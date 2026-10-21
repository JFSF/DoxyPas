unit DoxyPas.Model.Calls;

{ Who calls whom, for CALL_GRAPH / CALLER_GRAPH. There is no type information, so the bodies of the routines are
  scanned for identifiers: a plain identifier is resolved from the routine's scope, "Obj.Name" by "Type.Name" when
  Obj names a class and otherwise by the name alone when the project has exactly one routine with that name. }

interface

uses
  System.Generics.Collections,
  DoxyPas.Model.Defs,
  DoxyPas.Model.Project,
  DoxyPas.Model.Links;

type
  TCallIndex = class
  strict private
    FCalls: TObjectDictionary<TMemberDef, TList<TMemberDef>>;
    FCallers: TObjectDictionary<TMemberDef, TList<TMemberDef>>;
    procedure Link(AFrom, ATo: TMemberDef);
  public
    constructor Create(AProject: TProject; ALinks: TLinkResolver);
    destructor Destroy; override;
    /// <summary>The routines AMember calls (nil when none); owned by the index.</summary>
    function CallsOf(AMember: TMemberDef): TList<TMemberDef>;
    /// <summary>The routines that call AMember (nil when none).</summary>
    function CallersOf(AMember: TMemberDef): TList<TMemberDef>;
  end;

/// <summary>The text of a source file: UTF-8 (BOM or not), else the ANSI code page.</summary>
function ReadSourceText(const AFile: string): string;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  DoxyPas.Model.Entry;

function ReadSourceText(const AFile: string): string;
var
  Bytes: TBytes;
  Enc: TEncoding;
  Skip: Integer;
begin
  Bytes := TFile.ReadAllBytes(AFile);
  Enc := nil;
  Skip := TEncoding.GetBufferEncoding(Bytes, Enc, TEncoding.UTF8);
  Result := Enc.GetString(Bytes, Skip, Length(Bytes) - Skip);
  if Result.Contains(#$FFFD) then
    Result := TEncoding.ANSI.GetString(Bytes, Skip, Length(Bytes) - Skip);
end;

type
  TWord = record
    Text: string;
    Prev: string;       // the identifier before a '.', '' when the word is not qualified
  end;

// The identifiers of the code after the first "begin" (the header and local declarations are skipped), with
// comments and strings left out.
function BodyWords(const AText: string): TArray<TWord>;
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
          Started := SameText(W.Text, 'begin')
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

{ TCallIndex }

constructor TCallIndex.Create(AProject: TProject; ALinks: TLinkResolver);
var
  Routines: TList<TMemberDef>;
  Seen: TDictionary<TMemberDef, Boolean>;
  ByName: TObjectDictionary<string, TList<TMemberDef>>;
  Files: TDictionary<string, TArray<string>>;
  Cache: TDictionary<string, TMemberDef>;
  Starts_: TObjectDictionary<string, TList<Integer>>;   // per file: the sorted first lines of the bodies
  U: TUnitDef;
  C: TClassDef;
  M: TMemberDef;

  procedure Collect(AList: TList<TMemberDef>);
  var
    X: TMemberDef;
    L: TList<TMemberDef>;
  begin
    for X in AList do
      if (X.Kind = memFunction) and ALinks.IsLinkable(X) and not Seen.ContainsKey(X) then
      begin
        Seen.Add(X, True);
        Routines.Add(X);
        if not ByName.TryGetValue(LowerCase(X.Name), L) then
        begin
          L := TList<TMemberDef>.Create;
          ByName.Add(LowerCase(X.Name), L);
        end;
        L.Add(X);
      end;
  end;

  function Lines(const AFile: string): TArray<string>;
  begin
    if not Files.TryGetValue(AFile.ToLower, Result) then
    begin
      if TFile.Exists(AFile) then
        Result := ReadSourceText(AFile).Replace(#13#10, #10).Split([#10])
      else
        Result := nil;
      Files.Add(AFile.ToLower, Result);
    end;
  end;

  // The entry holding the body: the implementation, or the declaration of a routine that only exists in the
  // implementation section.
  function BodyEntry(AMember: TMemberDef): TEntry;
  begin
    Result := AMember.Impl;
    if (Result = nil) and AMember.ImplementationOnly then
      Result := AMember.Entry;
    if (Result <> nil) and ((Result.FileName = '') or (Result.Line < 1)) then
      Result := nil;
  end;

  // The parser records where a body starts but not where it ends, so the body runs up to the next one in the file.
  function BodyOf(AMember: TMemberDef): string;
  var
    B: TEntry;
    All: TArray<string>;
    Starts: TList<Integer>;
    K, Last: Integer;
    SB: TStringBuilder;
  begin
    Result := '';
    B := BodyEntry(AMember);
    if (B = nil) or not Starts_.TryGetValue(B.FileName.ToLower, Starts) then
      Exit;
    All := Lines(B.FileName);
    Last := Length(All);
    for K in Starts do
      if (K > B.Line) and (K <= Last) then
      begin
        Last := K - 1;
        Break;
      end;
    SB := TStringBuilder.Create;
    try
      for K := B.Line to Last do
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
      if (T.Def is TMemberDef) and (TMemberDef(T.Def).Kind = memFunction) then
        Result := TMemberDef(T.Def);
    end
    else
    begin
      T := ALinks.Resolve(AWord.Prev + '.' + AWord.Text, AFrom);
      if (T.Def is TMemberDef) and (TMemberDef(T.Def).Kind = memFunction) then
        Result := TMemberDef(T.Def)
      else if ByName.TryGetValue(LowerCase(AWord.Text), L) and (L.Count = 1) then
        Result := L[0];
    end;
    if (Result <> nil) and not ALinks.IsLinkable(Result) then
      Result := nil;
    Cache.Add(Key, Result);
  end;

var
  W: TWord;
  Target: TMemberDef;
  E: TEntry;
  SL: TList<Integer>;
begin
  inherited Create;
  Starts_ := TObjectDictionary<string, TList<Integer>>.Create([doOwnsValues]);
  FCalls := TObjectDictionary<TMemberDef, TList<TMemberDef>>.Create([doOwnsValues]);
  FCallers := TObjectDictionary<TMemberDef, TList<TMemberDef>>.Create([doOwnsValues]);
  Routines := TList<TMemberDef>.Create;
  Seen := TDictionary<TMemberDef, Boolean>.Create;
  ByName := TObjectDictionary<string, TList<TMemberDef>>.Create([doOwnsValues]);
  Files := TDictionary<string, TArray<string>>.Create;
  Cache := TDictionary<string, TMemberDef>.Create;
  try
    for U in AProject.Units do
      Collect(U.Members);
    for C in AProject.Classes do
      Collect(C.Members);
    for M in Routines do
    begin
      E := BodyEntry(M);
      if E = nil then
        Continue;
      if not Starts_.TryGetValue(E.FileName.ToLower, SL) then
      begin
        SL := TList<Integer>.Create;
        Starts_.Add(E.FileName.ToLower, SL);
      end;
      SL.Add(E.Line);
    end;
    for SL in Starts_.Values do
      SL.Sort;
    for M in Routines do
      for W in BodyWords(BodyOf(M)) do
      begin
        Target := TargetOf(M, W);
        if (Target <> nil) and (Target <> M) then
          Link(M, Target);
      end;
  finally
    Starts_.Free;
    Cache.Free;
    Files.Free;
    ByName.Free;
    Seen.Free;
    Routines.Free;
  end;
end;

destructor TCallIndex.Destroy;
begin
  FCallers.Free;
  FCalls.Free;
  inherited;
end;

procedure TCallIndex.Link(AFrom, ATo: TMemberDef);
var
  L: TList<TMemberDef>;
begin
  if not FCalls.TryGetValue(AFrom, L) then
  begin
    L := TList<TMemberDef>.Create;
    FCalls.Add(AFrom, L);
  end;
  if L.Contains(ATo) then
    Exit;
  L.Add(ATo);
  if not FCallers.TryGetValue(ATo, L) then
  begin
    L := TList<TMemberDef>.Create;
    FCallers.Add(ATo, L);
  end;
  L.Add(AFrom);
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
