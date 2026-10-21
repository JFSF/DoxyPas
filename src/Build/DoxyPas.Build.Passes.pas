unit DoxyPas.Build.Passes;

{ The passes that turn parser output (Entry trees) into the semantic model (Doxygen's parseInput() steps:
  buildClassList, buildFunctionList, findMemberDocumentation, computeClassRelations, buildCompleteMemberLists,
  addMembersToMemberGroup, resolveUserReferences, generateDiskNames ...). }

interface

uses
  DoxyPas.Model.Project;

/// <summary>Runs every pass in the right order over AProject.Roots.</summary>
procedure BuildModel(AProject: TProject);

/// <summary>File name (without extension) for a compound or page name, escaped like Doxygen's convertNameToFile.</summary>
function ConvertNameToFile(const AName: string; ACaseSense: Boolean; AAllowDots: Boolean = False;
  AAllowUnderscore: Boolean = False): string;

implementation

uses
  DoxyPas.Core.Timing,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Hash,
  System.Character,
  System.RegularExpressions,
  DoxyPas.Model.Entry,
  DoxyPas.Model.Defs,
  DoxyPas.Doc.Nodes,
  DoxyPas.Doc.Parser;

{ ------------------------------------------------------------------ helpers }

function NormType(const S: string): string;
begin
  Result := LowerCase(S).Replace(' ', '').Replace(#9, '');
end;

{ "const,integer,var,string": modifier and type of every argument }
function ArgKey(AEntry: TEntry): string;
var
  A: TArgument;
begin
  Result := '';
  for A in AEntry.Args do
    Result := Result + NormType(A.Modifier) + ':' + NormType(A.TypeText) + ',';
end;

function ConvertNameToFile(const AName: string; ACaseSense, AAllowDots, AAllowUnderscore: Boolean): string;
var
  SB: TStringBuilder;
  C: Char;
begin
  SB := TStringBuilder.Create;
  try
    for C in AName do
      case C of
        '_': if AAllowUnderscore then SB.Append('_') else SB.Append('__');
        '-': SB.Append('-');
        ':': SB.Append('_1');
        '/': SB.Append('_2');
        '<': SB.Append('_3');
        '>': SB.Append('_4');
        '*': SB.Append('_5');
        '&': SB.Append('_6');
        '|': SB.Append('_7');
        '.': if AAllowDots then SB.Append('.') else SB.Append('_8');
        '!': SB.Append('_9');
        ',': SB.Append('_00');
        ' ': SB.Append('_01');
        '{': SB.Append('_02');
        '}': SB.Append('_03');
        '?': SB.Append('_04');
        '^': SB.Append('_05');
        '%': SB.Append('_06');
        '(': SB.Append('_07');
        ')': SB.Append('_08');
        '+': SB.Append('_09');
        '=': SB.Append('_0a');
        '$': SB.Append('_0b');
        '\': SB.Append('_0c');
        '@': SB.Append('_0d');
        ']': SB.Append('_0e');
        '[': SB.Append('_0f');
        '#': SB.Append('_0g');
        '"': SB.Append('_0h');
        '~': SB.Append('_0i');
        '''': SB.Append('_0j');
        ';': SB.Append('_0k');
        '`': SB.Append('_0l');
      else
        if Ord(C) > 127 then
          SB.Append('_x').Append(IntToHex(Ord(C), 2).ToLower)
        else if (not ACaseSense) and (C >= 'A') and (C <= 'Z') then
          SB.Append('_').Append(LowerCase(C))
        else
          SB.Append(C);
      end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
  if Length(Result) >= 128 then // names that cannot be created: truncate and add a hash
    Result := Copy(Result, 1, 128 - 32) + THashMD5.GetHashString(Result);
end;

function IsInterfaceName(const AName: string): Boolean;
begin
  Result := (Length(AName) > 1) and (AName[1] = 'I') and AName[2].IsUpper;
end;

{ ------------------------------------------------------------------ definitions }

type
  TBuilder = class
  strict private
    FProject: TProject;
    FPending: TObjectDictionary<TUnitDef, TList<TEntry>>;
    procedure Children(AScope: TScopeDef; AParent: TEntry);
    function NewMember(AScope: TScopeDef; AEntry: TEntry; AKind: TMemberKind): TMemberDef;
    procedure NewClass(AScope: TScopeDef; AEntry: TEntry);
    procedure NewEnum(AScope: TScopeDef; AEntry: TEntry);
    procedure NewUnit(ARoot: TEntry);
    procedure NewPage(E: TEntry);
    procedure MergeDocs(AMember: TMemberDef; AImpl: TEntry);
    function MatchImpl(const ACandidates: TList<TMemberDef>; AImpl: TEntry): TMemberDef;
    procedure MergeImplementation(AUnit: TUnitDef; AImpl: TEntry);
    function FindClassPath(AUnit: TUnitDef; const AParts: TArray<string>; ACount: Integer): TClassDef;
  public
    constructor Create(AProject: TProject);
    destructor Destroy; override;
    procedure Run;
  end;

constructor TBuilder.Create(AProject: TProject);
begin
  inherited Create;
  FProject := AProject;
  FPending := TObjectDictionary<TUnitDef, TList<TEntry>>.Create([doOwnsValues]);
end;

destructor TBuilder.Destroy;
begin
  FPending.Free;
  inherited;
end;

function TBuilder.NewMember(AScope: TScopeDef; AEntry: TEntry; AKind: TMemberKind): TMemberDef;
begin
  Result := TMemberDef.Create(AEntry.Name, AEntry, AKind);
  Result.Scope := AScope;
  Result.ImplementationOnly := efImplementation in AEntry.Flags;
  FProject.AddMember(Result);
  AScope.AddSymbol(Result);
  if AScope is TUnitDef then
    TUnitDef(AScope).Members.Add(Result)
  else if AScope is TClassDef then
    TClassDef(AScope).Members.Add(Result);
end;

procedure TBuilder.NewEnum(AScope: TScopeDef; AEntry: TEntry);
var
  E: TMemberDef;
  V: TEntry;
  M: TMemberDef;
begin
  E := NewMember(AScope, AEntry, memEnumeration);
  for V in AEntry.Children do
    if V.Kind = ekEnumValue then
    begin
      M := TMemberDef.Create(V.Name, V, memEnumValue);
      M.Scope := AScope;
      M.EnumOwner := E;
      M.ImplementationOnly := E.ImplementationOnly;
      FProject.Own(M);
      E.EnumValues.Add(M);
      AScope.AddSymbol(M); // enumeration values are visible in the enclosing scope
    end;
end;

procedure TBuilder.NewClass(AScope: TScopeDef; AEntry: TEntry);
var
  C: TClassDef;
begin
  C := TClassDef.Create(AEntry.Name, AEntry);
  C.ClassKind := AEntry.ClassKind;
  C.Scope := AScope;
  C.ImplementationOnly := efImplementation in AEntry.Flags;
  FProject.AddClass(C);
  AScope.AddSymbol(C);
  if AScope is TUnitDef then
    TUnitDef(AScope).Classes.Add(C)
  else if AScope is TClassDef then
    TClassDef(AScope).NestedClasses.Add(C);
  Children(C, AEntry);
end;

procedure TBuilder.Children(AScope: TScopeDef; AParent: TEntry);
var
  E: TEntry;
  G: TGroupDef;
  P: TPageDef;
begin
  for E in AParent.Children do
    case E.Kind of
      ekClass:
        if not (efForward in E.Flags) then
          NewClass(AScope, E);
      ekEnum: NewEnum(AScope, E);
      ekTypeAlias: NewMember(AScope, E, memTypedef);
      ekField: NewMember(AScope, E, memVariable);
      ekConstant: NewMember(AScope, E, memConstant);
      ekProperty: NewMember(AScope, E, memProperty);
      ekMethod:
        if (efImplementation in E.Flags) and (AScope is TUnitDef) then
          FPending[TUnitDef(AScope)].Add(E)
        else
          NewMember(AScope, E, memFunction);
      ekPage: NewPage(E);
      ekGroup:
        begin
          G := FProject.FindGroup(E.Name);
          if G = nil then
          begin
            G := TGroupDef.Create(E.Name, E);
            G.Title := E.TypeText;
            FProject.AddGroup(G);
          end
          else
          begin
            // \addtogroup of a group that already exists: its text is added
            if (G.Title = '') and (E.TypeText <> '') then
              G.Title := E.TypeText;
            if E.Detailed <> '' then
              if G.Detailed = '' then G.Detailed := E.Detailed else G.Detailed := G.Detailed + #10#10 + E.Detailed;
            if E.Brief <> '' then
              if G.Brief = '' then G.Brief := E.Brief;
          end;
        end;
    end;
end;

procedure TBuilder.NewPage(E: TEntry);
var
  P: TPageDef;
begin
  P := TPageDef.Create(E.Name, E);
  P.Title := E.TypeText;
  P.IsMainPage := SameText(E.Name, 'mainpage');
  FProject.AddPage(P);
end;

procedure TBuilder.NewUnit(ARoot: TEntry);
var
  U: TUnitDef;
  S: string;
begin
  U := TUnitDef.Create(ARoot.Name, ARoot);
  U.UnitKind := ARoot.TypeText;
  U.FileName := ARoot.FileName;
  for S in ARoot.UsesInterface do
    U.UsesInterfaceNames.Add(S);
  for S in ARoot.UsesImplementation do
    U.UsesImplementationNames.Add(S);
  FProject.AddUnit(U);
  FPending.Add(U, TList<TEntry>.Create);
  Children(U, ARoot);
end;

procedure TBuilder.MergeDocs(AMember: TMemberDef; AImpl: TEntry);
begin
  AMember.Impl := AImpl;
  if AMember.Brief = '' then
    AMember.Brief := AImpl.Brief;
  if AImpl.Detailed <> '' then
    if AMember.Detailed = '' then
      AMember.Detailed := AImpl.Detailed
    else
      AMember.Detailed := AMember.Detailed + #10#10 + AImpl.Detailed;
end;

{ Declaration that belongs to an implementation heading: same arguments, else the same number of arguments,
  else (the implementation may omit the parameters) the only candidate. }
function TBuilder.MatchImpl(const ACandidates: TList<TMemberDef>; AImpl: TEntry): TMemberDef;
var
  M: TMemberDef;
  Free: TList<TMemberDef>;
begin
  Result := nil;
  Free := TList<TMemberDef>.Create;
  try
    for M in ACandidates do
      if M.Impl = nil then
        Free.Add(M);
    if Free.Count = 0 then
      Exit;
    for M in Free do
      if (ArgKey(M.Entry) = ArgKey(AImpl)) and (AImpl.Args.Count > 0) then
        Exit(M);
    if AImpl.Args.Count = 0 then
    begin
      for M in Free do
        if M.Entry.Args.Count = 0 then
          Exit(M);
      Exit(Free[0]);
    end;
    for M in Free do
      if M.Entry.Args.Count = AImpl.Args.Count then
        Exit(M);
    Result := Free[0];
  finally
    Free.Free;
  end;
end;

function TBuilder.FindClassPath(AUnit: TUnitDef; const AParts: TArray<string>; ACount: Integer): TClassDef;
var
  I: Integer;
  L: TList<TDefinition>;
  Cur: TScopeDef;
  D: TDefinition;
  Found: TClassDef;
begin
  Result := nil;
  Cur := AUnit;
  Found := nil;
  for I := 0 to ACount - 1 do
  begin
    L := Cur.Find(PlainName(AParts[I]));
    Found := nil;
    if L <> nil then
      for D in L do
        if D is TClassDef then
        begin
          Found := TClassDef(D);
          Break;
        end;
    if Found = nil then
      Exit;
    Cur := Found;
  end;
  Result := Found;
end;

procedure TBuilder.MergeImplementation(AUnit: TUnitDef; AImpl: TEntry);
var
  Parts: TArray<string>;
  C: TClassDef;
  Cand: TList<TMemberDef>;
  L: TList<TDefinition>;
  D: TDefinition;
  M: TMemberDef;
  Name: string;
begin
  Cand := TList<TMemberDef>.Create;
  try
    Parts := AImpl.Name.Split(['.']);
    if Length(Parts) > 1 then
    begin
      Name := PlainName(Parts[High(Parts)]);
      C := FindClassPath(AUnit, Parts, Length(Parts) - 1);
      if C = nil then
        Exit;  // implementation of a method of a class outside the project
      L := C.Find(Name);
      if L <> nil then
        for D in L do
          if (D is TMemberDef) and (TMemberDef(D).Kind = memFunction) then
            Cand.Add(TMemberDef(D));
      M := MatchImpl(Cand, AImpl);
      if M <> nil then
        MergeDocs(M, AImpl);
      Exit;
    end;
    L := AUnit.Find(AImpl.Name);
    if L <> nil then
      for D in L do
        if (D is TMemberDef) and (TMemberDef(D).Kind = memFunction) and not TMemberDef(D).ImplementationOnly then
          Cand.Add(TMemberDef(D));
    M := MatchImpl(Cand, AImpl);
    if M <> nil then
      MergeDocs(M, AImpl)
    else
      NewMember(AUnit, AImpl, memFunction);   // exists only in the implementation section
  finally
    Cand.Free;
  end;
end;

procedure TBuilder.Run;
var
  Root: TEntry;
  U: TUnitDef;
  E: TEntry;
begin
  for Root in FProject.Roots do
    if Root.Kind = ekUnit then
      NewUnit(Root)
    else if Root.Kind = ekPage then
      NewPage(Root);
  for U in FProject.Units do
    for E in FPending[U] do
      MergeImplementation(U, E);
end;

{ ------------------------------------------------------------------ relations }

procedure ResolveUses(AProject: TProject);
var
  U, T: TUnitDef;
  S: string;
begin
  for U in AProject.Units do
  begin
    for S in U.UsesInterfaceNames do
    begin
      T := AProject.FindUnit(S);
      if (T <> nil) and (T <> U) then
      begin
        U.UsesInterface.Add(T);
        if T.UsedBy.IndexOf(U) < 0 then
          T.UsedBy.Add(U);
      end;
    end;
    for S in U.UsesImplementationNames do
    begin
      T := AProject.FindUnit(S);
      if (T <> nil) and (T <> U) then
      begin
        U.UsesImplementation.Add(T);
        if T.UsedBy.IndexOf(U) < 0 then
          T.UsedBy.Add(U);
      end;
    end;
  end;
end;

procedure ResolveBases(AProject: TProject);
var
  C: TClassDef;
  S: string;
  Ref: TBaseRef;
  D: TDefinition;
  U: TUnitDef;
  I: Integer;
  L: TList<TDefinition>;
begin
  for C in AProject.Classes do
    for S in C.Entry.Bases do
    begin
      Ref := Default(TBaseRef);
      Ref.Text := S;
      D := AProject.Lookup(PlainName(S), C.Scope);
      if D = C then
      begin
        // "TFoo = class(TFoo)": the base comes from another unit
        D := nil;
        U := C.OwnerUnit;
        for I := U.UsesInterface.Count - 1 downto 0 do
        begin
          L := U.UsesInterface[I].Find(C.Name);
          if (L <> nil) and (L.Count > 0) and (L[0] is TClassDef) then
          begin
            D := L[0];
            Break;
          end;
        end;
      end;
      if D is TClassDef then
        Ref.ClassDef := TClassDef(D);
      if Ref.ClassDef <> nil then
        Ref.IsInterface := Ref.ClassDef.ClassKind in [ckInterface, ckDispInterface]
      else
        Ref.IsInterface := IsInterfaceName(PlainName(S));
      C.Bases.Add(Ref);
      if (Ref.ClassDef <> nil) and (Ref.ClassDef.Derived.IndexOf(C) < 0) then
        Ref.ClassDef.Derived.Add(C);
    end;
end;

procedure ResolveAccessors(AProject: TProject);
var
  M: TMemberDef;

  function Accessor(const AText: string): TMemberDef;
  var
    Name: string;
    D: TDefinition;
    I: Integer;
  begin
    Result := nil;
    Name := Trim(AText);
    for I := 1 to Length(Name) do
      if not (Name[I].IsLetterOrDigit or (Name[I] = '_')) then
      begin
        Name := Copy(Name, 1, I - 1);
        Break;
      end;
    if Name = '' then
      Exit;
    D := AProject.Lookup(Name, M.Scope);
    if (D is TMemberDef) and (D.Scope is TClassDef) then
      Result := TMemberDef(D);
  end;

begin
  for M in AProject.Members do
    if (M.Kind = memProperty) and (M.Scope is TClassDef) then
    begin
      M.ReadMember := Accessor(M.Entry.ReadAccessor);
      M.WriteMember := Accessor(M.Entry.WriteAccessor);
    end;
end;

function SameSignature(A, B: TMemberDef): Boolean;
begin
  Result := (A.Entry <> nil) and (B.Entry <> nil) and (ArgKey(A.Entry) = ArgKey(B.Entry));
end;

{ Own members first, then those inherited from the bases that are not hidden by a member of the class. }
procedure BuildOneMemberList(AClass: TClassDef; ADone: TList<TClassDef>; AInProgress: TList<TClassDef>);
var
  B: TBaseRef;
  IM: TInheritedMember;
  Item: TInheritedMember;
  M: TMemberDef;
  Hidden: Boolean;
  X: TMemberDef;
  ByName: TObjectDictionary<string, TList<TMemberDef>>;   // the members of the list so far, by name
  L: TList<TMemberDef>;

  procedure Note(AMember: TMemberDef);
  var
    Key: string;
  begin
    Key := LowerCase(AMember.Name);
    if not ByName.TryGetValue(Key, L) then
    begin
      L := TList<TMemberDef>.Create;
      ByName.Add(Key, L);
    end;
    L.Add(AMember);
  end;

begin
  if ADone.IndexOf(AClass) >= 0 then
    Exit;
  if AInProgress.IndexOf(AClass) >= 0 then
    Exit; // cycle
  AInProgress.Add(AClass);
  ByName := TObjectDictionary<string, TList<TMemberDef>>.Create([doOwnsValues]);
  try
  for M in AClass.Members do
  begin
    Item.Member := M;
    Item.From := AClass;
    AClass.AllMembers.Add(Item);
    Note(M);
  end;
  for B in AClass.Bases do
    if B.ClassDef <> nil then
    begin
      BuildOneMemberList(B.ClassDef, ADone, AInProgress);
      for IM in B.ClassDef.AllMembers do
      begin
        if IM.Member.Kind = memEnumValue then
          Continue;
        if (IM.Member.Protection in [prPrivate, prStrictPrivate]) and (IM.From.OwnerUnit <> AClass.OwnerUnit) then
          Continue;
        if IM.Member.Protection = prStrictPrivate then
          Continue;
        Hidden := False;
        if ByName.TryGetValue(LowerCase(IM.Member.Name), L) then
          for X in L do
            if X.Kind = IM.Member.Kind then
              if (IM.Member.Kind <> memFunction) or SameSignature(X, IM.Member) or
                not (efOverload in X.Entry.Flags) then
              begin
                Hidden := True;
                Break;
              end;
        if not Hidden then
        begin
          AClass.AllMembers.Add(IM);
          Note(IM.Member);
        end;
      end;
    end;
  finally
    ByName.Free;
  end;
  AInProgress.Remove(AClass);
  ADone.Add(AClass);
end;

procedure BuildMemberLists(AProject: TProject);
var
  Done, Busy: TList<TClassDef>;
  C: TClassDef;
begin
  Done := TList<TClassDef>.Create;
  Busy := TList<TClassDef>.Create;
  try
    for C in AProject.Classes do
      BuildOneMemberList(C, Done, Busy);
  finally
    Busy.Free;
    Done.Free;
  end;
end;

{ The member of an ancestor (class or interface) that M overrides or implements. }
function FindOverridden(AClass: TClassDef; M: TMemberDef; AVisited: TList<TClassDef>): TMemberDef;
var
  B: TBaseRef;
  L: TList<TDefinition>;
  D: TDefinition;
  Best: TMemberDef;
begin
  Result := nil;
  for B in AClass.Bases do
  begin
    if (B.ClassDef = nil) or (AVisited.IndexOf(B.ClassDef) >= 0) then
      Continue;
    AVisited.Add(B.ClassDef);
    L := B.ClassDef.Find(M.Name);
    Best := nil;
    if L <> nil then
      for D in L do
        if (D is TMemberDef) and (TMemberDef(D).Kind = M.Kind) and (D <> M) then
          if SameSignature(TMemberDef(D), M) then
          begin
            Best := TMemberDef(D);
            Break;
          end
          else if (Best = nil) and (TMemberDef(D).Entry.Args.Count = M.Entry.Args.Count) then
            Best := TMemberDef(D);
    if (Best <> nil) and ((M.Entry.Virtualness = vtOverride) or B.IsInterface or (Best.Entry.Virtualness <> vtNormal)
      or (B.ClassDef.ClassKind in [ckInterface, ckDispInterface])) then
      Exit(Best);
    Result := FindOverridden(B.ClassDef, M, AVisited);
    if Result <> nil then
      Exit;
  end;
end;

procedure ResolveReimplementations(AProject: TProject);
var
  C: TClassDef;
  M, O: TMemberDef;
  Visited: TList<TClassDef>;
begin
  Visited := TList<TClassDef>.Create;
  try
    for C in AProject.Classes do
      for M in C.Members do
        if M.Kind in [memFunction, memProperty] then
        begin
          Visited.Clear;
          Visited.Add(C);
          O := FindOverridden(C, M, Visited);
          if O <> nil then
          begin
            M.Reimplements := O;
            O.ReimplementedBy.Add(M);
          end;
        end;
  finally
    Visited.Free;
  end;
end;

procedure InheritDocs(AProject: TProject);
var
  M: TMemberDef;

  procedure Inherit(AMember: TMemberDef; ADepth: Integer);
  begin
    if (AMember.IsDocumented) or (AMember.Reimplements = nil) or (ADepth > 20) then
      Exit;
    Inherit(AMember.Reimplements, ADepth + 1);
    if AMember.Reimplements.IsDocumented then
    begin
      AMember.Brief := AMember.Reimplements.Brief;
      AMember.Detailed := AMember.Reimplements.Detailed;
      AMember.DocInherited := True;
    end;
  end;

begin
  if not AProject.Options.InheritDocs then
    Exit;
  for M in AProject.Members do
    Inherit(M, 0);
end;

{ \copydoc, \copybrief, \copydetails and \inheritdoc are replaced by the text they refer to. }
procedure ResolveCopyDocs(AProject: TProject);
var
  D: TDefinition;
  All: TList<TDefinition>;

  function Source(ADef: TDefinition; const ACmd, ATarget: string): TDefinition;
  var
    B: TBaseRef;
  begin
    Result := nil;
    if ACmd = 'inheritdoc' then
    begin
      if ADef is TMemberDef then
        Result := TMemberDef(ADef).Reimplements
      else if ADef is TClassDef then
        for B in TClassDef(ADef).Bases do
          if (B.ClassDef <> nil) and B.ClassDef.IsDocumented then
            Exit(B.ClassDef);
    end
    else
      Result := AProject.Lookup(ATarget, ADef);
  end;

  function Expand(ADef: TDefinition; const AText: string; AWhat: string): string;
  var
    Pass: Integer;
    M: TMatch;
    Src: TDefinition;
    Cmd, Target, Rep: string;
  begin
    Result := AText;
    // almost no text has one of the commands: without this the regular expression is compiled twice per definition
    if (Pos('copy', AText) = 0) and (Pos('inheritdoc', AText) = 0) then
      Exit;
    for Pass := 1 to 10 do
    begin
      M := TRegEx.Match(Result, '[\\@](copydoc|copybrief|copydetails|inheritdoc)\b[ \t]*([^\s]*)');
      if not M.Success then
        Break;
      Cmd := M.Groups[1].Value;
      Target := M.Groups[2].Value;
      if Cmd = 'inheritdoc' then
        Target := '';
      Src := Source(ADef, Cmd, Target);
      if (Src = nil) or (Src = ADef) then
      begin
        if (ADef.Entry <> nil) and AProject.Options.WarnIfDocError then
          if Cmd = 'inheritdoc' then
            AProject.Warn(ADef.Entry.FileName, ADef.Entry.DocLine, '\inheritdoc: no documented base member found')
          else
            AProject.Warn(ADef.Entry.FileName, ADef.Entry.DocLine,
              Format('target ''%s'' of \%s is not found', [Target, Cmd]));
        Rep := '';
      end
      else if Cmd = 'copybrief' then
        Rep := Src.Brief
      else if Cmd = 'copydetails' then
        Rep := Src.Detailed
      else if AWhat = 'brief' then
        Rep := Src.Brief
      else if (Src.Brief <> '') and (Src.Detailed <> '') then
        Rep := Src.Brief + #10#10 + Src.Detailed
      else
        Rep := Src.Brief + Src.Detailed;
      Result := Result.Remove(M.Index - 1, M.Length).Insert(M.Index - 1, Rep);
    end;
  end;

begin
  All := TList<TDefinition>.Create;
  try
    for D in AProject.Classes do All.Add(D);
    for D in AProject.Members do All.Add(D);
    for D in AProject.Units do All.Add(D);
    for D in AProject.Groups do All.Add(D);
    for D in All do
    begin
      D.Brief := Expand(D, D.Brief, 'brief');
      D.Detailed := Expand(D, D.Detailed, 'detailed');
    end;
  finally
    All.Free;
  end;
end;

procedure AssignGroups(AProject: TProject);
var
  D: TDefinition;
  G, P: TGroupDef;
  S: string;
  All: TList<TDefinition>;

  procedure AddTo(ADef: TDefinition);
  var
    S: string;
    G: TGroupDef;
  begin
    if (ADef.Entry = nil) then
      Exit;
    for S in ADef.Entry.Groups do
    begin
      G := AProject.FindGroup(S);
      if G = nil then
      begin
        AProject.Warn(ADef.Entry.FileName, ADef.Entry.DocLine, Format('unknown group ''%s'' in \ingroup', [S]));
        Continue;
      end;
      if G.Members.IndexOf(ADef) < 0 then
      begin
        G.Members.Add(ADef);
        ADef.Groups.Add(G);
      end;
    end;
  end;

begin
  All := TList<TDefinition>.Create;
  try
    for D in AProject.Units do All.Add(D);
    for D in AProject.Classes do All.Add(D);
    for D in AProject.Members do
      if TMemberDef(D).Kind <> memEnumValue then
        All.Add(D);
    for D in All do
      AddTo(D);
  finally
    All.Free;
  end;
  // groups inside groups
  for G in AProject.Groups do
    if G.Entry <> nil then
      for S in G.Entry.Groups do
      begin
        P := AProject.FindGroup(S);
        if (P <> nil) and (P <> G) then
        begin
          G.Parent := P;
          if P.Subgroups.IndexOf(G) < 0 then
            P.Subgroups.Add(G);
        end;
      end;
end;

function MemberAnchor(M: TMemberDef): string;
begin
  Result := 'a' + THashMD5.GetHashString(LowerCase(M.QualifiedName + M.Signature + MemberKindName(M.Kind))).ToLower;
end;

procedure AssignDiskNames(AProject: TProject);
var
  U: TUnitDef;
  C: TClassDef;
  M, V: TMemberDef;
  G: TGroupDef;
  P: TPageDef;
  Prefix, Q: string;
  Cs: Boolean;
  D: TDefinition;

  function ScopedName(ADef: TDefinition): string;
  begin
    // Unit::TOuter::TInner
    Result := ADef.Name;
    D := ADef.Scope;
    while D <> nil do
    begin
      Result := D.Name + '::' + Result;
      D := D.Scope;
    end;
  end;

begin
  Cs := AProject.Options.CaseSenseNames;
  for U in AProject.Units do
    U.DiskName := ConvertNameToFile('unit' + U.Name, Cs);
  for C in AProject.Classes do
  begin
    case C.ClassKind of
      ckRecord, ckRecordHelper: Prefix := 'struct';
      ckInterface, ckDispInterface: Prefix := 'interface';
    else
      Prefix := 'class';
    end;
    Q := ScopedName(C);
    C.DiskName := ConvertNameToFile(Prefix + Q, Cs);
  end;
  for M in AProject.Members do
  begin
    M.DiskName := MemberAnchor(M);
    for V in M.EnumValues do
      V.DiskName := MemberAnchor(V);
  end;
  for G in AProject.Groups do
    G.DiskName := ConvertNameToFile('group__' + G.Name, Cs, False, True);
  for P in AProject.Pages do
    if P.IsMainPage then
      P.DiskName := 'index'
    else
      P.DiskName := ConvertNameToFile(P.Name, Cs);
end;

{ ------------------------------------------------------------------ validation }

procedure CollectRefs(ANode: TDocNode; AList: TList<TDocNode>);
var
  C: TDocNode;
begin
  if (ANode.Kind = dnRef) or ((ANode.Kind = dnLink) and (ANode.Name = 'link')) then
    AList.Add(ANode);
  for C in ANode.Children do
    CollectRefs(C, AList);
end;

procedure CollectParams(ANode: TDocNode; const ASection: string; AList: TStrings);
var
  C, I: TDocNode;
  N: string;
begin
  if (ANode.Kind = dnParamList) and (ANode.Name = ASection) then
    for I in ANode.Children do
      for N in I.Text.Split([',']) do
        AList.Add(N);
  for C in ANode.Children do
    CollectParams(C, ASection, AList);
end;

function PageExists(AProject: TProject; const AName: string): Boolean;
var
  P: TPageDef;
begin
  Result := SameText(AName, 'mainpage');
  for P in AProject.Pages do
    if SameText(P.Name, AName) then
      Exit(True);
end;

function DescribeWhere(ADef: TDefinition): string;
begin
  Result := ADef.QualifiedName;
end;

procedure ValidateDocs(AProject: TProject);
var
  D: TDefinition;
  All: TList<TDefinition>;
  M: TMemberDef;
  Root: TDocNode;
  Refs: TList<TDocNode>;
  R: TDocNode;
  Names, Doc: TStringList;
  A: TArgument;
  N: string;
  Found: Boolean;
  File_: string;
  Line: Integer;
begin
  All := TList<TDefinition>.Create;
  Refs := TList<TDocNode>.Create;
  Names := TStringList.Create;
  Doc := TStringList.Create;
  try
    for D in AProject.Units do All.Add(D);
    for D in AProject.Classes do All.Add(D);
    for D in AProject.Members do
      if TMemberDef(D).Kind <> memEnumValue then
        All.Add(D);
    for D in AProject.Groups do All.Add(D);
    for D in AProject.Pages do All.Add(D);
    for D in All do
    begin
      if (D.Entry = nil) or not AProject.IsVisible(D) then
        Continue;
      File_ := D.Entry.FileName;
      Line := D.Entry.Line;
      if not D.IsDocumented then
      begin
        if AProject.Options.WarnIfUndocumented and not AProject.Options.ExtractAll then
          AProject.Warn(File_, Line, Format('%s %s is not documented.', [EntryKindName(D.Entry.Kind), DescribeWhere(D)]));
        Continue;
      end;
      if not AProject.Options.WarnIfDocError then
        Continue;
      Doc.Clear;
      Root := ParseDoc(D.Brief + #10#10 + D.Detailed, Doc);
      try
        for N in Doc do
          AProject.Warn(File_, D.Entry.DocLine, N);
        // unresolved references
        Refs.Clear;
        CollectRefs(Root, Refs);
        for R in Refs do
          if (R.Text <> '') and (AProject.Lookup(R.Text, D) = nil) and (AProject.FindGroup(R.Text) = nil) and
            not PageExists(AProject, R.Text) then
            AProject.Warn(File_, Line, Format('unable to resolve reference to ''%s'' for \ref command', [R.Text]));
        // \param names against the argument list
        if (D is TMemberDef) and (TMemberDef(D).Kind = memFunction) then
        begin
          M := TMemberDef(D);
          Names.Clear;
          CollectParams(Root, 'param', Names);
          for N in Names do
          begin
            Found := False;
            for A in M.Entry.Args do
              if SameText(A.Name, N) then
                Found := True;
            if not Found then
              AProject.Warn(File_, Line, Format('argument ''%s'' of command @param is not found in the argument list of %s%s',
                [N, M.QualifiedName, M.Signature]));
          end;
          if AProject.Options.WarnNoParamDoc and (Names.Count > 0) then
            for A in M.Entry.Args do
              if Names.IndexOf(A.Name) < 0 then
                AProject.Warn(File_, Line, Format('parameter ''%s'' of %s is not documented', [A.Name, M.QualifiedName]));
        end;
      finally
        Root.Free;
      end;
    end;
  finally
    Doc.Free;
    Names.Free;
    Refs.Free;
    All.Free;
  end;
end;

{ ------------------------------------------------------------------ driver }

procedure BuildModel(AProject: TProject);
var
  B: TBuilder;
begin
  B := TBuilder.Create(AProject);
  try
    B.Run;
  finally
    B.Free;
  end;
  Lap('model: builder');
  ResolveUses(AProject);
  Lap('model: uses');
  ResolveBases(AProject);
  Lap('model: bases');
  ResolveAccessors(AProject);
  Lap('model: accessors');
  BuildMemberLists(AProject);
  Lap('model: member lists');
  ResolveReimplementations(AProject);
  Lap('model: reimplementations');
  InheritDocs(AProject);
  Lap('model: inherit docs');
  ResolveCopyDocs(AProject);
  Lap('model: copydoc');
  AssignGroups(AProject);
  Lap('model: groups');
  AssignDiskNames(AProject);
  Lap('model: disk names');
  ValidateDocs(AProject);
  Lap('model: validate docs');
end;

end.
