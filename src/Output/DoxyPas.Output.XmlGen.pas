unit DoxyPas.Output.XmlGen;

{ XML output (Doxygen's xmlgen): index.xml, one <id>.xml per class, unit, group and page, and the schemas.
  Units are written as kind="namespace" (they scope classes, routines and variables); "Pascal" is added to the
  language list of the bundled compound.xsd. }

interface

uses
  System.Classes,
  DoxyPas.Config,
  DoxyPas.Model.Project;

/// <summary>Writes the XML files into AOutDir (created if needed). Returns the number of files written.</summary>
function GenerateXml(AProject: TProject; AConfig: TConfig; const AOutDir: string): Integer;

/// <summary>"English" -> "en-US" (value of xml:lang).</summary>
function XmlLanguageCode(const ALanguage: string): string;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  DoxyPas.Core.Version,
  DoxyPas.Model.Entry,
  DoxyPas.Model.Defs,
  DoxyPas.Model.Links,
  DoxyPas.Output.XmlWriter,
  DoxyPas.Output.XmlDoc,
  DoxyPas.Resources.Xml;

const
  Header = ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"';

function XmlLanguageCode(const ALanguage: string): string;
const
  Names: array[0..13] of string = ('English', 'Portuguese', 'Brazilian', 'German', 'French', 'Spanish', 'Italian',
    'Dutch', 'Russian', 'Polish', 'Czech', 'Chinese', 'Japanese', 'Korean');
  Codes: array[0..13] of string = ('en-US', 'pt-PT', 'pt-BR', 'de-DE', 'fr-FR', 'es-ES', 'it-IT', 'nl-NL', 'ru-RU',
    'pl-PL', 'cs-CZ', 'zh-CN', 'ja-JP', 'ko-KR');
var
  I: Integer;
begin
  for I := 0 to High(Names) do
    if SameText(Names[I], ALanguage) then
      Exit(Codes[I]);
  Result := 'en-US';
end;

type
  TXmlGenerator = class
  strict private
    FProject: TProject;
    FConfig: TConfig;
    FLinks: TLinkResolver;
    FDir: string;
    FLang: string;
    FFiles: Integer;
    FW: TXmlWriter;
    FDoc: TXmlDocWriter;
    function ProtText(AProt: TProtection): string;
    function MemberKindText(M: TMemberDef): string;
    function SectionKind(M: TMemberDef; AInUnit: Boolean): string;
    function IsStaticMember(M: TMemberDef): Boolean;
    function VirtText(M: TMemberDef): string;
    function Routine(M: TMemberDef): string;
    function ArgsText(M: TMemberDef): string;
    function CompoundKind(C: TClassDef): string;
    function VisibleMembers(AList: TList<TMemberDef>): TList<TMemberDef>;
    procedure Begin_(const AWhat: string);
    procedure Finish(const AId: string);
    procedure WriteLocation(AEntry: TEntry; AImpl: TEntry);
    procedure WriteTypeParams(AEntry: TEntry; AScope: TDefinition);
    procedure WriteMember(M: TMemberDef);
    procedure WriteSections(AMembers: TList<TMemberDef>; AInUnit: Boolean);
    procedure WriteClass(C: TClassDef);
    procedure WriteUnit(U: TUnitDef);
    procedure WriteGroup(G: TGroupDef);
    procedure WritePage(P: TPageDef);
    procedure WriteIndex;
    procedure WriteSchemas;
    procedure SaveFile(const AFileName: string);
  public
    constructor Create(AProject: TProject; AConfig: TConfig; const ADir: string);
    destructor Destroy; override;
    function Run: Integer;
  end;

constructor TXmlGenerator.Create(AProject: TProject; AConfig: TConfig; const ADir: string);
begin
  inherited Create;
  FProject := AProject;
  FConfig := AConfig;
  FDir := ADir;
  FLinks := TLinkResolver.Create(AProject);
  FLang := XmlLanguageCode(AConfig.GetString('OUTPUT_LANGUAGE'));
end;

destructor TXmlGenerator.Destroy;
begin
  FLinks.Free;
  inherited;
end;

function TXmlGenerator.ProtText(AProt: TProtection): string;
begin
  case AProt of
    prProtected, prStrictProtected: Result := 'protected';
    prPrivate, prStrictPrivate: Result := 'private';
  else
    Result := 'public';
  end;
end;

function TXmlGenerator.MemberKindText(M: TMemberDef): string;
begin
  case M.Kind of
    memFunction: Result := 'function';
    memProperty: Result := 'property';
    memTypedef: Result := 'typedef';
    memEnumeration: Result := 'enum';
    memEnumValue: Result := 'enumvalue';
  else
    Result := 'variable';
  end;
end;

function TXmlGenerator.IsStaticMember(M: TMemberDef): Boolean;
begin
  Result := (M.Entry <> nil) and ([efClassMember, efStatic] * M.Entry.Flags <> []);
end;

{ public-func, private-static-attrib, ...; units use func, var, typedef, enum. }
function TXmlGenerator.SectionKind(M: TMemberDef; AInUnit: Boolean): string;
var
  P, What: string;
begin
  if M.Kind = memProperty then
    Exit('property');
  if AInUnit then
  begin
    case M.Kind of
      memTypedef: Result := 'typedef';
      memEnumeration: Result := 'enum';
      memFunction: Result := 'func';
    else
      Result := 'var';
    end;
    Exit;
  end;
  P := ProtText(M.Protection);
  case M.Kind of
    memTypedef, memEnumeration: What := 'type';
    memFunction: if IsStaticMember(M) then What := 'static-func' else What := 'func';
  else
    if IsStaticMember(M) then What := 'static-attrib' else What := 'attrib';
  end;
  Result := P + '-' + What;
end;

function TXmlGenerator.VirtText(M: TMemberDef): string;
begin
  if M.Entry = nil then
    Exit('non-virtual');
  if (efAbstract in M.Entry.Flags) and (M.Entry.Virtualness <> vtNormal) then
    Result := 'pure-virtual'
  else if M.Entry.Virtualness <> vtNormal then
    Result := 'virtual'
  else
    Result := 'non-virtual';
end;

function TXmlGenerator.Routine(M: TMemberDef): string;
begin
  case M.Entry.MethodKind of
    rkFunction: Result := 'function';
    rkConstructor: Result := 'constructor';
    rkDestructor: Result := 'destructor';
    rkOperator: Result := 'operator';
  else
    Result := 'procedure';
  end;
  if efClassMember in M.Entry.Flags then
    Result := 'class ' + Result;
end;

function TXmlGenerator.ArgsText(M: TMemberDef): string;
var
  A: TArgument;
  S: string;
begin
  Result := '';
  for A in M.Entry.Args do
  begin
    S := A.Name;
    if A.Modifier <> '' then
      S := A.Modifier + ' ' + S;
    if A.TypeText <> '' then
      S := S + ': ' + A.TypeText;
    if A.DefaultText <> '' then
      S := S + ' = ' + A.DefaultText;
    if Result <> '' then
      Result := Result + '; ';
    Result := Result + S;
  end;
  if Result <> '' then
    Result := '(' + Result + ')';
end;

function TXmlGenerator.CompoundKind(C: TClassDef): string;
begin
  case C.ClassKind of
    ckRecord, ckRecordHelper: Result := 'struct';
    ckInterface, ckDispInterface: Result := 'interface';
  else
    Result := 'class';
  end;
end;

function TXmlGenerator.VisibleMembers(AList: TList<TMemberDef>): TList<TMemberDef>;
var
  M: TMemberDef;
begin
  Result := TList<TMemberDef>.Create;
  for M in AList do
    if FProject.IsVisible(M) then
      Result.Add(M);
end;

procedure TXmlGenerator.Begin_(const AWhat: string);
begin
  FW := TXmlWriter.Create;
  FDoc := TXmlDocWriter.Create(FW, FLinks);
  FW.Declaration;
  FW.Open('doxygen', ['xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance',
    'xsi:noNamespaceSchemaLocation', AWhat, 'version', DoxyPasVersion, 'xml:lang', FLang]);
end;

procedure TXmlGenerator.Finish(const AId: string);
begin
  FW.NewLine;
  FW.Close('doxygen');
  FW.NewLine;
  SaveFile(AId + '.xml');
  FreeAndNil(FDoc);
  FreeAndNil(FW);
end;

procedure TXmlGenerator.SaveFile(const AFileName: string);
begin
  TFile.WriteAllText(TPath.Combine(FDir, AFileName), FW.ToString, TUTF8Encoding.Create(False));
  Inc(FFiles);
end;

procedure TXmlGenerator.WriteLocation(AEntry: TEntry; AImpl: TEntry);
begin
  FW.NewLine;
  if AEntry = nil then
  begin
    FW.Empty('location', []);
    Exit;
  end;
  if (AImpl <> nil) and (AImpl.FileName <> '') then
    FW.Empty('location', ['file', FProject.OutputPath(AEntry.FileName), 'line', AEntry.Line.ToString, 'column',
      AEntry.Col.ToString, 'bodyfile', FProject.OutputPath(AImpl.FileName), 'bodystart', AImpl.Line.ToString,
      'bodyend', AImpl.EndLine.ToString])
  else if AEntry.EndLine > 0 then
    FW.Empty('location', ['file', FProject.OutputPath(AEntry.FileName), 'line', AEntry.Line.ToString, 'column',
      AEntry.Col.ToString, 'bodyfile', FProject.OutputPath(AEntry.FileName), 'bodystart', AEntry.Line.ToString,
      'bodyend', AEntry.EndLine.ToString])
  else
    FW.Empty('location', ['file', FProject.OutputPath(AEntry.FileName), 'line', AEntry.Line.ToString, 'column',
      AEntry.Col.ToString]);
end;

procedure TXmlGenerator.WriteTypeParams(AEntry: TEntry; AScope: TDefinition);
var
  P: TTypeParam;
begin
  if (AEntry = nil) or (AEntry.TypeParams.Count = 0) then
    Exit;
  FW.NewLine;
  FW.Open('templateparamlist', []);
  for P in AEntry.TypeParams do
  begin
    FW.NewLine;
    FW.Open('param', []);
    FW.Leaf('type', P.Name, []);
    if P.Constraints <> '' then
      FW.Leaf('typeconstraint', P.Constraints, []);
    FW.Close('param');
  end;
  FW.NewLine;
  FW.Close('templateparamlist');
end;

procedure TXmlGenerator.WriteMember(M: TMemberDef);
var
  E: TEntry;
  A: TArgument;
  V: TMemberDef;
  Id, Def, Name: string;
  Attrs: TList<string>;
  O: TMemberDef;
begin
  E := M.Entry;
  Id := FLinks.RefIdOf(M);
  Attrs := TList<string>.Create;
  try
    Attrs.AddRange(['kind', MemberKindText(M), 'id', Id, 'prot', ProtText(M.Protection), 'static',
      YesNo(IsStaticMember(M))]);
    if M.Kind = memFunction then
    begin
      Attrs.AddRange(['inline', YesNo(efInline in E.Flags), 'virt', VirtText(M)]);
      if efFinal in E.Flags then
        Attrs.AddRange(['final', 'yes']);
    end
    else if M.Kind = memProperty then
      Attrs.AddRange(['readable', YesNo(E.ReadAccessor <> ''), 'writable', YesNo(E.WriteAccessor <> '')]);
    FW.NewLine;
    FW.Open('memberdef', Attrs.ToArray);
  finally
    Attrs.Free;
  end;
  if (M.Kind = memFunction) and (E.TypeParams.Count > 0) then
    WriteTypeParams(E, M);
  // type
  FW.NewLine;
  if M.Kind = memEnumeration then
    FW.Empty('type', [])
  else
    FDoc.LinkedText('type', E.TypeText, M, []);
  // definition and arguments
  if M.Scope is TClassDef then
    Name := M.Scope.Name + '.' + M.Name
  else
    Name := M.Name;
  case M.Kind of
    memFunction: Def := Routine(M) + ' ' + Name;
    memProperty: Def := 'property ' + Name;
    memTypedef: Def := 'type ' + Name;
    memEnumeration: Def := 'enum ' + Name;
    memConstant: Def := 'const ' + Name;
  else
    Def := Name;
  end;
  if (M.Kind = memVariable) and (E.TypeText <> '') then
    Def := Name + ': ' + E.TypeText;
  FW.NewLine;
  FW.Leaf('definition', Def, []);
  FW.NewLine;
  if M.Kind in [memFunction, memProperty] then
    FW.Leaf('argsstring', ArgsText(M), [])
  else
    FW.Leaf('argsstring', '', []);
  FW.NewLine;
  FW.Leaf('name', M.Name, []);
  FW.NewLine;
  FW.Leaf('qualifiedname', M.QualifiedName, []);
  if M.Kind = memProperty then
  begin
    if E.ReadAccessor <> '' then
    begin
      FW.NewLine;
      FW.Leaf('read', E.ReadAccessor, []);
    end;
    if E.WriteAccessor <> '' then
    begin
      FW.NewLine;
      FW.Leaf('write', E.WriteAccessor, []);
    end;
  end;
  if M.Reimplements <> nil then
  begin
    FW.NewLine;
    FW.Leaf('reimplements', M.Reimplements.Name, ['refid', FLinks.RefIdOf(M.Reimplements)]);
  end;
  for O in M.ReimplementedBy do
    if FProject.IsVisible(O) then
    begin
      FW.NewLine;
      FW.Leaf('reimplementedby', O.Name, ['refid', FLinks.RefIdOf(O)]);
    end;
  if M.Kind in [memFunction, memProperty] then
    for A in E.Args do
    begin
      FW.NewLine;
      FW.Open('param', []);
      if A.Modifier <> '' then
        FW.Leaf('attributes', A.Modifier, []);
      FDoc.LinkedText('type', A.TypeText, M, []);
      FW.Leaf('declname', A.Name, []);
      if A.DefaultText <> '' then
        FDoc.LinkedText('defval', A.DefaultText, M, []);
      FW.Close('param');
    end;
  for V in M.EnumValues do
  begin
    FW.NewLine;
    FW.Open('enumvalue', ['id', FLinks.RefIdOf(V), 'prot', ProtText(M.Protection)]);
    FW.Leaf('name', V.Name, []);
    if V.Entry.InitText <> '' then
      FDoc.LinkedText('initializer', '= ' + V.Entry.InitText, M, []);
    FDoc.Description('briefdescription', V.Brief, V);
    FDoc.Description('detaileddescription', V.Detailed, V);
    FW.Close('enumvalue');
  end;
  if (M.Kind in [memVariable, memConstant]) and (E.InitText <> '') then
  begin
    FW.NewLine;
    FDoc.LinkedText('initializer', '= ' + E.InitText, M, []);
  end;
  FW.NewLine;
  FDoc.Description('briefdescription', M.Brief, M);
  FW.NewLine;
  FDoc.Description('detaileddescription', M.Detailed, M);
  FW.NewLine;
  FW.Open('inbodydescription', []);
  FW.NewLine;
  FW.Close('inbodydescription');
  WriteLocation(E, M.Impl);
  FW.NewLine;
  FW.Close('memberdef');
end;

procedure TXmlGenerator.WriteSections(AMembers: TList<TMemberDef>; AInUnit: Boolean);
const
  UnitOrder: array[0..3] of string = ('typedef', 'enum', 'func', 'var');
  ClassKinds: array[0..4] of string = ('type', 'func', 'attrib', 'static-func', 'static-attrib');
  Prots: array[0..2] of string = ('public', 'protected', 'private');
var
  Order: TList<string>;
  Kind: string;
  M: TMemberDef;
  Any: Boolean;
  P, K: string;
begin
  Order := TList<string>.Create;
  try
    if AInUnit then
      Order.AddRange(UnitOrder)
    else
    begin
      for P in Prots do
        for K in ClassKinds do
          Order.Add(P + '-' + K);
      Order.Add('property');
    end;
    for Kind in Order do
    begin
      Any := False;
      for M in AMembers do
        if SectionKind(M, AInUnit) = Kind then
          Any := True;
      if not Any then
        Continue;
      FW.NewLine;
      FW.Open('sectiondef', ['kind', Kind]);
      for M in AMembers do
        if SectionKind(M, AInUnit) = Kind then
          WriteMember(M);
      FW.NewLine;
      FW.Close('sectiondef');
    end;
  finally
    Order.Free;
  end;
end;

procedure TXmlGenerator.WriteClass(C: TClassDef);
var
  B: TBaseRef;
  D, N: TClassDef;
  Vis: TList<TMemberDef>;
  IM: TInheritedMember;
  Attrs: TList<string>;
begin
  Begin_('compound.xsd');
  Attrs := TList<string>.Create;
  try
    Attrs.AddRange(['id', C.DiskName, 'kind', CompoundKind(C), 'language', 'Pascal', 'prot', ProtText(C.Protection)]);
    if (C.Entry <> nil) and (efAbstract in C.Entry.Flags) then
      Attrs.AddRange(['abstract', 'yes']);
    if (C.Entry <> nil) and (efSealed in C.Entry.Flags) then
      Attrs.AddRange(['sealed', 'yes']);
    FW.NewLine;
    FW.Open('compounddef', Attrs.ToArray);
  finally
    Attrs.Free;
  end;
  FW.NewLine;
  FW.Leaf('compoundname', C.QualifiedName, []);
  for B in C.Bases do
  begin
    FW.NewLine;
    if (B.ClassDef <> nil) and FLinks.IsLinkable(B.ClassDef) then
      FW.Leaf('basecompoundref', B.Text, ['refid', B.ClassDef.DiskName, 'prot', 'public', 'virt', 'non-virtual'])
    else
      FW.Leaf('basecompoundref', B.Text, ['prot', 'public', 'virt', 'non-virtual']);
  end;
  for D in C.Derived do
    if FLinks.IsLinkable(D) then
    begin
      FW.NewLine;
      FW.Leaf('derivedcompoundref', D.Name, ['refid', D.DiskName, 'prot', 'public', 'virt', 'non-virtual']);
    end;
  for N in C.NestedClasses do
    if FProject.IsVisible(N) then
    begin
      FW.NewLine;
      FW.Leaf('innerclass', N.QualifiedName, ['refid', N.DiskName, 'prot', ProtText(N.Protection)]);
    end;
  WriteTypeParams(C.Entry, C);
  Vis := VisibleMembers(C.Members);
  try
    WriteSections(Vis, False);
  finally
    Vis.Free;
  end;
  FW.NewLine;
  FDoc.Description('briefdescription', C.Brief, C);
  FW.NewLine;
  FDoc.Description('detaileddescription', C.Detailed, C);
  WriteLocation(C.Entry, nil);
  FW.NewLine;
  FW.Open('listofallmembers', []);
  for IM in C.AllMembers do
    if FProject.IsVisible(IM.Member) and (IM.Member.Kind <> memEnumValue) then
    begin
      FW.NewLine;
      FW.Open('member', ['refid', FLinks.RefIdOf(IM.Member), 'prot', ProtText(IM.Member.Protection), 'virt',
        VirtText(IM.Member)]);
      FW.Leaf('scope', IM.From.QualifiedName, []);
      FW.Leaf('name', IM.Member.Name, []);
      FW.Close('member');
    end;
  FW.NewLine;
  FW.Close('listofallmembers');
  FW.NewLine;
  FW.Close('compounddef');
  Finish(C.DiskName);
end;

procedure TXmlGenerator.WriteUnit(U: TUnitDef);
var
  C: TClassDef;
  T: TUnitDef;
  S: string;
  Vis: TList<TMemberDef>;
begin
  Begin_('compound.xsd');
  FW.NewLine;
  FW.Open('compounddef', ['id', U.DiskName, 'kind', 'namespace', 'language', 'Pascal', 'prot', 'public']);
  FW.NewLine;
  FW.Leaf('compoundname', U.Name, []);
  // the uses clause plays the role of the include list
  for S in U.UsesInterfaceNames do
  begin
    FW.NewLine;
    T := FProject.FindUnit(S);
    if (T <> nil) and FLinks.IsLinkable(T) then
      FW.Leaf('includes', S, ['refid', T.DiskName, 'local', 'no'])
    else
      FW.Leaf('includes', S, ['local', 'no']);
  end;
  for T in U.UsedBy do
    if FLinks.IsLinkable(T) then
    begin
      FW.NewLine;
      FW.Leaf('includedby', T.Name, ['refid', T.DiskName, 'local', 'no']);
    end;
  for C in U.Classes do
    if FProject.IsVisible(C) then
    begin
      FW.NewLine;
      FW.Leaf('innerclass', C.QualifiedName, ['refid', C.DiskName, 'prot', 'public']);
    end;
  Vis := VisibleMembers(U.Members);
  try
    WriteSections(Vis, True);
  finally
    Vis.Free;
  end;
  FW.NewLine;
  FDoc.Description('briefdescription', U.Brief, U);
  FW.NewLine;
  FDoc.Description('detaileddescription', U.Detailed, U);
  WriteLocation(U.Entry, nil);
  FW.NewLine;
  FW.Close('compounddef');
  Finish(U.DiskName);
end;

procedure TXmlGenerator.WriteGroup(G: TGroupDef);
var
  D: TDefinition;
  S: TGroupDef;
  M: TMemberDef;
  Kinds: TList<string>;
  K: string;
  Any: Boolean;
begin
  Begin_('compound.xsd');
  FW.NewLine;
  FW.Open('compounddef', ['id', G.DiskName, 'kind', 'group']);
  FW.NewLine;
  FW.Leaf('compoundname', G.Name, []);
  FW.NewLine;
  FW.Leaf('title', G.Title, []);
  for D in G.Members do
    if (D is TClassDef) and FProject.IsVisible(D) then
    begin
      FW.NewLine;
      FW.Leaf('innerclass', D.QualifiedName, ['refid', D.DiskName, 'prot', 'public']);
    end;
  for D in G.Members do
    if (D is TUnitDef) and FProject.IsVisible(D) then
    begin
      FW.NewLine;
      FW.Leaf('innernamespace', D.Name, ['refid', D.DiskName]);
    end;
  for S in G.Subgroups do
  begin
    FW.NewLine;
    FW.Leaf('innergroup', S.Title, ['refid', S.DiskName]);
  end;
  Kinds := TList<string>.Create;
  try
    Kinds.AddRange(['typedef', 'enum', 'func', 'var', 'property']);
    for K in Kinds do
    begin
      Any := False;
      for D in G.Members do
        if (D is TMemberDef) and FProject.IsVisible(D) and (SectionKind(TMemberDef(D), True) = K) then
          Any := True;
      if not Any then
        Continue;
      FW.NewLine;
      FW.Open('sectiondef', ['kind', K]);
      for D in G.Members do
        if (D is TMemberDef) and FProject.IsVisible(D) and (SectionKind(TMemberDef(D), True) = K) then
        begin
          M := TMemberDef(D);
          FW.NewLine;
          FW.Open('member', ['refid', FLinks.RefIdOf(M), 'kind', MemberKindText(M)]);
          FW.Leaf('name', M.Name, []);
          FW.Close('member');
        end;
      FW.NewLine;
      FW.Close('sectiondef');
    end;
  finally
    Kinds.Free;
  end;
  FW.NewLine;
  FDoc.Description('briefdescription', G.Brief, G);
  FW.NewLine;
  FDoc.Description('detaileddescription', G.Detailed, G);
  WriteLocation(G.Entry, nil);
  FW.NewLine;
  FW.Close('compounddef');
  Finish(G.DiskName);
end;

procedure TXmlGenerator.WritePage(P: TPageDef);
var
  Id, Name: string;
begin
  Id := FLinks.RefIdOf(P);
  if P.IsMainPage then Name := 'index' else Name := P.Name;
  Begin_('compound.xsd');
  FW.NewLine;
  FW.Open('compounddef', ['id', Id, 'kind', 'page']);
  FW.NewLine;
  FW.Leaf('compoundname', Name, []);
  FW.NewLine;
  FW.Leaf('title', P.Title, []);
  FW.NewLine;
  FDoc.Description('briefdescription', P.Brief, P);
  FW.NewLine;
  FDoc.Description('detaileddescription', P.Detailed, P);
  WriteLocation(P.Entry, nil);
  FW.NewLine;
  FW.Close('compounddef');
  Finish(Id);
end;

procedure TXmlGenerator.WriteIndex;
var
  U: TUnitDef;
  C: TClassDef;
  G: TGroupDef;
  P: TPageDef;

  procedure Compound(const ARefId, AKind, AName: string; AMembers: TList<TMemberDef>);
  var
    Mem, Val: TMemberDef;
  begin
    FW.NewLine;
    FW.Open('compound', ['refid', ARefId, 'kind', AKind]);
    FW.NewLine;
    FW.Leaf('name', AName, []);
    if AMembers <> nil then
      for Mem in AMembers do
      begin
        FW.NewLine;
        FW.Open('member', ['refid', FLinks.RefIdOf(Mem), 'kind', MemberKindText(Mem)]);
        FW.Leaf('name', Mem.Name, []);
        FW.Close('member');
        for Val in Mem.EnumValues do
        begin
          FW.NewLine;
          FW.Open('member', ['refid', FLinks.RefIdOf(Val), 'kind', 'enumvalue']);
          FW.Leaf('name', Val.Name, []);
          FW.Close('member');
        end;
      end;
    FW.NewLine;
    FW.Close('compound');
  end;

var
  Vis: TList<TMemberDef>;
begin
  FW := TXmlWriter.Create;
  try
    FW.Declaration;
    FW.Open('doxygenindex', ['xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:noNamespaceSchemaLocation',
      'index.xsd', 'version', DoxyPasVersion, 'xml:lang', FLang]);
    for C in FProject.Classes do
      if FLinks.IsLinkable(C) then
      begin
        Vis := VisibleMembers(C.Members);
        try
          Compound(C.DiskName, CompoundKind(C), C.QualifiedName, Vis);
        finally
          Vis.Free;
        end;
      end;
    for U in FProject.Units do
      if FProject.IsVisible(U) then
      begin
        Vis := VisibleMembers(U.Members);
        try
          Compound(U.DiskName, 'namespace', U.Name, Vis);
        finally
          Vis.Free;
        end;
      end;
    for G in FProject.Groups do
      Compound(G.DiskName, 'group', G.Name, nil);
    for P in FProject.Pages do
      if P.IsMainPage then
        Compound(FLinks.RefIdOf(P), 'page', 'index', nil)
      else
        Compound(FLinks.RefIdOf(P), 'page', P.Name, nil);
    FW.NewLine;
    FW.Close('doxygenindex');
    FW.NewLine;
    SaveFile('index.xml');
  finally
    FreeAndNil(FW);
  end;
end;

procedure TXmlGenerator.WriteSchemas;
var
  Name: string;
begin
  for Name in ['compound.xsd', 'index.xsd', 'xml.xsd'] do
  begin
    TFile.WriteAllText(TPath.Combine(FDir, Name), XmlResource(Name), TUTF8Encoding.Create(False));
    Inc(FFiles);
  end;
end;

function TXmlGenerator.Run: Integer;
var
  U: TUnitDef;
  C: TClassDef;
  G: TGroupDef;
  P: TPageDef;
begin
  TDirectory.CreateDirectory(FDir);
  for C in FProject.Classes do
    if FLinks.IsLinkable(C) then
      WriteClass(C);
  for U in FProject.Units do
    if FProject.IsVisible(U) then
      WriteUnit(U);
  for G in FProject.Groups do
    WriteGroup(G);
  for P in FProject.Pages do
    WritePage(P);
  WriteIndex;
  WriteSchemas;
  Result := FFiles;
end;

function GenerateXml(AProject: TProject; AConfig: TConfig; const AOutDir: string): Integer;
var
  G: TXmlGenerator;
begin
  G := TXmlGenerator.Create(AProject, AConfig, AOutDir);
  try
    Result := G.Run;
  finally
    G.Free;
  end;
end;

end.
