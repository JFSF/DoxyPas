unit DoxyPas.Lang.Pascal.Parser;

{ Object Pascal front end: DelphiAST gives the structure of a unit, DoxyPas.Lang.Pascal.Source gives the exact
  source text (types, default values, directives) and DoxyPas.Lang.Pascal.DocBlocks the documentation comments.
  The result is a tree of TEntry. }

interface

uses
  System.SysUtils,
  DoxyPas.Model.Entry;

type
  TPascalParseOptions = record
    Defines: TArray<string>;      // conditional symbols that are defined
    IncludePaths: TArray<string>; // searched for {$I file} after the directory of the source file
    InterfaceOnly: Boolean;       // stop at "implementation" (faster; no implementation-only entities)
    class function Default: TPascalParseOptions; static;
  end;

  TPascalParseResult = record
    Root: TEntry;          // the unit; never nil for a successful tokenisation (partial after a syntax error)
    ErrorMessage: string;  // empty if the unit was parsed completely
    ErrorLine, ErrorCol: Integer;
  end;

/// <summary>Conditional symbols a Delphi/FPC compiler defines for the given dialect ("Delphi"/"FPC") and
/// platform ("Win32", "Win64", "Linux64", "macOS", "iOS", "Android").</summary>
function DefaultPascalDefines(const ADialect, APlatform: string): TArray<string>;

/// <summary>Parses Object Pascal source text. The caller owns Result.Root.</summary>
function ParsePascalText(const AText, AFileName: string; const AOptions: TPascalParseOptions): TPascalParseResult;

/// <summary>Reads and parses a source file (UTF-8 with or without BOM, else the ANSI code page).</summary>
function ParsePascalFile(const AFileName: string; const AOptions: TPascalParseOptions): TPascalParseResult;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  SimpleParser.Lexer.Types,
  DelphiAST,
  DelphiAST.Classes,
  DelphiAST.Consts,
  DoxyPas.Lang.Pascal.Source,
  DoxyPas.Lang.Pascal.DocBlocks;

{ TPascalParseOptions }

class function TPascalParseOptions.Default: TPascalParseOptions;
begin
  Result.Defines := DefaultPascalDefines('Delphi', 'Win64');
  Result.IncludePaths := nil;
  Result.InterfaceOnly := False;
end;

function DefaultPascalDefines(const ADialect, APlatform: string): TArray<string>;
var
  L: TList<string>;
begin
  L := TList<string>.Create;
  try
    if SameText(ADialect, 'FPC') then
    begin
      L.AddRange(['FPC', 'FPC_FULLVERSION', 'UNICODE', 'CPU64']);
    end
    else
      L.AddRange(['VER370', 'CONDITIONALEXPRESSIONS', 'UNICODE', 'NATIVECODE', 'CONSOLE']);
    if SameText(APlatform, 'Win32') then
      L.AddRange(['WIN32', 'MSWINDOWS', 'CPU386', 'CPUX86', 'CPU32BITS'])
    else if SameText(APlatform, 'Win64') then
      L.AddRange(['WIN64', 'MSWINDOWS', 'CPUX64', 'CPU64BITS'])
    else if SameText(APlatform, 'Linux64') then
      L.AddRange(['LINUX', 'LINUX64', 'POSIX', 'POSIX64', 'CPUX64', 'CPU64BITS', 'ELF'])
    else if SameText(APlatform, 'macOS') then
      L.AddRange(['MACOS', 'MACOS64', 'POSIX', 'POSIX64', 'CPUX64', 'CPU64BITS'])
    else if SameText(APlatform, 'iOS') then
      L.AddRange(['IOS', 'IOS64', 'POSIX', 'POSIX64', 'CPUARM64', 'CPU64BITS'])
    else if SameText(APlatform, 'Android') then
      L.AddRange(['ANDROID', 'ANDROID64', 'POSIX', 'POSIX64', 'CPUARM64', 'CPU64BITS']);
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

type
  TIncludeHandler = class(TInterfacedObject, IIncludeHandler)
  strict private
    FDirs: TArray<string>;
  public
    constructor Create(const ADirs: TArray<string>);
    function GetIncludeFileContent(const ParentFileName, IncludeName: string; out Content: string;
      out FileName: string): Boolean;
  end;

constructor TIncludeHandler.Create(const ADirs: TArray<string>);
begin
  inherited Create;
  FDirs := ADirs;
end;

function TIncludeHandler.GetIncludeFileContent(const ParentFileName, IncludeName: string; out Content: string;
  out FileName: string): Boolean;
var
  Dir, F: string;
begin
  Result := False;
  for Dir in FDirs do
  begin
    F := TPath.Combine(Dir, IncludeName);
    if TFile.Exists(F) then
    begin
      FileName := F;
      Content := TFile.ReadAllText(F);
      Exit(True);
    end;
  end;
end;

function DecodeSource(const ABytes: TBytes): string; forward;

type
  { Turns the DelphiAST tree into TEntry objects. }
  TEntryBuilder = class
  strict private
    FMain: TPasSource;
    FSrc: TPasSource;           // source of the node being processed (main file or include file)
    FFileName: string;
    FIncluded: TObjectDictionary<string, TPasSource>;
    FPendingAttrs: TList<string>;
    procedure Use(ANode: TSyntaxNode);
    function NodeName(ANode: TSyntaxNode): string;
    function TokAt(ANode: TSyntaxNode): Integer;
    function NewEntry(AKind: TEntryKind; const AName: string; ANode: TSyntaxNode): TEntry;
    procedure TakeAttributes(AEntry: TEntry);
    procedure SetEnd(AEntry: TEntry; ATok: Integer);
    procedure ReadArguments(AParams: TSyntaxNode; AEntry: TEntry);
    procedure ReadTypeParams(ANode: TSyntaxNode; AEntry: TEntry);
    function ReadAttributes(ANode: TSyntaxNode): string;
    procedure ReadDirectives(AEntry: TEntry; AFromTok: Integer);
    function FieldIsClassMember(ANameTok: Integer): Boolean;
    procedure DoUses(AUnit: TEntry; ANode: TSyntaxNode; AImpl: Boolean);
    procedure DoMethod(AParent: TEntry; ANode: TSyntaxNode; AProt: TProtection; AImpl: Boolean);
    procedure DoVarLike(AParent: TEntry; ANode: TSyntaxNode; AKind: TEntryKind; AProt: TProtection;
      AFlags: TEntryFlags; AImpl: Boolean);
    procedure DoProperty(AParent: TEntry; ANode: TSyntaxNode; AProt: TProtection);
    procedure DoTypeSection(AParent: TEntry; ANode: TSyntaxNode; AImpl: Boolean);
    procedure DoTypeDecl(AParent: TEntry; ANode: TSyntaxNode; AImpl: Boolean);
    procedure DoClassBody(AEntry: TEntry; ATypeNode: TSyntaxNode);
    procedure DoMembers(AParent: TEntry; ANode: TSyntaxNode; AProt: TProtection);
    procedure DoEnum(AEnum: TEntry; ATypeNode: TSyntaxNode);
    procedure DoConstants(AParent: TEntry; ANode: TSyntaxNode; AProt: TProtection; AImpl: Boolean);
    procedure DoVariables(AParent: TEntry; ANode: TSyntaxNode; AProt: TProtection; AImpl: Boolean);
    procedure DoContainer(AParent: TEntry; ANode: TSyntaxNode; AImpl: Boolean);
  public
    constructor Create(ASource: TPasSource; const AFileName: string);
    destructor Destroy; override;
    function Build(ATree: TSyntaxNode): TEntry;
  end;

const
  DirectiveWords: array[0..30] of string = ('virtual', 'dynamic', 'override', 'abstract', 'final', 'static',
    'inline', 'overload', 'reintroduce', 'deprecated', 'platform', 'experimental', 'library', 'stdcall', 'cdecl',
    'register', 'pascal', 'safecall', 'winapi', 'varargs', 'external', 'message', 'export', 'far', 'near',
    'assembler', 'forward', 'local', 'unsafe', 'delayed', 'dispid');

function IsDirectiveWord(const AWord: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(DirectiveWords) do
    if DirectiveWords[I] = AWord then
      Exit(True);
  Result := False;
end;

{ TEntryBuilder }

constructor TEntryBuilder.Create(ASource: TPasSource; const AFileName: string);
begin
  inherited Create;
  FMain := ASource;
  FSrc := ASource;
  FFileName := AFileName;
  FIncluded := TObjectDictionary<string, TPasSource>.Create([doOwnsValues]);
  FPendingAttrs := TList<string>.Create;
end;

destructor TEntryBuilder.Destroy;
begin
  FPendingAttrs.Free;
  FIncluded.Free;
  inherited;
end;

// Positions of a node refer to the file it came from: the unit itself or an include file.
procedure TEntryBuilder.Use(ANode: TSyntaxNode);
var
  Key: string;
  S: TPasSource;
begin
  if ANode.FileName = '' then
  begin
    FSrc := FMain;
    Exit;
  end;
  Key := LowerCase(ANode.FileName);
  if not FIncluded.TryGetValue(Key, S) then
  begin
    try
      S := TPasSource.Create(DecodeSource(TFile.ReadAllBytes(ANode.FileName)));
    except
      S := TPasSource.Create('');
    end;
    FIncluded.Add(Key, S);
  end;
  FSrc := S;
end;

function TEntryBuilder.NodeName(ANode: TSyntaxNode): string;
begin
  if ANode is TValuedSyntaxNode then
    Result := TValuedSyntaxNode(ANode).Value
  else
    Result := ANode.GetAttribute(anName);
end;

function TEntryBuilder.TokAt(ANode: TSyntaxNode): Integer;
begin
  Result := FSrc.IndexAt(ANode.Line, ANode.Col);
end;

function TEntryBuilder.NewEntry(AKind: TEntryKind; const AName: string; ANode: TSyntaxNode): TEntry;
begin
  Result := TEntry.Create(AKind, AName);
  if ANode.FileName <> '' then
    Result.FileName := ANode.FileName
  else
    Result.FileName := FFileName;
  Result.Line := ANode.Line;
  Result.Col := ANode.Col;
end;

procedure TEntryBuilder.TakeAttributes(AEntry: TEntry);
begin
  if FPendingAttrs.Count > 0 then
    AEntry.WriteAttributes.AddRange(FPendingAttrs);
  FPendingAttrs.Clear;
end;

procedure TEntryBuilder.SetEnd(AEntry: TEntry; ATok: Integer);
begin
  AEntry.EndLine := FSrc.Token(ATok).EndLine;
  AEntry.EndCol := FSrc.Token(ATok).EndCol;
end;

{ Text between the brackets of an attribute list that starts at ANode. }
function TEntryBuilder.ReadAttributes(ANode: TSyntaxNode): string;
var
  T, E: Integer;
begin
  Use(ANode);
  T := TokAt(ANode);
  if not FSrc.IsSymbol(T, '[') then
    Exit('');
  E := FSrc.ScanTo(T + 1, ']', [], False);
  Result := FSrc.Slice(T + 1, E);
end;

procedure TEntryBuilder.ReadArguments(AParams: TSyntaxNode; AEntry: TEntry);
var
  P: TSyntaxNode;
  A: TArgument;
  T, TypeStart, TypeEnd: Integer;
  NameNode: TSyntaxNode;
begin
  if AParams = nil then
    Exit;
  for P in AParams.ChildNodes do
  begin
    if P.Typ <> ntParameter then
      Continue;
    A := Default(TArgument);
    NameNode := P.FindNode(ntName);
    if NameNode = nil then
      Continue;
    A.Name := NodeName(NameNode);
    A.Modifier := P.GetAttribute(anKind);
    T := TokAt(NameNode);
    // "A, B: Integer": walk to the colon of this parameter group
    T := FSrc.ScanTo(T, ':;)]=', [], False);
    if FSrc.IsSymbol(T, ':') then
    begin
      TypeStart := FSrc.NextCode(T);
      TypeEnd := FSrc.ScanTo(TypeStart, ';)]=', [], True);
      A.TypeText := FSrc.Slice(TypeStart, TypeEnd);
      if FSrc.IsSymbol(TypeEnd, '=') then
        A.DefaultText := FSrc.Slice(TypeEnd + 1, FSrc.ScanTo(TypeEnd + 1, ';)]', [], False));
    end;
    AEntry.WriteArgs.Add(A);
  end;
end;

procedure TEntryBuilder.ReadTypeParams(ANode: TSyntaxNode; AEntry: TEntry);
var
  Params, P, C: TSyntaxNode;
  TP: TTypeParam;
  S: string;
begin
  Params := ANode.FindNode(ntTypeParams);
  if Params = nil then
    Exit;
  for P in Params.ChildNodes do
  begin
    if P.Typ <> ntTypeParam then
      Continue;
    TP := Default(TTypeParam);
    if P.FindNode(ntType) <> nil then
      TP.Name := P.FindNode(ntType).GetAttribute(anName);
    if P.FindNode(ntConstraints) <> nil then
      for C in P.FindNode(ntConstraints).ChildNodes do
      begin
        case C.Typ of
          ntClassConstraint: S := 'class';
          ntRecordConstraint: S := 'record';
          ntConstructorConstraint: S := 'constructor';
        else
          S := C.GetAttribute(anName);
        end;
        if TP.Constraints <> '' then
          TP.Constraints := TP.Constraints + ', ';
        TP.Constraints := TP.Constraints + S;
      end;
    AEntry.WriteTypeParams.Add(TP);
  end;
end;

{ Directives that follow a routine heading: "; virtual; stdcall; deprecated 'x';" }
procedure TEntryBuilder.ReadDirectives(AEntry: TEntry; AFromTok: Integer);
var
  T, E: Integer;
  W: string;
begin
  // AFromTok is the ';' that ends the heading
  SetEnd(AEntry, AFromTok);
  T := FSrc.NextCode(AFromTok);
  while FSrc.Token(T).Kind = tkIdent do
  begin
    W := LowerCase(FSrc.TokenText(T));
    if not IsDirectiveWord(W) then
      Break;
    E := FSrc.ScanTo(T + 1, ';', [], False);
    if W = 'virtual' then AEntry.Virtualness := vtVirtual
    else if W = 'dynamic' then AEntry.Virtualness := vtDynamic
    else if W = 'override' then AEntry.Virtualness := vtOverride
    else if W = 'abstract' then Include(AEntry.Flags, efAbstract)
    else if W = 'final' then Include(AEntry.Flags, efFinal)
    else if W = 'static' then Include(AEntry.Flags, efStatic)
    else if W = 'inline' then Include(AEntry.Flags, efInline)
    else if W = 'overload' then Include(AEntry.Flags, efOverload)
    else if W = 'reintroduce' then Include(AEntry.Flags, efReintroduce)
    else if W = 'platform' then Include(AEntry.Flags, efPlatform)
    else if W = 'experimental' then Include(AEntry.Flags, efExperimental)
    else if W = 'library' then Include(AEntry.Flags, efLibrary)
    else if W = 'deprecated' then
    begin
      Include(AEntry.Flags, efDeprecated);
      AEntry.DeprecatedMsg := FSrc.Slice(T + 1, E);
    end
    else if (W = 'stdcall') or (W = 'cdecl') or (W = 'register') or (W = 'pascal') or (W = 'safecall') or
      (W = 'winapi') or (W = 'varargs') then
      AEntry.CallConv := W
    else if W = 'external' then
    begin
      Include(AEntry.Flags, efExternal);
      AEntry.ExternalText := FSrc.Slice(T + 1, E);
    end
    else if W = 'forward' then
      Include(AEntry.Flags, efForward)
    else
      AEntry.WriteDirectives.Add(FSrc.Slice(T, E));
    if not FSrc.IsSymbol(E, ';') then
      Break;
    SetEnd(AEntry, E);
    T := FSrc.NextCode(E);
  end;
end;

{ True for fields declared in a "class var" block. }
function TEntryBuilder.FieldIsClassMember(ANameTok: Integer): Boolean;
var
  I: Integer;
  W: string;
begin
  Result := False;
  I := ANameTok;
  while I > 0 do
  begin
    I := FSrc.PrevCode(I);
    if FSrc.Token(I).Kind <> tkIdent then
      Continue;
    W := LowerCase(FSrc.TokenText(I));
    if W = 'var' then
      Exit(FSrc.IsWord(FSrc.PrevCode(I), 'class'));
    if (W = 'private') or (W = 'protected') or (W = 'public') or (W = 'published') or (W = 'strict') or
      (W = 'type') or (W = 'const') or (W = 'procedure') or (W = 'function') or (W = 'property') or
      (W = 'constructor') or (W = 'destructor') or (W = 'end') or (W = 'begin') or (W = 'record') or
      (W = 'class') or (W = 'object') or (W = 'interface') then
      Exit(False);
  end;
end;

procedure TEntryBuilder.DoUses(AUnit: TEntry; ANode: TSyntaxNode; AImpl: Boolean);
var
  U: TSyntaxNode;
begin
  for U in ANode.ChildNodes do
    if U.Typ = ntUnit then
      if AImpl then
        AUnit.WriteUsesImplementation.Add(U.GetAttribute(anName))
      else
        AUnit.WriteUsesInterface.Add(U.GetAttribute(anName));
end;

procedure TEntryBuilder.DoMethod(AParent: TEntry; ANode: TSyntaxNode; AProt: TProtection; AImpl: Boolean);
var
  E: TEntry;
  Name, W: string;
  T, HeadEnd, RT, Lt: Integer;
  Ret: TSyntaxNode;
  TP: TTypeParam;
begin
  Use(ANode);
  Name := ANode.GetAttribute(anName);
  Lt := Pos('<', Name);
  E := NewEntry(ekMethod, Name, ANode);
  if Lt > 0 then
    E.Name := Copy(Name, 1, Lt - 1);
  E.Protection := AProt;
  if AImpl then
    Include(E.Flags, efImplementation);
  TakeAttributes(E);
  // kind and "class" prefix from the source: [class] procedure|function|constructor|destructor|operator
  T := TokAt(ANode);
  if FSrc.IsWord(T, 'class') then
  begin
    Include(E.Flags, efClassMember);
    T := FSrc.NextCode(T);
  end;
  W := LowerCase(FSrc.TokenText(T));
  if W = 'function' then E.MethodKind := rkFunction
  else if W = 'constructor' then E.MethodKind := rkConstructor
  else if W = 'destructor' then E.MethodKind := rkDestructor
  else if W = 'operator' then E.MethodKind := rkOperator
  else E.MethodKind := rkProcedure;
  // generic methods: Make<U>
  if Lt > 0 then
  begin
    ReadTypeParams(ANode, E);
    if E.TypeParams.Count = 0 then
    begin
      TP.Name := Copy(Name, Lt + 1, Length(Name) - Lt - 1);
      TP.Constraints := '';
      E.WriteTypeParams.Add(TP);
    end;
  end;
  ReadArguments(ANode.FindNode(ntParameters), E);
  Ret := ANode.FindNode(ntReturnType);
  HeadEnd := FSrc.ScanTo(T, ';', [], False);
  if Ret <> nil then
  begin
    RT := TokAt(Ret);
    E.TypeText := FSrc.Slice(RT, FSrc.ScanTo(RT, ';', [], True));
  end;
  ReadDirectives(E, HeadEnd);
  if ANode.HasAttribute(anAbstract) then
    Include(E.Flags, efAbstract);
  AParent.Add(E);
end;

{ Variables, fields and constants share "Name[, Name]: Type [= Value]". }
procedure TEntryBuilder.DoVarLike(AParent: TEntry; ANode: TSyntaxNode; AKind: TEntryKind; AProt: TProtection;
  AFlags: TEntryFlags; AImpl: Boolean);
var
  NameNode: TSyntaxNode;
  E: TEntry;
  T, TypeStart, TypeEnd, Stop: Integer;
begin
  Use(ANode);
  NameNode := ANode.FindNode(ntName);
  if NameNode = nil then
    Exit;
  E := NewEntry(AKind, NodeName(NameNode), NameNode);
  E.Protection := AProt;
  E.Flags := AFlags;
  if AImpl then
    Include(E.Flags, efImplementation);
  TakeAttributes(E);
  T := TokAt(NameNode);
  if (AKind = ekField) and FieldIsClassMember(T) then
    Include(E.Flags, efClassMember);
  Stop := FSrc.ScanTo(T, ':;=', [], False);
  if FSrc.IsSymbol(Stop, ':') then
  begin
    TypeStart := FSrc.NextCode(Stop);
    TypeEnd := FSrc.ScanTo(TypeStart, ';=', ['deprecated', 'platform', 'experimental', 'library', 'absolute'], True);
    E.TypeText := FSrc.Slice(TypeStart, TypeEnd);
    Stop := TypeEnd;
    if AKind = ekConstant then
      Include(E.Flags, efTypedConst);
  end;
  if FSrc.IsSymbol(Stop, '=') then
  begin
    TypeEnd := FSrc.ScanTo(Stop + 1, ';', ['deprecated', 'platform', 'experimental', 'library'], False);
    E.InitText := FSrc.Slice(Stop + 1, TypeEnd);
    Stop := TypeEnd;
  end;
  // skip trailing hint directives up to the ';'
  Stop := FSrc.ScanTo(Stop, ';', [], False);
  SetEnd(E, Stop);
  AParent.Add(E);
end;

procedure TEntryBuilder.DoProperty(AParent: TEntry; ANode: TSyntaxNode; AProt: TProtection);
var
  E: TEntry;
  T, Stop, TypeStart, Nxt: Integer;
  W: string;
begin
  Use(ANode);
  E := NewEntry(ekProperty, ANode.GetAttribute(anName), ANode);
  E.Protection := AProt;
  TakeAttributes(E);
  T := TokAt(ANode);
  if FSrc.IsWord(T, 'class') then
  begin
    Include(E.Flags, efClassMember);
    T := FSrc.NextCode(T);
  end;
  ReadArguments(ANode.FindNode(ntParameters), E);
  // property Name [params] : Type [index N] [read X] [write Y] [stored Z] [default V] [implements I] ;
  Stop := FSrc.ScanTo(T + 1, ':;', ['read', 'write'], False);
  if FSrc.IsSymbol(Stop, ':') then
  begin
    TypeStart := FSrc.NextCode(Stop);
    Stop := FSrc.ScanTo(TypeStart, ';', ['index', 'read', 'write', 'stored', 'default', 'nodefault', 'implements',
      'readonly', 'writeonly', 'dispid', 'deprecated', 'platform', 'experimental'], True);
    E.TypeText := FSrc.Slice(TypeStart, Stop);
  end;
  while (Stop < FSrc.Count - 1) and not FSrc.IsSymbol(Stop, ';') do
  begin
    W := LowerCase(FSrc.TokenText(Stop));
    Nxt := FSrc.ScanTo(Stop + 1, ';', ['index', 'read', 'write', 'stored', 'default', 'nodefault', 'implements',
      'readonly', 'writeonly', 'dispid', 'deprecated', 'platform', 'experimental'], False);
    if W = 'read' then E.ReadAccessor := FSrc.Slice(Stop + 1, Nxt)
    else if W = 'write' then E.WriteAccessor := FSrc.Slice(Stop + 1, Nxt)
    else if W = 'index' then E.IndexText := FSrc.Slice(Stop + 1, Nxt)
    else if W = 'stored' then E.StoredText := FSrc.Slice(Stop + 1, Nxt)
    else if W = 'default' then E.InitText := FSrc.Slice(Stop + 1, Nxt)
    else if W = 'deprecated' then
    begin
      Include(E.Flags, efDeprecated);
      E.DeprecatedMsg := FSrc.Slice(Stop + 1, Nxt);
    end
    else
      E.WriteDirectives.Add(FSrc.Slice(Stop, Nxt));
    if Nxt = Stop then
      Break;
    Stop := Nxt;
  end;
  SetEnd(E, Stop);
  // "default;" after the property marks the default (array) property
  Nxt := FSrc.NextCode(Stop);
  if FSrc.IsWord(Nxt, 'default') and FSrc.IsSymbol(FSrc.NextCode(Nxt), ';') then
  begin
    Include(E.Flags, efDefaultProperty);
    SetEnd(E, FSrc.NextCode(Nxt));
  end;
  AParent.Add(E);
end;

procedure TEntryBuilder.DoEnum(AEnum: TEntry; ATypeNode: TSyntaxNode);
var
  N: TSyntaxNode;
  V: TEntry;
  T, Stop: Integer;
begin
  for N in ATypeNode.ChildNodes do
  begin
    if N.Typ <> ntIdentifier then
      Continue;
    Use(N);
    V := NewEntry(ekEnumValue, N.GetAttribute(anName), N);
    T := TokAt(N);
    Stop := FSrc.NextCode(T);
    if FSrc.IsSymbol(Stop, '=') then
    begin
      Stop := FSrc.ScanTo(Stop + 1, ',)', [], False);
      V.InitText := FSrc.Slice(FSrc.NextCode(T) + 1, Stop);
    end;
    if FSrc.IsSymbol(Stop, ',') then
      SetEnd(V, Stop)
    else
      SetEnd(V, FSrc.PrevCode(Stop));
    AEnum.Add(V);
  end;
end;

procedure TEntryBuilder.DoConstants(AParent: TEntry; ANode: TSyntaxNode; AProt: TProtection; AImpl: Boolean);
var
  C: TSyntaxNode;
begin
  for C in ANode.ChildNodes do
    case C.Typ of
      ntConstant:
        DoVarLike(AParent, C, ekConstant, AProt, [], AImpl);
      ntResourceString:
        DoVarLike(AParent, C, ekConstant, AProt, [efResourceString], AImpl);
      ntAttributes:
        FPendingAttrs.Add(ReadAttributes(C));
    end;
end;

procedure TEntryBuilder.DoVariables(AParent: TEntry; ANode: TSyntaxNode; AProt: TProtection; AImpl: Boolean);
var
  V: TSyntaxNode;
  Fl: TEntryFlags;
begin
  Fl := [];
  if FSrc.IsWord(TokAt(ANode), 'threadvar') then
    Include(Fl, efThreadVar);
  for V in ANode.ChildNodes do
    case V.Typ of
      ntVariable: DoVarLike(AParent, V, ekField, AProt, Fl, AImpl);
      ntAttributes: FPendingAttrs.Add(ReadAttributes(V));
    end;
end;

procedure TEntryBuilder.DoMembers(AParent: TEntry; ANode: TSyntaxNode; AProt: TProtection);
var
  M: TSyntaxNode;
begin
  for M in ANode.ChildNodes do
    case M.Typ of
      ntField: DoVarLike(AParent, M, ekField, AProt, [], False);
      ntMethod: DoMethod(AParent, M, AProt, False);
      ntProperty: DoProperty(AParent, M, AProt);
      ntTypeSection: DoTypeSection(AParent, M, False);
      ntConstants: DoConstants(AParent, M, AProt, False);
      ntVariables: DoVariables(AParent, M, AProt, False);
      ntAttributes: FPendingAttrs.Add(ReadAttributes(M));
    end;
end;

procedure TEntryBuilder.DoClassBody(AEntry: TEntry; ATypeNode: TSyntaxNode);
var
  N: TSyntaxNode;
  Prot: TProtection;
begin
  for N in ATypeNode.ChildNodes do
  begin
    case N.Typ of
      ntType:
        AEntry.WriteBases.Add(N.GetAttribute(anName));
      ntHelper:
        if N.FindNode(ntType) <> nil then
          AEntry.HelperFor := N.FindNode(ntType).GetAttribute(anName);
      ntGuid:
        if N.FindNode(ntLiteral) <> nil then
          AEntry.GuidText := (N.FindNode(ntLiteral) as TValuedSyntaxNode).Value;
      ntPublic, ntProtected, ntPrivate, ntPublished, ntStrictPrivate, ntStrictProtected:
        begin
          case N.Typ of
            ntPublic: Prot := prPublic;
            ntProtected: Prot := prProtected;
            ntPrivate: Prot := prPrivate;
            ntPublished: Prot := prPublished;
            ntStrictPrivate: Prot := prStrictPrivate;
          else
            Prot := prStrictProtected;
          end;
          DoMembers(AEntry, N, Prot);
        end;
      ntField: DoVarLike(AEntry, N, ekField, prPublic, [], False);
      ntMethod: DoMethod(AEntry, N, prPublic, False);
      ntProperty: DoProperty(AEntry, N, prPublic);
      ntTypeSection: DoTypeSection(AEntry, N, False);
      ntConstants: DoConstants(AEntry, N, prPublic, False);
      ntVariables: DoVariables(AEntry, N, prPublic, False);
      ntAttributes: FPendingAttrs.Add(ReadAttributes(N));
    end;
  end;
end;

procedure TEntryBuilder.DoTypeDecl(AParent: TEntry; ANode: TSyntaxNode; AImpl: Boolean);
var
  E: TEntry;
  TypeNode: TSyntaxNode;
  TypeName: string;
  NameTok, Rhs, Eq, EndTok, T: Integer;
  IsClassLike: Boolean;
begin
  Use(ANode);
  TypeNode := ANode.FindNode(ntType);
  E := NewEntry(ekTypeAlias, ANode.GetAttribute(anName), ANode);
  if AImpl then
    Include(E.Flags, efImplementation);
  TakeAttributes(E);
  ReadTypeParams(ANode, E);
  NameTok := TokAt(ANode);
  // right-hand side: first code token after the "=" that follows the name (and its <type params>)
  Eq := FSrc.ScanTo(NameTok + 1, '=;', [], True);
  if FSrc.IsSymbol(Eq, '=') then
    Rhs := FSrc.NextCode(Eq)
  else
    Rhs := Eq;
  // end of the declaration: DelphiAST's end position lies on (class-like) or just after the ';'
  EndTok := FSrc.PrevCode(Rhs);
  if ANode is TCompoundSyntaxNode then
  begin
    T := FSrc.IndexAt(TCompoundSyntaxNode(ANode).EndLine, TCompoundSyntaxNode(ANode).EndCol);
    if FSrc.IsSymbol(T, ';') then
      EndTok := T
    else
      EndTok := FSrc.PrevCode(T);
  end;
  SetEnd(E, EndTok);

  if ANode.GetAttribute(anForwarded) = 'true' then
  begin
    Include(E.Flags, efForward);
    E.Kind := ekClass;
    AParent.Add(E);
    Exit;
  end;

  TypeName := '';
  IsClassLike := False;
  if TypeNode <> nil then
    TypeName := TypeNode.GetAttribute(anType);
  IsClassLike := (TypeNode <> nil) and ((TypeName = 'class') or (TypeName = 'record') or
    (TypeName = 'interface') or (TypeName = 'dispinterface') or (TypeName = 'object'));
  if (TypeNode <> nil) and (TypeNode.GetAttribute(anName) = 'enum') then
  begin
    E.Kind := ekEnum;
    DoEnum(E, TypeNode);
  end
  else if IsClassLike then
  begin
    E.Kind := ekClass;
    if TypeName = 'class' then E.ClassKind := ckClass
    else if TypeName = 'record' then E.ClassKind := ckRecord
    else if TypeName = 'object' then E.ClassKind := ckObject
    else if TypeName = 'dispinterface' then E.ClassKind := ckDispInterface
    else E.ClassKind := ckInterface;
    if TypeNode.FindNode(ntHelper) <> nil then
    begin
      if E.ClassKind = ckRecord then E.ClassKind := ckRecordHelper else E.ClassKind := ckClassHelper;
    end;
    // "class abstract" / "class sealed"
    T := Rhs;
    if FSrc.IsWord(T, 'packed') then
      T := FSrc.NextCode(T);
    T := FSrc.NextCode(T);
    if FSrc.IsWord(T, 'abstract') then Include(E.Flags, efAbstract)
    else if FSrc.IsWord(T, 'sealed') then Include(E.Flags, efSealed);
    DoClassBody(E, TypeNode);
  end
  else
    E.TypeText := FSrc.Slice(Rhs, FSrc.ScanTo(Rhs, ';', [], True));
  AParent.Add(E);
end;

procedure TEntryBuilder.DoTypeSection(AParent: TEntry; ANode: TSyntaxNode; AImpl: Boolean);
var
  N: TSyntaxNode;
begin
  for N in ANode.ChildNodes do
    case N.Typ of
      ntTypeDecl: DoTypeDecl(AParent, N, AImpl);
      ntAttributes: FPendingAttrs.Add(ReadAttributes(N));
    end;
end;

procedure TEntryBuilder.DoContainer(AParent: TEntry; ANode: TSyntaxNode; AImpl: Boolean);
var
  N: TSyntaxNode;
begin
  for N in ANode.ChildNodes do
    case N.Typ of
      ntUses: DoUses(AParent, N, AImpl);
      ntTypeSection: DoTypeSection(AParent, N, AImpl);
      ntConstants: DoConstants(AParent, N, prPublic, AImpl);
      ntVariables: DoVariables(AParent, N, prPublic, AImpl);
      ntMethod: DoMethod(AParent, N, prPublic, AImpl);
      ntAttributes: FPendingAttrs.Add(ReadAttributes(N));
      ntInterface: DoContainer(AParent, N, False);
      ntImplementation: DoContainer(AParent, N, True);
    end;
end;

function TEntryBuilder.Build(ATree: TSyntaxNode): TEntry;
var
  T: Integer;
begin
  Result := NewEntry(ekUnit, ATree.GetAttribute(anName), ATree);
  T := FSrc.NextCode(-1);
  Result.TypeText := LowerCase(FSrc.TokenText(T)); // unit, program, library or package
  DoContainer(Result, ATree, False);
  AttachDocComments(FMain, Result, FFileName);
end;

function DecodeSource(const ABytes: TBytes): string;
var
  Enc: TEncoding;
  Offset: Integer;
begin
  Enc := nil;
  Offset := TEncoding.GetBufferEncoding(ABytes, Enc, nil);
  if Enc = nil then
  begin
    // no BOM: UTF-8 if it decodes without replacement characters, else the ANSI code page
    try
      Result := TEncoding.UTF8.GetString(ABytes);
      if Result.IndexOf(#$FFFD) < 0 then
        Exit;
    except
      on EEncodingError do; // invalid UTF-8
    end;
    Enc := TEncoding.ANSI;
  end;
  Result := Enc.GetString(ABytes, Offset, Length(ABytes) - Offset);
end;

function ParsePascalText(const AText, AFileName: string; const AOptions: TPascalParseOptions): TPascalParseResult;
var
  Src: TPasSource;
  Builder: TPasSyntaxTreeBuilder;
  Stream: TStringStream;
  Tree: TSyntaxNode;
  EB: TEntryBuilder;
  D: string;
  Dirs: TArray<string>;
begin
  Result.Root := nil;
  Result.ErrorMessage := '';
  Result.ErrorLine := 0;
  Result.ErrorCol := 0;
  Src := TPasSource.Create(AText);
  Builder := TPasSyntaxTreeBuilder.Create;
  Stream := TStringStream.Create(AText, TEncoding.Unicode);
  EB := TEntryBuilder.Create(Src, AFileName);
  try
    for D in AOptions.Defines do
      Builder.AddDefine(D);
    Dirs := [ExtractFilePath(ExpandFileName(AFileName))] + AOptions.IncludePaths;
    Builder.IncludeHandler := TIncludeHandler.Create(Dirs);
    Builder.InterfaceOnly := AOptions.InterfaceOnly;
    try
      Tree := Builder.Run(Stream);
      try
        Result.Root := EB.Build(Tree);
      finally
        Tree.Free;
      end;
    except
      on E: ESyntaxTreeException do
      begin
        Result.ErrorMessage := E.Message;
        Result.ErrorLine := E.Line;
        Result.ErrorCol := E.Col;
        if E.SyntaxTree <> nil then
          Result.Root := EB.Build(E.SyntaxTree); // partial tree: what was parsed before the error
      end;
    end;
  finally
    EB.Free;
    Stream.Free;
    Builder.Free;
    Src.Free;
  end;
end;

function ParsePascalFile(const AFileName: string; const AOptions: TPascalParseOptions): TPascalParseResult;
begin
  Result := ParsePascalText(DecodeSource(TFile.ReadAllBytes(AFileName)), AFileName, AOptions);
end;

end.
