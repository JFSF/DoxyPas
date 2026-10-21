unit DoxyPas.Output.SqliteGen;

{ SQLite output (Doxygen's sqlite3gen): a SQL script with Doxygen's schema (meta, path, refid, compounddef,
  memberdef, member, compoundref, contains, reimplements, param, memberdef_param and the views def, local_file,
  external_file, inner_outer) and the data of the project. Load it with
      sqlite3 doxygen_sqlite3.db < doxygen_sqlite3.sql
  The descriptions are stored as plain text, not as XML. No SQLite library is needed to produce it, so it works on
  every platform. }

interface

uses
  DoxyPas.Config,
  DoxyPas.Model.Project;

/// <summary>Writes doxygen_sqlite3.sql into AOutDir. Returns the number of files written (1).</summary>
function GenerateSqlite(AProject: TProject; AConfig: TConfig; const AOutDir: string): Integer;

/// <summary>SQL literal: 'text' with quotes doubled, NULL for an empty string.</summary>
function SqlText(const S: string): string;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  DoxyPas.Core.Version,
  DoxyPas.Doc.Nodes,
  DoxyPas.Doc.Parser,
  DoxyPas.Model.Entry,
  DoxyPas.Model.Defs,
  DoxyPas.Model.Calls,
  DoxyPas.Model.Links;

const
  Schema =
    'CREATE TABLE IF NOT EXISTS meta (doxygen_version TEXT PRIMARY KEY NOT NULL, schema_version TEXT NOT NULL, ' +
    'generated_at TEXT NOT NULL, generated_on TEXT NOT NULL, project_name TEXT NOT NULL, project_number TEXT, ' +
    'project_brief TEXT);'#10 +
    'CREATE TABLE IF NOT EXISTS includes (rowid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, local INTEGER NOT NULL, ' +
    'src_id INTEGER NOT NULL REFERENCES path, dst_id INTEGER NOT NULL REFERENCES path, ' +
    'UNIQUE(local, src_id, dst_id) ON CONFLICT IGNORE);'#10 +
    'CREATE TABLE IF NOT EXISTS contains (rowid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, ' +
    'inner_rowid INTEGER NOT NULL REFERENCES compounddef, outer_rowid INTEGER NOT NULL REFERENCES compounddef);'#10 +
    'CREATE TABLE IF NOT EXISTS path (rowid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, type INTEGER NOT NULL, ' +
    'local INTEGER NOT NULL, found INTEGER NOT NULL, name TEXT NOT NULL);'#10 +
    'CREATE TABLE IF NOT EXISTS refid (rowid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, refid TEXT NOT NULL UNIQUE);'#10 +
    'CREATE TABLE IF NOT EXISTS xrefs (rowid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, ' +
    'src_rowid INTEGER NOT NULL REFERENCES refid, dst_rowid INTEGER NOT NULL REFERENCES refid, ' +
    'context TEXT NOT NULL, UNIQUE(src_rowid, dst_rowid, context) ON CONFLICT IGNORE);'#10 +
    'CREATE TABLE IF NOT EXISTS memberdef (rowid INTEGER PRIMARY KEY NOT NULL, name TEXT NOT NULL, definition TEXT, ' +
    'type TEXT, argsstring TEXT, scope TEXT, initializer TEXT, bitfield TEXT, read TEXT, write TEXT, ' +
    'prot INTEGER DEFAULT 0, static INTEGER DEFAULT 0, extern INTEGER DEFAULT 0, const INTEGER DEFAULT 0, ' +
    'explicit INTEGER DEFAULT 0, inline INTEGER DEFAULT 0, final INTEGER DEFAULT 0, sealed INTEGER DEFAULT 0, ' +
    'new INTEGER DEFAULT 0, optional INTEGER DEFAULT 0, required INTEGER DEFAULT 0, volatile INTEGER DEFAULT 0, ' +
    'virt INTEGER DEFAULT 0, mutable INTEGER DEFAULT 0, thread_local INTEGER DEFAULT 0, initonly INTEGER DEFAULT 0, ' +
    'attribute INTEGER DEFAULT 0, property INTEGER DEFAULT 0, readonly INTEGER DEFAULT 0, bound INTEGER DEFAULT 0, ' +
    'constrained INTEGER DEFAULT 0, transient INTEGER DEFAULT 0, maybevoid INTEGER DEFAULT 0, ' +
    'maybedefault INTEGER DEFAULT 0, maybeambiguous INTEGER DEFAULT 0, readable INTEGER DEFAULT 0, ' +
    'writable INTEGER DEFAULT 0, gettable INTEGER DEFAULT 0, privategettable INTEGER DEFAULT 0, ' +
    'protectedgettable INTEGER DEFAULT 0, settable INTEGER DEFAULT 0, privatesettable INTEGER DEFAULT 0, ' +
    'protectedsettable INTEGER DEFAULT 0, accessor INTEGER DEFAULT 0, addable INTEGER DEFAULT 0, ' +
    'removable INTEGER DEFAULT 0, raisable INTEGER DEFAULT 0, kind TEXT NOT NULL, bodystart INTEGER DEFAULT 0, ' +
    'bodyend INTEGER DEFAULT 0, bodyfile_id INTEGER REFERENCES path, file_id INTEGER NOT NULL REFERENCES path, ' +
    'line INTEGER NOT NULL, column INTEGER NOT NULL, detaileddescription TEXT, briefdescription TEXT, ' +
    'inbodydescription TEXT, FOREIGN KEY (rowid) REFERENCES refid (rowid));'#10 +
    'CREATE TABLE IF NOT EXISTS member (rowid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, ' +
    'scope_rowid INTEGER NOT NULL REFERENCES compounddef, memberdef_rowid INTEGER NOT NULL REFERENCES memberdef, ' +
    'prot INTEGER NOT NULL, virt INTEGER NOT NULL, UNIQUE(scope_rowid, memberdef_rowid));'#10 +
    'CREATE TABLE IF NOT EXISTS reimplements (rowid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, ' +
    'memberdef_rowid INTEGER NOT NULL REFERENCES memberdef, reimplemented_rowid INTEGER NOT NULL REFERENCES memberdef, ' +
    'UNIQUE(memberdef_rowid, reimplemented_rowid) ON CONFLICT IGNORE);'#10 +
    'CREATE TABLE IF NOT EXISTS compounddef (rowid INTEGER PRIMARY KEY NOT NULL, name TEXT NOT NULL, title TEXT, ' +
    'kind TEXT NOT NULL, prot INTEGER, file_id INTEGER NOT NULL REFERENCES path, line INTEGER NOT NULL, ' +
    'column INTEGER NOT NULL, header_id INTEGER REFERENCES path, detaileddescription TEXT, briefdescription TEXT, ' +
    'FOREIGN KEY (rowid) REFERENCES refid (rowid));'#10 +
    'CREATE TABLE IF NOT EXISTS compoundref (rowid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, ' +
    'base_rowid INTEGER NOT NULL REFERENCES compounddef, derived_rowid INTEGER NOT NULL REFERENCES compounddef, ' +
    'prot INTEGER NOT NULL, virt INTEGER NOT NULL, UNIQUE(base_rowid, derived_rowid));'#10 +
    'CREATE TABLE IF NOT EXISTS param (rowid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, attributes TEXT, type TEXT, ' +
    'declname TEXT, defname TEXT, array TEXT, defval TEXT, briefdescription TEXT);'#10 +
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_param ON param (type, defname);'#10 +
    'CREATE TABLE IF NOT EXISTS memberdef_param (rowid INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, ' +
    'memberdef_id INTEGER NOT NULL REFERENCES memberdef, param_id INTEGER NOT NULL REFERENCES param);'#10;

  Views =
    'CREATE VIEW IF NOT EXISTS def (rowid, refid, kind, name, summary) AS SELECT refid.rowid, refid.refid, ' +
    'memberdef.kind, memberdef.name, memberdef.briefdescription FROM refid JOIN memberdef ON ' +
    'refid.rowid=memberdef.rowid UNION ALL SELECT refid.rowid, refid.refid, compounddef.kind, compounddef.name, ' +
    'CASE WHEN briefdescription IS NOT NULL THEN briefdescription ELSE title END summary FROM refid JOIN ' +
    'compounddef ON refid.rowid=compounddef.rowid;'#10 +
    'CREATE VIEW IF NOT EXISTS local_file (rowid, found, name) AS SELECT path.rowid, path.found, path.name FROM path ' +
    'WHERE path.type=1 AND path.local=1 AND path.found=1;'#10 +
    'CREATE VIEW IF NOT EXISTS external_file (rowid, found, name) AS SELECT path.rowid, path.found, path.name FROM ' +
    'path WHERE path.type=1 AND path.local=0;'#10 +
    'CREATE VIEW IF NOT EXISTS inline_xrefs (rowid, src_rowid, dst_rowid) AS SELECT xrefs.rowid, xrefs.src_rowid, ' +
    'xrefs.dst_rowid FROM xrefs WHERE xrefs.context=''inline'';'#10 +
    'CREATE VIEW IF NOT EXISTS argument_xrefs (rowid, src_rowid, dst_rowid) AS SELECT xrefs.rowid, xrefs.src_rowid, ' +
    'xrefs.dst_rowid FROM xrefs WHERE xrefs.context=''argument'';'#10 +
    'CREATE VIEW IF NOT EXISTS initializer_xrefs (rowid, src_rowid, dst_rowid) AS SELECT xrefs.rowid, xrefs.src_rowid, ' +
    'xrefs.dst_rowid FROM xrefs WHERE xrefs.context=''initializer'';'#10 +
    'CREATE VIEW IF NOT EXISTS inner_outer AS SELECT inner.*, outer.* FROM def AS inner JOIN contains ON ' +
    'inner.rowid=contains.inner_rowid JOIN def AS outer ON outer.rowid=contains.outer_rowid;'#10;

function SqlText(const S: string): string;
begin
  if S = '' then
    Result := 'NULL'
  else
    Result := '''' + S.Replace('''', '''''') + '''';
end;

type
  TSqliteGenerator = class
  strict private
    FProject: TProject;
    FConfig: TConfig;
    FLinks: TLinkResolver;
    FSB: TStringBuilder;
    FIds: TDictionary<TDefinition, Integer>;
    FPaths: TDictionary<string, Integer>;
    FNext: Integer;
    function Plain(const AText: string): string;
    function PathId(const AFile: string): Integer;
    function ExternalPathId(const AName: string): Integer;
    procedure Includes;
    procedure Xrefs;
    function IdOf(ADef: TDefinition): Integer;
    function Prot(AProt: TProtection): Integer;
    function Virt(M: TMemberDef): Integer;
    function KindOf(M: TMemberDef): string;
    function Flag(AValue: Boolean): string;
    procedure Compound(ADef: TDefinition; const AKind, ATitle: string; AProt: Integer);
    procedure Member(M: TMemberDef);
    procedure Exec(const ASql: string);
  public
    constructor Create(AProject: TProject; AConfig: TConfig);
    destructor Destroy; override;
    function Script: string;
  end;

constructor TSqliteGenerator.Create(AProject: TProject; AConfig: TConfig);
begin
  inherited Create;
  FProject := AProject;
  FConfig := AConfig;
  FLinks := TLinkResolver.Create(AProject);
  FSB := TStringBuilder.Create;
  FIds := TDictionary<TDefinition, Integer>.Create;
  FPaths := TDictionary<string, Integer>.Create;
end;

destructor TSqliteGenerator.Destroy;
begin
  FPaths.Free;
  FIds.Free;
  FSB.Free;
  FLinks.Free;
  inherited;
end;

procedure TSqliteGenerator.Exec(const ASql: string);
begin
  FSB.Append(ASql).Append(#10);
end;

function TSqliteGenerator.Plain(const AText: string): string;
var
  Root: TDocNode;
begin
  Result := '';
  if Trim(AText) = '' then
    Exit;
  Root := ParseDoc(AText);
  try
    Result := Trim(Root.PlainText);
  finally
    Root.Free;
  end;
end;

function TSqliteGenerator.PathId(const AFile: string): Integer;
var
  Name: string;
begin
  Name := FProject.OutputPath(AFile);
  if not FPaths.TryGetValue(Name, Result) then
  begin
    Result := FPaths.Count + 1;
    FPaths.Add(Name, Result);
    Exec('INSERT INTO path (rowid, type, local, found, name) VALUES (' + Result.ToString + ',1,1,1,' + '''' + Name.Replace('''', '''''') + ''');');
  end;
end;

// A unit that is not part of the project (System.SysUtils...): a path that is not local and was not found.
function TSqliteGenerator.ExternalPathId(const AName: string): Integer;
begin
  if not FPaths.TryGetValue('?' + AName, Result) then
  begin
    Result := FPaths.Count + 1;
    FPaths.Add('?' + AName, Result);
    Exec('INSERT INTO path (rowid, type, local, found, name) VALUES (' + Result.ToString + ',1,0,0,' + SqlText(AName) + ');');
  end;
end;

// The uses clauses as Doxygen's #include relations: the file of a unit includes the files of the units it uses.
procedure TSqliteGenerator.Includes;
var
  U, T: TUnitDef;
  S: string;
  Names: TList<string>;
begin
  for U in FProject.Units do
    if FLinks.IsLinkable(U) and (U.FileName <> '') then
    begin
      Names := TList<string>.Create;
      try
        Names.AddRange(U.UsesInterfaceNames);
        for S in U.UsesImplementationNames do
          if not Names.Contains(S) then
            Names.Add(S);
        for S in Names do
        begin
          T := FProject.FindUnit(S);
          if (T <> nil) and (T.FileName <> '') then
            Exec('INSERT OR IGNORE INTO includes (local, src_id, dst_id) VALUES (1,' + PathId(U.FileName).ToString + ',' +
              PathId(T.FileName).ToString + ');')
          else
            Exec('INSERT OR IGNORE INTO includes (local, src_id, dst_id) VALUES (0,' + PathId(U.FileName).ToString + ',' +
              ExternalPathId(S).ToString + ');');
        end;
      finally
        Names.Free;
      end;
    end;
end;

// REFERENCES_RELATION / REFERENCED_BY_RELATION: what the body of a routine uses (the "inline" context of Doxygen).
procedure TSqliteGenerator.Xrefs;
var
  Bodies: TBodyLocator;
  Calls: TCallIndex;
  M, T: TMemberDef;
  L: TList<TMemberDef>;
begin
  if not (FConfig.GetBool('REFERENCES_RELATION') or FConfig.GetBool('REFERENCED_BY_RELATION')) then
    Exit;
  Bodies := TBodyLocator.Create(FProject, FLinks);
  try
    Calls := TCallIndex.Create(Bodies, FLinks);
    try
      for M in Bodies.Routines do
        if FIds.ContainsKey(M) then
        begin
          L := Calls.ReferencesOf(M);
          if L <> nil then
            for T in L do
              if FIds.ContainsKey(T) then
                Exec('INSERT OR IGNORE INTO xrefs (src_rowid, dst_rowid, context) VALUES (' + IdOf(M).ToString + ',' +
                  IdOf(T).ToString + ',''inline'');');
        end;
    finally
      Calls.Free;
    end;
  finally
    Bodies.Free;
  end;
end;

function TSqliteGenerator.IdOf(ADef: TDefinition): Integer;
begin
  if not FIds.TryGetValue(ADef, Result) then
  begin
    Inc(FNext);
    Result := FNext;
    FIds.Add(ADef, Result);
    Exec('INSERT INTO refid (rowid, refid) VALUES (' + Result.ToString + ',' + SqlText(FLinks.RefIdOf(ADef)) + ');');
  end;
end;

function TSqliteGenerator.Prot(AProt: TProtection): Integer;
begin
  case AProt of
    prProtected, prStrictProtected: Result := 1;
    prPrivate, prStrictPrivate: Result := 2;
  else
    Result := 0;
  end;
end;

function TSqliteGenerator.Virt(M: TMemberDef): Integer;
begin
  Result := 0;
  if M.Entry = nil then
    Exit;
  if M.Entry.Virtualness <> vtNormal then
  begin
    Result := 1;
    if efAbstract in M.Entry.Flags then
      Result := 2;
  end;
end;

function TSqliteGenerator.KindOf(M: TMemberDef): string;
begin
  case M.Kind of
    memFunction: Result := 'function';
    memProperty: Result := 'property';
    memTypedef: Result := 'typedef';
    memEnumeration: Result := 'enumeration';
    memEnumValue: Result := 'enumvalue';
  else
    Result := 'variable';
  end;
end;

function TSqliteGenerator.Flag(AValue: Boolean): string;
begin
  if AValue then Result := '1' else Result := '0';
end;

procedure TSqliteGenerator.Compound(ADef: TDefinition; const AKind, ATitle: string; AProt: Integer);
var
  E: TEntry;
  File_, Line, Col: string;
begin
  E := ADef.Entry;
  if (E <> nil) and (E.FileName <> '') then
  begin
    File_ := PathId(E.FileName).ToString;
    Line := E.Line.ToString;
    Col := E.Col.ToString;
  end
  else
  begin
    File_ := PathId('').ToString;
    Line := '0';
    Col := '0';
  end;
  Exec('INSERT INTO compounddef (rowid, name, title, kind, prot, file_id, line, column, detaileddescription, ' +
    'briefdescription) VALUES (' + IdOf(ADef).ToString + ',' + SqlText(ADef.QualifiedName) + ',' + SqlText(ATitle) + ',' +
    SqlText(AKind) + ',' + AProt.ToString + ',' + File_ + ',' + Line + ',' + Col + ',' +
    SqlText(Plain(ADef.Detailed)) + ',' + SqlText(Plain(ADef.Brief)) + ');');
end;

procedure TSqliteGenerator.Member(M: TMemberDef);
var
  E: TEntry;
  Id, Mp: Integer;
  Impl: TEntry;
  A: TArgument;
  Def, Args, BodyFile, BodyStart, BodyEnd: string;
  Static: Boolean;
begin
  E := M.Entry;
  if E = nil then
    Exit;
  Id := IdOf(M);
  Static := [efClassMember, efStatic] * E.Flags <> [];
  Args := '';
  for A in E.Args do
  begin
    if Args <> '' then
      Args := Args + '; ';
    Args := Args + Trim(A.Modifier + ' ' + A.Name + ': ' + A.TypeText);
  end;
  if Args <> '' then
    Args := '(' + Args + ')';
  Def := M.Name;
  if (M.Kind in [memVariable, memConstant, memProperty]) and (E.TypeText <> '') then
    Def := M.Name + ': ' + E.TypeText;
  BodyFile := 'NULL';
  BodyStart := '0';
  BodyEnd := '0';
  Impl := M.Impl;
  if (Impl <> nil) and (Impl.FileName <> '') then
  begin
    BodyFile := PathId(Impl.FileName).ToString;
    BodyStart := Impl.Line.ToString;
    BodyEnd := Impl.EndLine.ToString;
  end;
  Exec('INSERT INTO memberdef (rowid, name, definition, type, argsstring, scope, initializer, read, write, prot, ' +
    'static, inline, final, sealed, virt, property, readable, writable, kind, bodystart, bodyend, bodyfile_id, ' +
    'file_id, line, column, detaileddescription, briefdescription) VALUES (' + Id.ToString + ',' + SqlText(M.Name) +
    ',' + SqlText(Def) + ',' + SqlText(E.TypeText) + ',' + SqlText(Args) + ',' +
    SqlText(M.Scope.QualifiedName) + ',' + SqlText(E.InitText) + ',' + SqlText(E.ReadAccessor) + ',' +
    SqlText(E.WriteAccessor) + ',' + Prot(M.Protection).ToString + ',' + Flag(Static) + ',' +
    Flag(efInline in E.Flags) + ',' + Flag(efFinal in E.Flags) + ',' + Flag(efSealed in E.Flags) + ',' +
    Virt(M).ToString + ',' + Flag(M.Kind = memProperty) + ',' + Flag(E.ReadAccessor <> '') + ',' +
    Flag(E.WriteAccessor <> '') + ',' + SqlText(KindOf(M)) + ',' + BodyStart + ',' + BodyEnd + ',' + BodyFile + ',' +
    PathId(E.FileName).ToString + ',' + E.Line.ToString + ',' + E.Col.ToString + ',' +
    SqlText(Plain(M.Detailed)) + ',' + SqlText(Plain(M.Brief)) + ');');
  if (M.Scope <> nil) and FIds.TryGetValue(M.Scope, Mp) then
    Exec('INSERT OR IGNORE INTO member (scope_rowid, memberdef_rowid, prot, virt) VALUES (' + Mp.ToString + ',' +
      Id.ToString + ',' + Prot(M.Protection).ToString + ',' + Virt(M).ToString + ');');
  for A in E.Args do
  begin
    Exec('INSERT OR IGNORE INTO param (attributes, type, declname, defname, defval) VALUES (' + SqlText(A.Modifier) +
      ',' + SqlText(A.TypeText) + ',' + SqlText(A.Name) + ',' + SqlText(A.Name) + ',' + SqlText(A.DefaultText) + ');');
    Exec('INSERT INTO memberdef_param (memberdef_id, param_id) SELECT ' + Id.ToString +
      ', rowid FROM param WHERE type IS ' + SqlText(A.TypeText) + ' AND defname IS ' + SqlText(A.Name) + ';');
  end;
end;

function TSqliteGenerator.Script: string;
var
  U: TUnitDef;
  C, N: TClassDef;
  G: TGroupDef;
  P: TPageDef;
  M, V: TMemberDef;
  B: TBaseRef;
  Kind, Title: string;
begin
  Exec('PRAGMA foreign_keys=OFF;');
  FSB.Append(Schema);
  Exec('BEGIN TRANSACTION;');
  Exec('INSERT INTO meta (doxygen_version, schema_version, generated_at, generated_on, project_name, ' +
    'project_number, project_brief) VALUES (' + SqlText(DoxyPasVersion) + ',''0.2.1'',' +
    SqlText(FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now)) + ',' + SqlText('DoxyPas') + ',' +
    SqlText(FConfig.GetString('PROJECT_NAME')) + ',' + SqlText(FConfig.GetString('PROJECT_NUMBER')) + ',' +
    SqlText(FConfig.GetString('PROJECT_BRIEF')) + ');');
  // compounds first so that members can refer to their scope
  for U in FProject.Units do
    if FLinks.IsLinkable(U) then
      Compound(U, 'namespace', '', 0);
  for C in FProject.Classes do
    if FLinks.IsLinkable(C) then
    begin
      case C.ClassKind of
        ckRecord, ckRecordHelper: Kind := 'struct';
        ckInterface, ckDispInterface: Kind := 'interface';
      else
        Kind := 'class';
      end;
      Compound(C, Kind, '', Prot(C.Protection));
    end;
  for G in FProject.Groups do
    Compound(G, 'group', G.Title, 0);
  for P in FProject.Pages do
  begin
    Title := P.Title;
    Compound(P, 'page', Title, 0);
  end;
  for U in FProject.Units do
    if FLinks.IsLinkable(U) then
    begin
      for C in U.Classes do
        if FLinks.IsLinkable(C) and (C.Scope = U) then
          Exec('INSERT INTO contains (inner_rowid, outer_rowid) VALUES (' + IdOf(C).ToString + ',' +
            IdOf(U).ToString + ');');
    end;
  for C in FProject.Classes do
    if FLinks.IsLinkable(C) then
    begin
      for N in C.NestedClasses do
        if FLinks.IsLinkable(N) then
          Exec('INSERT INTO contains (inner_rowid, outer_rowid) VALUES (' + IdOf(N).ToString + ',' +
            IdOf(C).ToString + ');');
      for B in C.Bases do
        if (B.ClassDef <> nil) and FLinks.IsLinkable(B.ClassDef) then
          Exec('INSERT OR IGNORE INTO compoundref (base_rowid, derived_rowid, prot, virt) VALUES (' +
            IdOf(B.ClassDef).ToString + ',' + IdOf(C).ToString + ',0,0);');
    end;
  for M in FProject.Members do
    if FProject.IsVisible(M) and FLinks.IsLinkable(M) and (M.Scope <> nil) and FIds.ContainsKey(M.Scope) then
    begin
      Member(M);
      for V in M.EnumValues do
        if FLinks.IsLinkable(V) then
          Member(V);
    end;
  for M in FProject.Members do
    if (M.Reimplements <> nil) and FIds.ContainsKey(M) and FIds.ContainsKey(M.Reimplements) then
      Exec('INSERT OR IGNORE INTO reimplements (memberdef_rowid, reimplemented_rowid) VALUES (' +
        IdOf(M).ToString + ',' + IdOf(M.Reimplements).ToString + ');');
  Includes;
  Xrefs;
  Exec('COMMIT;');
  FSB.Append(Views);
  Result := FSB.ToString;
end;

function GenerateSqlite(AProject: TProject; AConfig: TConfig; const AOutDir: string): Integer;
var
  G: TSqliteGenerator;
begin
  TDirectory.CreateDirectory(AOutDir);
  G := TSqliteGenerator.Create(AProject, AConfig);
  try
    TFile.WriteAllText(TPath.Combine(AOutDir, 'doxygen_sqlite3.sql'), G.Script, TUTF8Encoding.Create(False));
  finally
    G.Free;
  end;
  Result := 1;
end;

end.
