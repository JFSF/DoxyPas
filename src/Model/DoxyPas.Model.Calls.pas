unit DoxyPas.Model.Calls;

{ Who calls and references whom, for CALL_GRAPH / CALLER_GRAPH and REFERENCES_RELATION / REFERENCED_BY_RELATION. There is
  no type information, so the bodies of the routines are scanned for identifiers: a plain identifier is resolved from the
  routine's scope (unless the routine's own header, i.e. a parameter or a local, uses the same name), "Obj.Name" by
  "Type.Name" when Obj names a class and otherwise by the name alone when the project has exactly one member with that
  name. }

interface

uses
  System.Generics.Collections,
  DoxyPas.Model.Defs,
  DoxyPas.Model.Project,
  DoxyPas.Model.Links,
  DoxyPas.Model.Entry;

type
  /// <summary>Where the bodies of the routines are: the file and the first and last line.</summary>
  TBodyLocator = class
  strict private
    FRoutines: TList<TMemberDef>;
    FMembers: TList<TMemberDef>;
    FFiles: TDictionary<string, TArray<string>>;
    FStarts: TObjectDictionary<string, TList<Integer>>;   // per file: the sorted first lines of the bodies
    function BodyEntry(AMember: TMemberDef): TEntry;
  public
    constructor Create(AProject: TProject; ALinks: TLinkResolver);
    destructor Destroy; override;
    /// <summary>The routines that have a body in the project's files.</summary>
    property Routines: TList<TMemberDef> read FRoutines;
    /// <summary>The routines, variables, constants and properties: what a body can refer to.</summary>
    property Members: TList<TMemberDef> read FMembers;
    function Lines(const AFile: string): TArray<string>;
    function Find(AMember: TMemberDef; out AFile: string; out AFirst, ALast: Integer): Boolean;
  end;

  TCallIndex = class
  strict private
    FCalls: TObjectDictionary<TMemberDef, TList<TMemberDef>>;
    FCallers: TObjectDictionary<TMemberDef, TList<TMemberDef>>;
    FRefs: TObjectDictionary<TMemberDef, TList<TMemberDef>>;
    FReferrers: TObjectDictionary<TMemberDef, TList<TMemberDef>>;
    procedure Link(AFrom, ATo: TMemberDef);
  public
    constructor Create(ALocator: TBodyLocator; ALinks: TLinkResolver);
    destructor Destroy; override;
    /// <summary>The routines AMember calls (nil when none); owned by the index.</summary>
    function CallsOf(AMember: TMemberDef): TList<TMemberDef>;
    /// <summary>The routines that call AMember (nil when none).</summary>
    function CallersOf(AMember: TMemberDef): TList<TMemberDef>;
    /// <summary>The routines, variables, constants and properties the body of AMember uses (nil when none).</summary>
    function ReferencesOf(AMember: TMemberDef): TList<TMemberDef>;
    /// <summary>The routines whose body uses AMember (nil when none).</summary>
    function ReferencedBy(AMember: TMemberDef): TList<TMemberDef>;
  end;

/// <summary>The line of the "end" that closes the routine starting at AStart (searching up to ALimit); -1 when there
/// is none (an external declaration).</summary>
function FindBodyEnd(const ALines: TArray<string>; AStart, ALimit: Integer): Integer;

/// <summary>The text of a source file (INPUT_ENCODING, see DoxyPas.Core.SourceText).</summary>
function ReadSourceText(const AFile: string): string;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  DoxyPas.Core.SourceText;

function ReadSourceText(const AFile: string): string;
begin
  Result := ReadSourceFile(AFile);
end;

const
  Referable = [memFunction, memVariable, memConstant, memProperty];

type
  TWord = record
    Text: string;
    Prev: string;       // the identifier before a '.', '' when the word is not qualified
  end;

// The identifiers of the code after the first "begin", with comments and strings left out; AShadow gets the ones used
// before it (the header and the local declarations).
function BodyWords(const AText: string; AShadow: THashSet<string>): TArray<TWord>;
var
  L: TList<TWord>;
  I, N, J: Integer;
  C: Char;
  Started, AfterDot: Boolean;
  Last, Prev: string;
  W: TWord;
begin
  L := TList<TWord>.Create;
  try
    I := 1;
    N := Length(AText);
    Started := False;
    AfterDot := False;
    Last := '';
    Prev := '';
    while I <= N do
    begin
      C := AText[I];
      if (C = '/') and (I < N) and (AText[I + 1] = '/') then
        while (I <= N) and (AText[I] <> #10) do
          Inc(I)
      else if C = '{' then
      begin
        while (I <= N) and (AText[I] <> '}') do
          Inc(I);
      end
      else if (C = '(') and (I < N) and (AText[I + 1] = '*') then
      begin
        Inc(I, 2);
        while (I < N) and not ((AText[I] = '*') and (AText[I + 1] = ')')) do
          Inc(I);
        Inc(I);
      end
      else if C = '''' then
      begin
        Inc(I);
        while (I <= N) and (AText[I] <> #10) do
        begin
          if AText[I] = '''' then
          begin
            if (I < N) and (AText[I + 1] = '''') then
              Inc(I)
            else
              Break;
          end;
          Inc(I);
        end;
        AfterDot := False;
      end
      else if CharInSet(C, ['A'..'Z', 'a'..'z', '_']) then
      begin
        J := I;
        while (J <= N) and CharInSet(AText[J], ['A'..'Z', 'a'..'z', '_', '0'..'9']) do
          Inc(J);
        W.Text := Copy(AText, I, J - I);
        if not Started then
        begin
          Started := SameText(W.Text, 'begin');
          AShadow.Add(LowerCase(W.Text));       // a parameter, a local or a type of the header
        end
        else
        begin
          if AfterDot then
            W.Prev := Last
          else
            W.Prev := '';
          L.Add(W);
        end;
        Last := W.Text;
        AfterDot := False;
        I := J;
        Continue;
      end
      else if C = '.' then
      begin
        AfterDot := (I < N) and (AText[I + 1] <> '.') and (Last <> '');
        Inc(I);
        Continue;
      end
      else if not CharInSet(C, [' ', #9, #10, #13]) and not CharInSet(C, ['0'..'9']) then
      begin
        Last := '';
        AfterDot := False;
      end;
      Inc(I);
    end;
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

{ TBodyLocator }

// The parser records where a body starts but not where it ends. Scans from AStart (ALimit: the line before the next
// body) for the "end" that closes the routine; local routines are told by a routine keyword after a ';'.
function FindBodyEnd(const ALines: TArray<string>; AStart, ALimit: Integer): Integer;
var
  Line, I, N, J, Locals: Integer;
  S, Word, Stack: string;   // one letter per open block: b begin/asm, x try/case, r record
  Kind: Char;
  InBrace, InParen, PrevSemi, First: Boolean;
  C: Char;
begin
  Result := -1;                            // no closing "end": an external declaration or a body it could not follow
  Stack := '';
  Locals := 0;
  InBrace := False;
  InParen := False;
  PrevSemi := False;
  First := True;
  for Line := AStart to ALimit do
  begin
    S := ALines[Line - 1];
    N := Length(S);
    I := 1;
    while I <= N do
    begin
      C := S[I];
      if InBrace then
      begin
        if C = '}' then
          InBrace := False;
        Inc(I);
      end
      else if InParen then
      begin
        if (C = '*') and (I < N) and (S[I + 1] = ')') then
        begin
          InParen := False;
          Inc(I);
        end;
        Inc(I);
      end
      else if C = '{' then
      begin
        InBrace := True;
        Inc(I);
      end
      else if (C = '(') and (I < N) and (S[I + 1] = '*') then
      begin
        InParen := True;
        Inc(I, 2);
      end
      else if (C = '/') and (I < N) and (S[I + 1] = '/') then
        Break
      else if C = '''' then
      begin
        Inc(I);
        while I <= N do
        begin
          if S[I] = '''' then
          begin
            if (I < N) and (S[I + 1] = '''') then
              Inc(I)
            else
              Break;
          end;
          Inc(I);
        end;
        Inc(I);
        PrevSemi := False;
      end
      else if CharInSet(C, ['A'..'Z', 'a'..'z', '_']) then
      begin
        J := I;
        while (J <= N) and CharInSet(S[J], ['A'..'Z', 'a'..'z', '_', '0'..'9']) do
          Inc(J);
        Word := LowerCase(Copy(S, I, J - I));
        I := J;
        if (Word = 'begin') or (Word = 'asm') then
        begin
          Stack := Stack + 'b';
        end
        else if (Word = 'try') or (Word = 'case') then
          Stack := Stack + 'x'
        else if Word = 'record' then
          Stack := Stack + 'r'
        else if (Word = 'end') and (Stack <> '') then
        begin
          Kind := Stack[Length(Stack)];
          SetLength(Stack, Length(Stack) - 1);
          if (Stack = '') and (Kind = 'b') then
          begin
            if Locals = 0 then
              Exit(Line);
            Dec(Locals);
          end;
        end
        else if ((Word = 'procedure') or (Word = 'function') or (Word = 'constructor') or (Word = 'destructor')) and
          (Stack = '') then
        begin
          if First then
            First := False                 // the routine's own header
          else if PrevSemi then
            Inc(Locals);
        end;
        if First and ((Word = 'class') or (Word = 'inline')) then
          Continue;                        // "class function ..." is still the header
        First := False;
        PrevSemi := False;
      end
      else
      begin
        if C = ';' then
          PrevSemi := True
        else if not CharInSet(C, [' ', #9]) then
          PrevSemi := False;
        Inc(I);
      end;
    end;
  end;
end;

constructor TBodyLocator.Create(AProject: TProject; ALinks: TLinkResolver);
var
  Seen: TDictionary<TMemberDef, Boolean>;
  U: TUnitDef;
  C: TClassDef;
  M: TMemberDef;
  E: TEntry;
  SL: TList<Integer>;

  procedure Collect(AList: TList<TMemberDef>);
  var
    X: TMemberDef;
  begin
    for X in AList do
      if (X.Kind in [memFunction, memVariable, memConstant, memProperty]) and ALinks.IsLinkable(X) and
        not Seen.ContainsKey(X) then
      begin
        Seen.Add(X, True);
        FMembers.Add(X);
        if X.Kind = memFunction then
          FRoutines.Add(X);
      end;
  end;

begin
  inherited Create;
  FRoutines := TList<TMemberDef>.Create;
  FMembers := TList<TMemberDef>.Create;
  FFiles := TDictionary<string, TArray<string>>.Create;
  FStarts := TObjectDictionary<string, TList<Integer>>.Create([doOwnsValues]);
  Seen := TDictionary<TMemberDef, Boolean>.Create;
  try
    for U in AProject.Units do
      Collect(U.Members);
    for C in AProject.Classes do
      Collect(C.Members);
  finally
    Seen.Free;
  end;
  for M in FRoutines do
  begin
    E := BodyEntry(M);
    if E = nil then
      Continue;
    if not FStarts.TryGetValue(E.FileName.ToLower, SL) then
    begin
      SL := TList<Integer>.Create;
      FStarts.Add(E.FileName.ToLower, SL);
    end;
    SL.Add(E.Line);
  end;
  for SL in FStarts.Values do
    SL.Sort;
end;

destructor TBodyLocator.Destroy;
begin
  FStarts.Free;
  FFiles.Free;
  FMembers.Free;
  FRoutines.Free;
  inherited;
end;

// The entry holding the body: the implementation, or the declaration of a routine that only exists in the
// implementation section.
function TBodyLocator.BodyEntry(AMember: TMemberDef): TEntry;
begin
  Result := AMember.Impl;
  if (Result = nil) and AMember.ImplementationOnly then
    Result := AMember.Entry;
  if (Result <> nil) and ((Result.FileName = '') or (Result.Line < 1)) then
    Result := nil;
end;

function TBodyLocator.Lines(const AFile: string): TArray<string>;
begin
  if not FFiles.TryGetValue(AFile.ToLower, Result) then
  begin
    if TFile.Exists(AFile) then
      Result := ReadSourceText(AFile).Replace(#13#10, #10).Split([#10])
    else
      Result := nil;
    FFiles.Add(AFile.ToLower, Result);
  end;
end;

function TBodyLocator.Find(AMember: TMemberDef; out AFile: string; out AFirst, ALast: Integer): Boolean;
var
  B: TEntry;
  All: TArray<string>;
  Starts: TList<Integer>;
  K, Limit: Integer;
begin
  Result := False;
  B := BodyEntry(AMember);
  if (B = nil) or not FStarts.TryGetValue(B.FileName.ToLower, Starts) then
    Exit;
  All := Lines(B.FileName);
  if B.Line > Length(All) then
    Exit;
  Limit := Length(All);
  for K in Starts do
    if (K > B.Line) and (K <= Limit) then
    begin
      Limit := K - 1;
      Break;
    end;
  AFile := B.FileName;
  AFirst := B.Line;
  ALast := FindBodyEnd(All, B.Line, Limit);
  Result := ALast >= B.Line;
end;

{ TCallIndex }

constructor TCallIndex.Create(ALocator: TBodyLocator; ALinks: TLinkResolver);
var
  ByName: TObjectDictionary<string, TList<TMemberDef>>;
  Cache: TDictionary<string, TMemberDef>;
  M: TMemberDef;
  W: TWord;
  Target: TMemberDef;
  Shadow: THashSet<string>;

  function BodyOf(AMember: TMemberDef): string;
  var
    F: string;
    First, Last, K: Integer;
    All: TArray<string>;
    SB: TStringBuilder;
  begin
    Result := '';
    if not ALocator.Find(AMember, F, First, Last) then
      Exit;
    All := ALocator.Lines(F);
    SB := TStringBuilder.Create;
    try
      for K := First to Last do
        SB.Append(All[K - 1]).Append(#10);
      Result := SB.ToString;
    finally
      SB.Free;
    end;
  end;

  // The routine a word of AFrom's body stands for, nil when it is not (clearly) one.
  function TargetOf(AFrom: TMemberDef; const AWord: TWord): TMemberDef;
  var
    Key: string;
    T: TLinkTarget;
    L: TList<TMemberDef>;
  begin
    Key := AWord.Prev + '.' + AWord.Text + '|' + IntToStr(NativeInt(AFrom.Scope));
    if Cache.TryGetValue(Key, Result) then
      Exit;
    Result := nil;
    if AWord.Prev = '' then
    begin
      T := ALinks.Resolve(AWord.Text, AFrom);
      if (T.Def is TMemberDef) and (TMemberDef(T.Def).Kind in Referable) then
        Result := TMemberDef(T.Def);
    end
    else
    begin
      T := ALinks.Resolve(AWord.Prev + '.' + AWord.Text, AFrom);
      if (T.Def is TMemberDef) and (TMemberDef(T.Def).Kind in Referable) then
        Result := TMemberDef(T.Def)
      else if ByName.TryGetValue(LowerCase(AWord.Text), L) and (L.Count = 1) then
        Result := L[0];
    end;
    if (Result <> nil) and not ALinks.IsLinkable(Result) then
      Result := nil;
    Cache.Add(Key, Result);
  end;

var
  L: TList<TMemberDef>;
begin
  inherited Create;
  FCalls := TObjectDictionary<TMemberDef, TList<TMemberDef>>.Create([doOwnsValues]);
  FCallers := TObjectDictionary<TMemberDef, TList<TMemberDef>>.Create([doOwnsValues]);
  FRefs := TObjectDictionary<TMemberDef, TList<TMemberDef>>.Create([doOwnsValues]);
  FReferrers := TObjectDictionary<TMemberDef, TList<TMemberDef>>.Create([doOwnsValues]);
  ByName := TObjectDictionary<string, TList<TMemberDef>>.Create([doOwnsValues]);
  Cache := TDictionary<string, TMemberDef>.Create;
  try
    for M in ALocator.Members do
    begin
      if not ByName.TryGetValue(LowerCase(M.Name), L) then
      begin
        L := TList<TMemberDef>.Create;
        ByName.Add(LowerCase(M.Name), L);
      end;
      L.Add(M);
    end;
    Shadow := THashSet<string>.Create;
    try
      for M in ALocator.Routines do
      begin
        Shadow.Clear;
        for W in BodyWords(BodyOf(M), Shadow) do
        begin
          if (W.Prev = '') and Shadow.Contains(LowerCase(W.Text)) then
            Continue;
          Target := TargetOf(M, W);
          if (Target <> nil) and (Target <> M) then
            Link(M, Target);
        end;
      end;
    finally
      Shadow.Free;
    end;
  finally
    Cache.Free;
    ByName.Free;
  end;
end;

destructor TCallIndex.Destroy;
begin
  FReferrers.Free;
  FRefs.Free;
  FCallers.Free;
  FCalls.Free;
  inherited;
end;

procedure Append(ADict: TObjectDictionary<TMemberDef, TList<TMemberDef>>; AKey, AValue: TMemberDef);
var
  L: TList<TMemberDef>;
begin
  if not ADict.TryGetValue(AKey, L) then
  begin
    L := TList<TMemberDef>.Create;
    ADict.Add(AKey, L);
  end;
  if not L.Contains(AValue) then
    L.Add(AValue);
end;

procedure TCallIndex.Link(AFrom, ATo: TMemberDef);
begin
  Append(FRefs, AFrom, ATo);
  Append(FReferrers, ATo, AFrom);
  if ATo.Kind = memFunction then
  begin
    Append(FCalls, AFrom, ATo);
    Append(FCallers, ATo, AFrom);
  end;
end;

function TCallIndex.ReferencesOf(AMember: TMemberDef): TList<TMemberDef>;
begin
  if not FRefs.TryGetValue(AMember, Result) then
    Result := nil;
end;

function TCallIndex.ReferencedBy(AMember: TMemberDef): TList<TMemberDef>;
begin
  if not FReferrers.TryGetValue(AMember, Result) then
    Result := nil;
end;
function TCallIndex.CallsOf(AMember: TMemberDef): TList<TMemberDef>;
begin
  if not FCalls.TryGetValue(AMember, Result) then
    Result := nil;
end;

function TCallIndex.CallersOf(AMember: TMemberDef): TList<TMemberDef>;
begin
  if not FCallers.TryGetValue(AMember, Result) then
    Result := nil;
end;

end.
