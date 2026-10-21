unit DoxyPas.Model.Project;

{ The documentation project: every definition found in the input, symbol lookup (Pascal scoping rules) and the
  extraction rules of the configuration (EXTRACT_ALL, EXTRACT_PRIVATE, HIDE_UNDOC_*, ...). }

interface

uses
  System.Classes,
  System.Generics.Collections,
  DoxyPas.Config,
  DoxyPas.Model.Entry,
  DoxyPas.Model.Defs;

type
  TProjectOptions = record
    ExtractAll: Boolean;
    ExtractPrivate: Boolean;
    ExtractStatic: Boolean;          // routines/variables that exist only in the implementation section
    ExtractLocalClasses: Boolean;    // classes declared in the implementation section
    HideUndocMembers: Boolean;
    HideUndocClasses: Boolean;
    InternalDocs: Boolean;
    InheritDocs: Boolean;
    WarnIfUndocumented: Boolean;
    WarnIfDocError: Boolean;
    WarnNoParamDoc: Boolean;
    CaseSenseNames: Boolean;         // file names: keep case (Linux) or escape upper case (Windows)
    UnitScopes: TArray<string>;      // prefixes tried for unit names ("Classes" -> "System.Classes")
    StripFromPath: TArray<string>;   // prefixes removed from file names in the output
    AutolinkSupport: Boolean;        // link words that match a class or unit name
    class function Default: TProjectOptions; static;
    class function FromConfig(AConfig: TConfig): TProjectOptions; static;
  end;

  /// <summary>A compound or member of another project, read from a tag file (TAGFILES).</summary>
  TExternalRef = record
    Name: string;        // qualified name as in the tag file
    Kind: string;        // class, struct, interface, namespace, group, page, function, variable, ...
    Url: string;         // base location of the other documentation ("../other/html"), may be empty
    FileName: string;    // e.g. "classTFoo.html"
    Anchor: string;
    TagName: string;
  end;

  TProject = class
  strict private
    FOwned: TObjectList<TDefinition>;
    FExternals: TDictionary<string, TExternalRef>;
    FUnitByName: TDictionary<string, TUnitDef>;
    FGlobal: TDictionary<string, TDefinition>;   // GlobalSymbol: the first symbol of every name in any unit
    FGlobalVersion: Integer;
    FGroupByName: TDictionary<string, TGroupDef>;
    function GlobalSymbol(const AName: string): TDefinition;
    function LookupSimple(const AName: string; AScope: TDefinition): TDefinition;
    function LookupMember(AScope: TDefinition; const AName: string; AVisited: TList<TDefinition>): TDefinition;
  public
    Options: TProjectOptions;
    Roots: TObjectList<TEntry>;       // parser output (owned)
    Units: TList<TUnitDef>;
    Classes: TList<TClassDef>;        // all classes, nested ones included
    Members: TList<TMemberDef>;       // all members of units and classes
    Groups: TList<TGroupDef>;
    Pages: TList<TPageDef>;
    Warnings: TStringList;
    constructor Create(const AOptions: TProjectOptions);
    destructor Destroy; override;
    /// <summary>Takes ownership of ADef (freed with the project).</summary>
    function Own(ADef: TDefinition): TDefinition;
    function AddUnit(AUnit: TUnitDef): TUnitDef;
    function AddClass(AClass: TClassDef): TClassDef;
    function AddMember(AMember: TMemberDef): TMemberDef;
    function AddGroup(AGroup: TGroupDef): TGroupDef;
    function AddPage(APage: TPageDef): TPageDef;
    function FindUnit(const AName: string): TUnitDef;
    function FindGroup(const AName: string): TGroupDef;
    /// <summary>Resolves a (possibly qualified) name as seen from AScope; nil if it is not part of the project.</summary>
    function Lookup(const AName: string; AScope: TDefinition): TDefinition;
    function IsVisible(ADef: TDefinition): Boolean;
    procedure Warn(const AFile: string; ALine: Integer; const AMsg: string);
    /// <summary>Registers a symbol of another project; it is found by its full name and by its last name part.</summary>
    procedure AddExternal(const ARef: TExternalRef);
    function FindExternal(const AName: string; out ARef: TExternalRef): Boolean;
    /// <summary>File name as written in the output: relative to STRIP_FROM_PATH, '/' separators.</summary>
    function OutputPath(const AFileName: string): string;
  end;

/// <summary>"TList&lt;T&gt;.Add(X)" -> "TList.Add": generic arguments and call arguments removed.</summary>
function PlainName(const AName: string): string;

implementation

uses
  System.SysUtils;

function PlainName(const AName: string): string;
var
  I, Depth: Integer;
  C: Char;
begin
  Result := '';
  Depth := 0;
  for I := 1 to Length(AName) do
  begin
    C := AName[I];
    if (C = '<') or (C = '(') then
      Inc(Depth)
    else if (C = '>') or (C = ')') then
    begin
      if Depth > 0 then
        Dec(Depth);
    end
    else if Depth = 0 then
      Result := Result + C;
  end;
  Result := Trim(Result);
end;

{ TProjectOptions }

class function TProjectOptions.Default: TProjectOptions;
begin
  Result.ExtractAll := False;
  Result.ExtractPrivate := False;
  Result.ExtractStatic := False;
  Result.ExtractLocalClasses := True;
  Result.HideUndocMembers := False;
  Result.HideUndocClasses := False;
  Result.InternalDocs := False;
  Result.InheritDocs := True;
  Result.WarnIfUndocumented := True;
  Result.WarnIfDocError := True;
  Result.WarnNoParamDoc := False;
{$IFDEF MSWINDOWS}
  Result.CaseSenseNames := False;
{$ELSE}
  Result.CaseSenseNames := True;
{$ENDIF}
  Result.UnitScopes := ['System', 'System.Win', 'Winapi', 'Vcl', 'FMX', 'Data', 'Xml', 'Soap', 'Web', 'Posix'];
  Result.StripFromPath := nil;
  Result.AutolinkSupport := True;
end;

class function TProjectOptions.FromConfig(AConfig: TConfig): TProjectOptions;
var
  Cs: string;
begin
  Result.ExtractAll := AConfig.GetBool('EXTRACT_ALL');
  Result.ExtractPrivate := AConfig.GetBool('EXTRACT_PRIVATE');
  Result.ExtractStatic := AConfig.GetBool('EXTRACT_STATIC');
  Result.ExtractLocalClasses := AConfig.GetBool('EXTRACT_LOCAL_CLASSES');
  Result.HideUndocMembers := AConfig.GetBool('HIDE_UNDOC_MEMBERS');
  Result.HideUndocClasses := AConfig.GetBool('HIDE_UNDOC_CLASSES');
  Result.InternalDocs := AConfig.GetBool('INTERNAL_DOCS');
  Result.InheritDocs := AConfig.GetBool('INHERIT_DOCS');
  Result.WarnIfUndocumented := AConfig.GetBool('WARN_IF_UNDOCUMENTED');
  Result.WarnIfDocError := AConfig.GetBool('WARN_IF_DOC_ERROR');
  Result.WarnNoParamDoc := AConfig.GetBool('WARN_NO_PARAMDOC');
  Cs := AConfig.GetString('CASE_SENSE_NAMES');
  if SameText(Cs, 'SYSTEM') then
    Result.CaseSenseNames := Default.CaseSenseNames
  else
    Result.CaseSenseNames := SameText(Cs, 'YES');
  Result.UnitScopes := AConfig.GetList('PASCAL_UNIT_SCOPES');
  Result.StripFromPath := AConfig.GetList('STRIP_FROM_PATH');
  Result.AutolinkSupport := AConfig.GetBool('AUTOLINK_SUPPORT');
end;

{ TProject }

constructor TProject.Create(const AOptions: TProjectOptions);
begin
  inherited Create;
  Options := AOptions;
  FOwned := TObjectList<TDefinition>.Create(True);
  FUnitByName := TDictionary<string, TUnitDef>.Create;
  FGroupByName := TDictionary<string, TGroupDef>.Create;
  FExternals := TDictionary<string, TExternalRef>.Create;
  Roots := TObjectList<TEntry>.Create(True);
  Units := TList<TUnitDef>.Create;
  Classes := TList<TClassDef>.Create;
  Members := TList<TMemberDef>.Create;
  Groups := TList<TGroupDef>.Create;
  Pages := TList<TPageDef>.Create;
  Warnings := TStringList.Create;
end;

destructor TProject.Destroy;
begin
  FGlobal.Free;
  Warnings.Free;
  Pages.Free;
  Groups.Free;
  Members.Free;
  Classes.Free;
  Units.Free;
  FExternals.Free;
  FGroupByName.Free;
  FUnitByName.Free;
  FOwned.Free;   // definitions refer to entries: free them first
  Roots.Free;
  inherited;
end;

function TProject.Own(ADef: TDefinition): TDefinition;
begin
  FOwned.Add(ADef);
  Result := ADef;
end;

function TProject.AddUnit(AUnit: TUnitDef): TUnitDef;
begin
  Own(AUnit);
  Units.Add(AUnit);
  FUnitByName.AddOrSetValue(LowerCase(AUnit.Name), AUnit);
  Result := AUnit;
end;

function TProject.AddClass(AClass: TClassDef): TClassDef;
begin
  Own(AClass);
  Classes.Add(AClass);
  Result := AClass;
end;

function TProject.AddMember(AMember: TMemberDef): TMemberDef;
begin
  Own(AMember);
  Members.Add(AMember);
  Result := AMember;
end;

function TProject.AddGroup(AGroup: TGroupDef): TGroupDef;
begin
  Own(AGroup);
  Groups.Add(AGroup);
  FGroupByName.AddOrSetValue(LowerCase(AGroup.Name), AGroup);
  Result := AGroup;
end;

function TProject.AddPage(APage: TPageDef): TPageDef;
begin
  Own(APage);
  Pages.Add(APage);
  Result := APage;
end;

// The first definition called AName among the symbols of all units, in the order of the units. The index is made when
// it is first needed and again when a symbol has been added since: looking at every unit for every word of a text that
// is not a name (most of them) took more time than anything else when the project has thousands of units.
function TProject.GlobalSymbol(const AName: string): TDefinition;
var
  U: TUnitDef;
begin
  if (FGlobal = nil) or (FGlobalVersion <> TScopeDef.SymbolVersion) then
  begin
    if FGlobal = nil then
      FGlobal := TDictionary<string, TDefinition>.Create
    else
      FGlobal.Clear;
    for U in Units do
      U.FirstSymbolsInto(FGlobal);
    FGlobalVersion := TScopeDef.SymbolVersion;
  end;
  if not FGlobal.TryGetValue(LowerCase(AName), Result) then
    Result := nil;
end;

function TProject.FindUnit(const AName: string): TUnitDef;
var
  Prefix: string;
begin
  if FUnitByName.TryGetValue(LowerCase(AName), Result) then
    Exit;
  for Prefix in Options.UnitScopes do
    if FUnitByName.TryGetValue(LowerCase(Prefix + '.' + AName), Result) then
      Exit;
  Result := nil;
end;

function TProject.FindGroup(const AName: string): TGroupDef;
begin
  if not FGroupByName.TryGetValue(LowerCase(AName), Result) then
    Result := nil;
end;

procedure TProject.Warn(const AFile: string; ALine: Integer; const AMsg: string);
begin
  if AFile = '' then
    Warnings.Add('warning: ' + AMsg)
  else
    Warnings.Add(Format('%s:%d: warning: %s', [AFile, ALine, AMsg]));
end;

procedure TProject.AddExternal(const ARef: TExternalRef);
var
  Plain: string;
  P: Integer;
begin
  Plain := LowerCase(PlainName(ARef.Name)).Replace('::', '.');
  FExternals.AddOrSetValue(Plain, ARef);
  // every trailing part of the qualified name finds it too: "ns.foo.bar", "foo.bar", "bar"
  P := Pos('.', Plain);
  while P > 0 do
  begin
    Plain := Copy(Plain, P + 1, MaxInt);
    if (Plain <> '') and not FExternals.ContainsKey(Plain) then
      FExternals.Add(Plain, ARef);
    P := Pos('.', Plain);
  end;
end;

function TProject.FindExternal(const AName: string; out ARef: TExternalRef): Boolean;
begin
  Result := FExternals.TryGetValue(LowerCase(PlainName(AName)).Replace('::', '.'), ARef);
end;

function TProject.OutputPath(const AFileName: string): string;
var
  Prefix, Full, Norm: string;
  Best: Integer;
begin
  Full := AFileName.Replace('\', '/');
  Best := 0;
  Result := Full;
  for Prefix in Options.StripFromPath do
  begin
    Norm := Prefix.Replace('\', '/').TrimRight(['/']) + '/';
    if (Length(Norm) > Best) and Full.StartsWith(Norm, True) then
    begin
      Best := Length(Norm);
      Result := Copy(Full, Length(Norm) + 1, MaxInt);
    end;
  end;
end;

{ A member of a class or of one of its ancestors. }
function TProject.LookupMember(AScope: TDefinition; const AName: string; AVisited: TList<TDefinition>): TDefinition;
var
  L: TArray<TDefinition>;
  B: TBaseRef;
  E: TDefinition;
begin
  Result := nil;
  if (AScope = nil) or (AVisited.IndexOf(AScope) >= 0) then
    Exit;
  AVisited.Add(AScope);
  if AScope is TScopeDef then
  begin
    L := TScopeDef(AScope).Find(AName);
    if Length(L) > 0 then
      Exit(L[0]);
  end;
  if AScope is TMemberDef then
  begin
    for E in TMemberDef(AScope).EnumValues do
      if SameText(E.Name, AName) then
        Exit(E);
  end
  else if AScope is TClassDef then
    for B in TClassDef(AScope).Bases do
      if B.ClassDef <> nil then
      begin
        Result := LookupMember(B.ClassDef, AName, AVisited);
        if Result <> nil then
          Exit;
      end;
end;

{ First identifier of a name: enclosing scopes (class members, ancestors), the unit, its used units, unit names. }
function TProject.LookupSimple(const AName: string; AScope: TDefinition): TDefinition;
var
  Cur: TDefinition;
  Visited: TList<TDefinition>;
  U: TUnitDef;
  I: Integer;
  L: TArray<TDefinition>;
begin
  Result := nil;
  Visited := TList<TDefinition>.Create;
  try
    Cur := AScope;
    while Cur <> nil do
    begin
      Visited.Clear;
      Result := LookupMember(Cur, AName, Visited);
      if Result <> nil then
        Exit;
      if SameText(Cur.Name, AName) then
        Exit(Cur);
      Cur := Cur.Scope;
    end;
    if AScope <> nil then
    begin
      U := AScope.OwnerUnit;
      if U <> nil then
      begin
        for I := U.UsesImplementation.Count - 1 downto 0 do
        begin
          L := U.UsesImplementation[I].Find(AName);
          if Length(L) > 0 then
            Exit(L[0]);
        end;
        for I := U.UsesInterface.Count - 1 downto 0 do
        begin
          L := U.UsesInterface[I].Find(AName);
          if Length(L) > 0 then
            Exit(L[0]);
        end;
      end;
    end;
    Result := FindUnit(AName);
    if Result = nil then
      // search everywhere as a last resort (documentation often refers to types of units that are not "used")
      Result := GlobalSymbol(AName);
  finally
    Visited.Free;
  end;
end;

function TProject.Lookup(const AName: string; AScope: TDefinition): TDefinition;
var
  Parts: TArray<string>;
  I, N: Integer;
  Name: string;
  U: TUnitDef;
  Visited: TList<TDefinition>;
begin
  Result := nil;
  Name := PlainName(AName);
  if Name = '' then
    Exit;
  Name := Name.Replace('::', '.').Replace('#', '.');
  Parts := Name.Split(['.'], TStringSplitOptions.ExcludeEmpty);
  if Length(Parts) = 0 then
    Exit;
  // the longest prefix that names a unit ("System.Classes.TList")
  for N := Length(Parts) downto 1 do
  begin
    U := FindUnit(string.Join('.', Copy(Parts, 0, N)));
    if U <> nil then
    begin
      Result := U;
      I := N;
      Break;
    end;
  end;
  if Result = nil then
  begin
    Result := LookupSimple(Parts[0], AScope);
    I := 1;
  end;
  if Result = nil then
    Exit;
  Visited := TList<TDefinition>.Create;
  try
    while I < Length(Parts) do
    begin
      Visited.Clear;
      Result := LookupMember(Result, Parts[I], Visited);
      if Result = nil then
        Exit;
      Inc(I);
    end;
  finally
    Visited.Free;
  end;
end;

function TProject.IsVisible(ADef: TDefinition): Boolean;
var
  E: TDefinition;
  M: TMemberDef;
  C: TClassDef;
begin
  Result := False;
  if ADef = nil then
    Exit;
  if (ADef.Entry <> nil) and (efInternal in ADef.Entry.Flags) and not Options.InternalDocs then
    Exit;
  if ADef is TUnitDef then
  begin
    if Options.ExtractAll or ADef.IsDocumented then
      Exit(True);
    for M in TUnitDef(ADef).Members do
      if IsVisible(M) then
        Exit(True);
    for C in TUnitDef(ADef).Classes do
      if IsVisible(C) then
        Exit(True);
    Exit(False);
  end;
  if ADef is TGroupDef then
    Exit(True);
  if ADef is TPageDef then
    Exit(True);
  // private members need EXTRACT_PRIVATE; implementation-only items need EXTRACT_STATIC / EXTRACT_LOCAL_CLASSES
  if (ADef.Protection in [prPrivate, prStrictPrivate]) and not Options.ExtractPrivate then
    Exit;
  if ADef.ImplementationOnly then
    if ADef is TClassDef then
    begin
      if not Options.ExtractLocalClasses then
        Exit;
    end
    else if not Options.ExtractStatic then
      Exit;
  if ADef.Scope <> nil then
    if not (ADef.Scope is TUnitDef) and not IsVisible(ADef.Scope) then
      Exit;
  if Options.ExtractAll or ADef.IsDocumented then
    Exit(True);
  // undocumented: listed (without a documentation section) inside a documented compound unless hidden
  E := ADef.Scope;
  if ADef is TClassDef then
    Result := (not Options.HideUndocClasses) and (E <> nil) and E.IsDocumented
  else
    Result := (not Options.HideUndocMembers) and (E <> nil) and E.IsDocumented;
end;

end.
