unit DoxyPas.Output.HtmlGen;

{ HTML output (Doxygen's htmlgen + index + ftvhelp + searchindex_js): one page per class, unit, group and page, the
  index pages, the menu / navigation tree / search data and the style sheets and scripts of Doxygen's own templates.
  Units are the "namespaces" of the output. Not (yet) supported: graphs, source browser, LaTeX formulas, server
  based search, static tabs (HTML_DYNAMIC_MENUS = NO), LAYOUT_FILE. }

interface

uses
  DoxyPas.Config,
  DoxyPas.Model.Project;

/// <summary>Writes the HTML files into AOutDir (created if needed). Returns the number of files written.</summary>
function GenerateHtml(AProject: TProject; AConfig: TConfig; const AOutDir: string): Integer;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Hash,
  System.Generics.Collections,
  System.Generics.Defaults,
  DoxyPas.Core.Version,
  DoxyPas.Model.Entry,
  DoxyPas.Model.Defs,
  DoxyPas.Model.Links,
  DoxyPas.Output.HtmlTemplate,
  DoxyPas.Output.Translator,
  DoxyPas.Output.HtmlDoc,
  DoxyPas.Output.HtmlCode,
  DoxyPas.Resources.Html;

type
  TNavNode = class
  public
    Name, Url: string;
    Kids: TObjectList<TNavNode>;
    constructor Create(const AName, AUrl: string);
    destructor Destroy; override;
    function Add(const AName, AUrl: string): TNavNode;
  end;

  TSearchTerm = record
    Word: string;     // the indexed word
    Title: string;    // shown when the word is unique
    Url: string;
    Scope: string;    // shown for a unique result
    Named: string;    // shown in the expanded list of an ambiguous word
  end;

  THtmlGenerator = class
  strict private
    FProject: TProject;
    FConfig: TConfig;
    FLinks: TLinkResolver;
    FDoc: THtmlDocWriter;
    FDir: string;
    FExt: string;
    FFiles: Integer;
    FColors: THtmlColors;
    FLight, FDark: string;
    FTree, FSearch, FNoIndex, FSidebar, FFold, FDynSec, FClip: Boolean;
    FSortDocs, FSortBrief: Boolean;
    FProjectName, FProjectNumber, FProjectBrief, FProjectLogo, FProjectIcon, FStyleSheet: string;
    FExtraCss: TArray<string>;
    FHeader, FFooter: string;
    FProjectId: string;
    FPage: TStringBuilder;
    FPageFile, FPageTitle: string;
    FHasPages, FHasGroups, FHasClasses, FHasUnits: Boolean;
    FDotGraphs: Boolean;      // HAVE_DOT and CLASS_GRAPH: draw the inheritance diagrams (Windows only for now)
    FDotPath: string;
    FNav: TObjectList<TNavNode>;
    FNavIndex: TList<TPair<string, string>>;
    FSearchTerms: array of TList<TSearchTerm>;
    procedure W(const S: string);
    procedure SaveText(const ARelName, AText: string);
    function ReadTemplate(const AOption, AResource: string): string;
    function Template(const AText, ATitle, ANavPath: string): string;
    function SearchBoxHtml: string;
    function ConfigScript: string;
    procedure QuickLinks(AMenu: Boolean);
    procedure SplitBar(const AMembersFile: string);
    procedure BeginPage(const AFile, ATitle: string; const AMembersFile: string = '');
    procedure EndPage(const ANavPath: string = '');
    procedure PageHeader(const ATitle: string; const ASummary: string = '');
    function Url(const AFile: string): string;
    function IconSpan(const ALetter: string): string;
    function ClassIcon(C: TClassDef): string;
    function ClassKindText(C: TClassDef): string;
    function ClassTitle(C: TClassDef): string;
    function UnitTitle(U: TUnitDef): string;
    function BriefOf(ADef: TDefinition): string;
    function DefinedAt(ADef: TDefinition): string;
    function VisibleMembers(AList: TList<TMemberDef>): TList<TMemberDef>;
    function IsDocPage(M: TMemberDef): Boolean;
    // members
    function SectionKey(M: TMemberDef; AInUnit: Boolean): string;
    function SectionTitle(const AKey: string): string;
    function IsConstructor(M: TMemberDef): Boolean;
    function ArgsHtml(M: TMemberDef; ADefaults: Boolean): string;
    function DirectivesText(M: TMemberDef): string;
    function LeftHtml(M: TMemberDef): string;
    function RightHtml(M: TMemberDef): string;
    function ProtoHtml(M: TMemberDef): string;
    function MemberRows(M: TMemberDef; const AInheritClass: string): string;
    procedure DeclSections(AMembers: TList<TMemberDef>; AInUnit: Boolean; ARows, ASummary: TStringBuilder);
    procedure InheritedSections(C: TClassDef; ARows: TStringBuilder);
    function MemberDoc(M: TMemberDef): string;
    function DocSections(AMembers: TList<TMemberDef>; AInUnit: Boolean): string;
    function DetailedBlock(ADef: TDefinition; AWithHeading: Boolean): string;
    function NavPathOf(ADef: TDefinition): string;
    // pages
    function ClassDot(C: TClassDef): string;
    function ClassGraph(C: TClassDef): string;
    procedure WriteMainPage;
    procedure WriteClass(C: TClassDef);
    procedure WriteMembersPage(C: TClassDef);
    procedure WriteUnit(U: TUnitDef);
    procedure WriteGroup(G: TGroupDef);
    procedure WritePage(P: TPageDef);
    // index pages
    procedure DirRow(var ARow: Integer; ALevel: Integer; const AIcon, ALink, ABrief: string);
    procedure ClassTreeRows(C: TClassDef; ALevel: Integer; var ARow: Integer; ASB: TStringBuilder);
    procedure HierarchyRows(C: TClassDef; ALevel: Integer; var ARow: Integer; ASB: TStringBuilder);
    procedure GroupRows(G: TGroupDef; ALevel: Integer; var ARow: Integer; ASB: TStringBuilder);
    procedure WriteAnnotated;
    procedure WriteClassIndex;
    procedure WriteHierarchy;
    procedure WriteUnitList;
    procedure WriteTopics;
    procedure WritePagesIndex;
    procedure WriteFunctionsIndex;
    // data
    procedure WriteStatic;
    procedure WriteMenuData;
    procedure BuildNav;
    procedure WriteHtmlHelp;
    function NavJs(ANodes: TObjectList<TNavNode>; ALevel: Integer; const APath: string; var AFirst: Boolean): Boolean;
    procedure RegisterNav(ANodes: TObjectList<TNavNode>; const APath: string);
    procedure WriteNavTree;
    procedure AddTerm(ACategory: Integer; const AWord, ATitle, AUrl, AScope, ANamed: string);
    procedure CollectSearch;
    procedure WriteSearchData;
  public
    constructor Create(AProject: TProject; AConfig: TConfig; const ADir: string);
    destructor Destroy; override;
    function Run: Integer;
  end;

const
  LicenseText =
    '/*'#10' @licstart  The following is the entire license notice for the JavaScript code in this file.'#10#10 +
    ' This program is free software; you can redistribute it and/or modify it under the terms of the GNU General'#10 +
    ' Public License as published by the Free Software Foundation; either version 2 of the License, or (at your'#10 +
    ' option) any later version.'#10#10' @licend  The above is the entire license notice for the JavaScript code in this file'#10' */'#10;

  SearchNames: array[0..10] of string = ('all', 'classes', 'namespaces', 'functions', 'variables', 'typedefs',
    'enums', 'enumvalues', 'properties', 'groups', 'pages');
  SearchLabels: array[0..10] of string = ('All', 'Classes', 'Units', 'Functions', 'Variables', 'Typedefs',
    'Enumerations', 'Enumerator', 'Properties', 'Topics', 'Pages');
  CAll = 0; CClasses = 1; CUnits = 2; CFunctions = 3; CVariables = 4; CTypedefs = 5; CEnums = 6; CEnumValues = 7;
  CProperties = 8; CGroups = 9; CPages = 10;

{$IFDEF MSWINDOWS}
// Runs a command line in ADir and waits for it; False when it could not be started or exited with a non-zero code.
function RunTool(const ACmd, ADir: string): Boolean;
var
  SI: TStartupInfo;
  PI: TProcessInformation;
  Cmd: string;
  Code: Cardinal;
begin
  Result := False;
  ZeroMemory(@SI, SizeOf(SI));
  SI.cb := SizeOf(SI);
  Cmd := ACmd;
  UniqueString(Cmd);
  if CreateProcess(nil, PChar(Cmd), nil, nil, False, CREATE_NO_WINDOW, nil, PChar(ADir), SI, PI) then
  begin
    WaitForSingleObject(PI.hProcess, 600000);
    GetExitCodeProcess(PI.hProcess, Code);
    Result := Code = 0;
    CloseHandle(PI.hProcess);
    CloseHandle(PI.hThread);
  end;
end;

// Runs hhc.exe on index.hhp and waits for it (it exits with 1 when the CHM was built).
procedure RunHhc(const AHhc, ADir: string);
begin
  RunTool('"' + AHhc + '" index.hhp', ADir);
end;
{$ENDIF}

function DotQuote(const S: string): string;
begin
  Result := '"' + S.Replace('\', '\\').Replace('"', '\"') + '"';
end;

{ TNavNode }

constructor TNavNode.Create(const AName, AUrl: string);
begin
  inherited Create;
  Name := AName;
  Url := AUrl;
  Kids := TObjectList<TNavNode>.Create(True);
end;

destructor TNavNode.Destroy;
begin
  Kids.Free;
  inherited;
end;

function TNavNode.Add(const AName, AUrl: string): TNavNode;
begin
  Result := TNavNode.Create(AName, AUrl);
  Kids.Add(Result);
end;

{ THtmlGenerator }

constructor THtmlGenerator.Create(AProject: TProject; AConfig: TConfig; const ADir: string);
var
  I: Integer;
begin
  inherited Create;
  FProject := AProject;
  FConfig := AConfig;
  FDir := ADir;
  FLinks := TLinkResolver.Create(AProject);
  SetOutputLanguage(AConfig.GetString('OUTPUT_LANGUAGE'));
  FExt := AConfig.GetString('HTML_FILE_EXTENSION');
  if FExt = '' then
    FExt := '.html';
  if FExt[1] <> '.' then
    FExt := '.' + FExt;
  FDoc := THtmlDocWriter.Create(FLinks, FExt);
{$IFDEF MSWINDOWS}
  FDotGraphs := AConfig.GetBool('HAVE_DOT') and SameText(AConfig.GetString('CLASS_GRAPH'), 'YES');
  FDotPath := AConfig.GetString('DOT_PATH');
  if FDotPath <> '' then
    FDotPath := IncludeTrailingPathDelimiter(FDotPath);
{$ENDIF}
  FColors := THtmlColors.Parse(AConfig.GetString('HTML_COLORSTYLE'), AConfig.GetInt('HTML_COLORSTYLE_HUE'),
    AConfig.GetInt('HTML_COLORSTYLE_SAT'), AConfig.GetInt('HTML_COLORSTYLE_GAMMA'));
  FLight := HtmlResourceText('lightmode_settings.css');
  FDark := HtmlResourceText('darkmode_settings.css');
  FTree := AConfig.GetBool('GENERATE_TREEVIEW');
  FSearch := AConfig.GetBool('SEARCHENGINE');
  FNoIndex := AConfig.GetBool('DISABLE_INDEX');
  FSidebar := AConfig.GetBool('FULL_SIDEBAR') and FTree;
  FFold := AConfig.GetBool('HTML_CODE_FOLDING');
  FDynSec := AConfig.GetBool('HTML_DYNAMIC_SECTIONS');
  FClip := AConfig.GetBool('HTML_COPY_CLIPBOARD');
  FSortDocs := AConfig.GetBool('SORT_MEMBER_DOCS');
  FSortBrief := AConfig.GetBool('SORT_BRIEF_DOCS');
  FProjectName := AConfig.GetString('PROJECT_NAME');
  FProjectNumber := AConfig.GetString('PROJECT_NUMBER');
  FProjectBrief := AConfig.GetString('PROJECT_BRIEF');
  FProjectLogo := AConfig.GetString('PROJECT_LOGO');
  FProjectIcon := AConfig.GetString('PROJECT_ICON');
  FStyleSheet := AConfig.GetString('HTML_STYLESHEET');
  FExtraCss := AConfig.GetList('HTML_EXTRA_STYLESHEET');
  FHeader := ReadTemplate('HTML_HEADER', 'header.html');
  FFooter := ReadTemplate('HTML_FOOTER', 'footer.html');
  FProjectId := LowerCase(Copy(THashMD5.GetHashString(FProjectName), 1, 8)) + '_';
  FNav := TObjectList<TNavNode>.Create(True);
  FNavIndex := TList<TPair<string, string>>.Create;
  SetLength(FSearchTerms, Length(SearchNames));
  for I := 0 to High(FSearchTerms) do
    FSearchTerms[I] := TList<TSearchTerm>.Create;
end;

destructor THtmlGenerator.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FSearchTerms) do
    FSearchTerms[I].Free;
  FNavIndex.Free;
  FNav.Free;
  FDoc.Free;
  FLinks.Free;
  inherited;
end;

procedure THtmlGenerator.W(const S: string);
begin
  FPage.Append(S);
end;

procedure THtmlGenerator.SaveText(const ARelName, AText: string);
var
  Path: string;
begin
  Path := TPath.Combine(FDir, ARelName.Replace('/', PathDelim));
  TDirectory.CreateDirectory(ExtractFilePath(Path));
  TFile.WriteAllText(Path, AText, TUTF8Encoding.Create(False));
  Inc(FFiles);
end;

function THtmlGenerator.ReadTemplate(const AOption, AResource: string): string;
var
  Name: string;
begin
  Name := FConfig.GetString(AOption);
  if (Name <> '') and TFile.Exists(Name) then
    Result := TFile.ReadAllText(Name, TEncoding.UTF8)
  else
    Result := HtmlResourceText(AResource);
end;

function THtmlGenerator.Url(const AFile: string): string;
begin
  Result := AFile + FExt;
end;

{ ------------------------------------------------------------------ page skeleton }

function THtmlGenerator.SearchBoxHtml: string;
begin
  Result :=
    '        <div id="MSearchBox" class="MSearchBoxInactive">'#10 +
    '        <span class="left">'#10 +
    '          <span id="MSearchSelect" class="search-icon"><span class="search-icon-dropdown"></span></span>'#10 +
    '          <input type="text" id="MSearchField" value="" placeholder="' + Tr('Search') + '" accesskey="S"/>'#10 +
    '          </span><span class="right">'#10 +
    '            <a id="MSearchClose" href="javascript:searchBox.CloseResultsWindow()"><div id="MSearchCloseImg" class="close-icon"></div></a>'#10 +
    '          </span>'#10 +
    '        </div>'#10;
end;

function THtmlGenerator.Template(const AText, ATitle, ANavPath: string): string;
var
  Keys: TDictionary<string, string>;
  Blocks: TDictionary<string, Boolean>;
  Tree, SearchCss, Dark, Extra, Logo, Icon, Title: string;
  HasName, HasNumber, HasBrief, HasLogo, HasIcon, TitleArea: Boolean;
  S: string;
begin
  HasName := FProjectName <> '';
  HasNumber := FProjectNumber <> '';
  HasBrief := FProjectBrief <> '';
  HasLogo := FProjectLogo <> '';
  HasIcon := FProjectIcon <> '';
  TitleArea := HasName or HasBrief or HasLogo or (FNoIndex and FSearch);
  Tree := '';
  if FTree then
    Tree := '<link href="$relpath^navtree.css" rel="stylesheet" type="text/css"/>'#10 +
      '<script type="text/javascript" src="$relpath^navtreedata.js"></script>'#10 +
      '<script type="text/javascript" src="$relpath^navtree.js"></script>'#10;
  if FTree or FSearch or (FColors.Style = csToggle) then
    Tree := Tree + '<script type="text/javascript" src="$relpath^cookie.js"></script>'#10;
  SearchCss := '';
  if FSearch then
    SearchCss := '<link href="$relpath^search/search.css" rel="stylesheet" type="text/css"/>'#10 +
      '<script type="text/javascript" src="$relpath^search/searchdata.js"></script>'#10 +
      '<script type="text/javascript" src="$relpath^search/search.js"></script>'#10;
  Dark := '';
  if FColors.Style = csToggle then
    Dark := '<script type="text/javascript" src="$relpath^darkmode_toggle.js"></script>'#10;
  Extra := '';
  for S in FExtraCss do
    if S <> '' then
      Extra := Extra + '<link href="$relpath^' + ExtractFileName(S) + '" rel="stylesheet" type="text/css"/>'#10;
  Logo := ExtractFileName(FProjectLogo);
  Icon := ExtractFileName(FProjectIcon);
  if ATitle <> '' then
    Title := HtmlEscape(ATitle)
  else
    Title := HtmlEscape(FProjectName);
  Keys := TDictionary<string, string>.Create;
  Blocks := TDictionary<string, Boolean>.Create;
  try
    Keys.Add('$title', Title);
    Keys.Add('$doxygenversion', DoxyPasVersion);
    Keys.Add('$projectname', HtmlEscape(FProjectName));
    Keys.Add('$projectnumber', HtmlEscape(FProjectNumber));
    Keys.Add('$projectbrief', HtmlEscape(FProjectBrief));
    Keys.Add('$projectlogo', Logo);
    Keys.Add('$logosize', '');
    Keys.Add('$projecticon', Icon);
    Keys.Add('$langISO', LanguageIso);
    Keys.Add('$datetime', '<span class="datetime"></span>');
    Keys.Add('$date', '<span class="date"></span>');
    Keys.Add('$time', '<span class="time"></span>');
    Keys.Add('$year', '<span class="year"></span>');
    Keys.Add('$navpath', ANavPath);
    if FStyleSheet <> '' then
      Keys.Add('$stylesheet', ExtractFileName(FStyleSheet))
    else
      Keys.Add('$stylesheet', 'doxygen.css');
    Keys.Add('$treeview', Tree);
    if FSearch then
      Keys.Add('$searchbox', SearchBoxHtml)
    else
      Keys.Add('$searchbox', '');
    Keys.Add('$search', SearchCss);
    Keys.Add('$mathjax', '');
    Keys.Add('$mermaidjs', '');
    Keys.Add('$darkmode', Dark);
    Keys.Add('$generatedby', 'Generated by');
    Keys.Add('$extrastylesheet', Extra);
    Keys.Add('$relpath$', '');
    Blocks.Add('FULL_SIDEBAR', FSidebar);
    Blocks.Add('DISABLE_INDEX', FNoIndex);
    Blocks.Add('GENERATE_TREEVIEW', FTree);
    Blocks.Add('SEARCHENGINE', FSearch);
    Blocks.Add('TITLEAREA', TitleArea);
    Blocks.Add('PROJECT_NAME', HasName);
    Blocks.Add('PROJECT_NUMBER', HasNumber);
    Blocks.Add('PROJECT_BRIEF', HasBrief);
    Blocks.Add('PROJECT_LOGO', HasLogo);
    Blocks.Add('PROJECT_ICON', HasIcon);
    Blocks.Add('COPY_CLIPBOARD', FClip);
    Blocks.Add('HTML_CODE_FOLDING', FFold);
    Blocks.Add('HTML_DYNAMIC_SECTIONS', FDynSec);
    Result := SubstituteKeywords(AText, Keys).Replace('$relpath^', '');
    Result := RemoveEmptyLines(SelectBlocks(Result, Blocks));
  finally
    Blocks.Free;
    Keys.Free;
  end;
end;

function THtmlGenerator.ConfigScript: string;

  function B(AValue: Boolean): string;
  begin
    if AValue then Result := 'true' else Result := 'false';
  end;

begin
  Result := '<script type="application/json" id="doxygen-config">'#10'{'#10'  "relPath": "",'#10 +
    '  "generateTreeView": ' + B(FTree) + ','#10'  "searchEngine": ' + B(FSearch) + ','#10 +
    '  "serverBasedSearch": false,'#10'  "disableIndex": ' + B(FNoIndex) + ','#10'  "dynamicMenus": true,'#10 +
    '  "fullSidebar": ' + B(FSidebar) + #10'}'#10'</script>'#10;
end;

procedure THtmlGenerator.QuickLinks(AMenu: Boolean);
begin
  W(ConfigScript);
  if not AMenu then
    Exit;
  W('<script type="text/javascript" src="menudata.js"></script>'#10);
  W('<script type="text/javascript" src="menu.js"></script>'#10);
  W('<div id="main-nav-mobile">'#10);
  if FSearch and not FSidebar then
    W('<div class="sm sm-dox"><input id="main-menu-state" type="checkbox"/>'#10 +
      '<label class="main-menu-btn" for="main-menu-state">'#10 +
      '<span class="main-menu-btn-icon"></span> ' + Tr('Toggle main menu visibility') + '</label>'#10 +
      '<span id="searchBoxPos1"></span>'#10'</div>'#10);
  W('</div><!-- main-nav-mobile -->'#10);
  W('<div id="main-nav">'#10'  <ul class="sm sm-dox" id="main-menu">'#10'    <li id="searchBoxPos2">'#10);
  if FSearch and not (FTree and FSidebar) then
    W(SearchBoxHtml);
  W('    </li>'#10'  </ul>'#10'</div><!-- main-nav -->'#10);
  if FTree and FSidebar then
    W('<div id="container"><div id="doc-content">'#10);
end;

procedure THtmlGenerator.SplitBar(const AMembersFile: string);
begin
  if not FTree then
    Exit;
  if not FSidebar then
    W('<div id="side-nav" class="ui-resizable side-nav-resizable">'#10);
  W('  <div id="nav-tree">'#10'    <div id="nav-tree-contents">'#10'      <div id="nav-sync" class="sync"></div>'#10 +
    '    </div>'#10'  </div>'#10'  <div id="splitbar" class="ui-resizable-handle">'#10'  </div>'#10'</div>'#10 +
    '<script type="text/javascript">'#10 +
    'document.addEventListener(''DOMContentLoaded'',() => { initNavTree(''' + FPageFile + FExt + ''','''',''' +
    AMembersFile + '''); });'#10'</script>'#10);
  if FNoIndex or not FSidebar then
    W('<div id="container">'#10'<div id="doc-content">'#10);
end;

procedure THtmlGenerator.BeginPage(const AFile, ATitle: string; const AMembersFile: string);
begin
  FPageFile := AFile;
  FPageTitle := ATitle;
  FPage := TStringBuilder.Create;
  W(Template(FHeader, ATitle, ''));
  W('<!-- Generated by DoxyPas ' + DoxyPasVersion + ' -->'#10);
  if FSearch then
    W('<script type="text/javascript">'#10'let searchBox = new SearchBox("searchBox", "search/",''' + FExt +
      ''');'#10'</script>'#10);
  if FFold then
    W('<script type="text/javascript">'#10'document.addEventListener(''DOMContentLoaded'', codefold.init);'#10 +
      '</script>'#10);
  if not FSidebar then
    QuickLinks(not FNoIndex);
  W('</div><!-- top -->'#10);
  if FTree then
    SplitBar(AMembersFile)
  else
    W('<div id="doc-content">'#10);
  if FSidebar then
    QuickLinks(not FNoIndex);
  if FSearch then
    W('<!-- window showing the filter options -->'#10'<div id="MSearchSelectWindow">'#10'</div>'#10#10 +
      '<!-- iframe showing the search results (closed by default) -->'#10'<div id="MSearchResultsWindow">'#10 +
      '<div id="MSearchResults">'#10'<div class="SRPage">'#10'<div id="SRIndex">'#10 +
      '<div id="SRResults"></div>'#10'<div class="SRStatus" id="Loading">' + Tr('Loading...') + '</div>'#10 +
      '<div class="SRStatus" id="Searching">' + Tr('Searching...') + '</div>'#10 +
      '<div class="SRStatus" id="NoMatches">' + Tr('No Matches') + '</div>'#10'</div>'#10'</div>'#10'</div>'#10'</div>'#10#10);
end;

procedure THtmlGenerator.EndPage(const ANavPath: string);
begin
  W('</div><!-- contents -->'#10);
  if FTree then
    W('</div><!-- doc-content -->'#10);
  W(Template(FFooter, FPageTitle, ANavPath));
  SaveText(FPageFile + FExt, FPage.ToString);
  FreeAndNil(FPage);
end;

procedure THtmlGenerator.PageHeader(const ATitle, ASummary: string);
begin
  W('<div class="header">'#10);
  if ASummary <> '' then
    W('  <div class="summary">'#10 + ASummary + '</div>'#10);
  W('  <div class="headertitle"><div class="title">' + HtmlEscape(ATitle) + '</div></div>'#10 +
    '</div><!--header-->'#10'<div class="contents">'#10);
end;

{ ------------------------------------------------------------------ helpers }

function THtmlGenerator.IconSpan(const ALetter: string): string;
begin
  Result := '<span class="icona"><span class="icon">' + ALetter + '</span></span>';
end;

function THtmlGenerator.ClassIcon(C: TClassDef): string;
begin
  case C.ClassKind of
    ckRecord, ckRecordHelper: Result := 'S';
    ckInterface, ckDispInterface: Result := 'I';
  else
    Result := 'C';
  end;
end;

function THtmlGenerator.ClassTitle(C: TClassDef): string;
begin
  Result := Format(Tr('%0:s %1:s Reference'), [C.QualifiedName, Tr(ClassKindText(C))]);
end;

function THtmlGenerator.UnitTitle(U: TUnitDef): string;
begin
  Result := Format(Tr('%0:s %1:s Reference'), [U.Name, Tr('Unit')]);
end;

function THtmlGenerator.ClassKindText(C: TClassDef): string;
begin
  case C.ClassKind of
    ckRecord, ckRecordHelper: Result := Tr('Record');
    ckInterface, ckDispInterface: Result := 'Interface';
    ckObject: Result := 'Object';
    ckClassHelper, ckTypeHelper: Result := 'Helper';
  else
    Result := 'Class';
  end;
end;

function THtmlGenerator.BriefOf(ADef: TDefinition): string;
begin
  Result := FDoc.RenderBrief(ADef.Brief, ADef);
end;

function THtmlGenerator.DefinedAt(ADef: TDefinition): string;
var
  E: TEntry;
begin
  E := ADef.Entry;
  if (E = nil) or (E.FileName = '') then
    Exit('');
  Result := '<p class="definition">' + HtmlEscape(Format(Tr('Definition at line %d of file %s.'),
    [E.Line, ExtractFileName(FProject.OutputPath(E.FileName))])) + '</p>'#10;
end;

function THtmlGenerator.VisibleMembers(AList: TList<TMemberDef>): TList<TMemberDef>;
var
  M: TMemberDef;
begin
  Result := TList<TMemberDef>.Create;
  for M in AList do
    if FProject.IsVisible(M) then
      Result.Add(M);
  if FSortBrief then
    Result.Sort(TComparer<TMemberDef>.Construct(
      function(const A, B: TMemberDef): Integer
      begin
        Result := CompareText(A.Name, B.Name);
      end));
end;

// a member has an entry in the "documentation" part of the page
function THtmlGenerator.IsDocPage(M: TMemberDef): Boolean;
begin
  Result := FLinks.IsLinkable(M);
end;

function THtmlGenerator.NavPathOf(ADef: TDefinition): string;
var
  Chain: TList<TDefinition>;
  D: TDefinition;
begin
  Result := '';
  Chain := TList<TDefinition>.Create;
  try
    D := ADef;
    while D <> nil do
    begin
      if (D is TUnitDef) or (D is TClassDef) then
        Chain.Insert(0, D);
      D := D.Scope;
    end;
    for D in Chain do
      Result := Result + '<li class="navelem"><a class="el" href="' + HtmlEscape(FDoc.DefUrl(D)) + '">' +
        HtmlEscape(D.Name) + '</a></li>';
  finally
    Chain.Free;
  end;
end;

{ ------------------------------------------------------------------ members }

function THtmlGenerator.IsConstructor(M: TMemberDef): Boolean;
begin
  Result := (M.Kind = memFunction) and (M.Entry <> nil) and (M.Entry.MethodKind in [rkConstructor, rkDestructor]);
end;

function THtmlGenerator.SectionKey(M: TMemberDef; AInUnit: Boolean): string;
var
  P, What: string;
  Static: Boolean;
begin
  if M.Kind = memProperty then
    Exit('properties');
  if AInUnit then
  begin
    case M.Kind of
      memTypedef: Result := 'typedef-members';
      memEnumeration: Result := 'enum-members';
      memFunction: Result := 'func-members';
    else
      Result := 'var-members';
    end;
    Exit;
  end;
  case M.Protection of
    prProtected, prStrictProtected: P := 'pro';
    prPrivate, prStrictPrivate: P := 'pri';
  else
    P := 'pub';
  end;
  Static := (M.Entry <> nil) and ([efClassMember, efStatic] * M.Entry.Flags <> []);
  case M.Kind of
    memTypedef, memEnumeration: What := 'types';
    memFunction: if Static then What := 'static-methods' else What := 'methods';
  else
    if Static then What := 'static-attribs' else What := 'attribs';
  end;
  Result := P + '-' + What;
end;

function THtmlGenerator.SectionTitle(const AKey: string): string;
var
  P, What: string;
begin
  if AKey = 'properties' then Exit(Tr('Properties'));
  if AKey = 'typedef-members' then Exit(Tr('Typedefs'));
  if AKey = 'enum-members' then Exit(Tr('Enumerations'));
  if AKey = 'func-members' then Exit(Tr('Functions'));
  if AKey = 'var-members' then Exit(Tr('Variables'));
  if AKey.StartsWith('pub-') then P := 'Public'
  else if AKey.StartsWith('pro-') then P := 'Protected'
  else P := 'Private';
  What := Copy(AKey, 5, MaxInt);
  if What = 'types' then Result := TrSection(P, 'Types')
  else if What = 'methods' then Result := TrSection(P, 'Member Functions')
  else if What = 'static-methods' then Result := TrSection(P, 'Static Member Functions')
  else if What = 'attribs' then Result := TrSection(P, 'Attributes')
  else Result := TrSection(P, 'Static Attributes');
end;

function THtmlGenerator.ArgsHtml(M: TMemberDef; ADefaults: Boolean): string;
var
  A: TArgument;
  S: string;
begin
  Result := '';
  for A in M.Entry.Args do
  begin
    S := '';
    if A.Modifier <> '' then
      S := A.Modifier + ' ';
    S := HtmlEscape(S + A.Name);
    if A.TypeText <> '' then
      S := S + ': ' + FDoc.LinkedText(A.TypeText, M);
    if ADefaults and (A.DefaultText <> '') then
      S := S + ' = ' + FDoc.LinkedText(A.DefaultText, M);
    if Result <> '' then
      Result := Result + '; ';
    Result := Result + S;
  end;
  if (Result <> '') or ((M.Kind = memFunction) and (M.Entry.Kind = ekMethod)) then
    Result := '(' + Result + ')';
end;

function THtmlGenerator.DirectivesText(M: TMemberDef): string;
var
  E: TEntry;
  L: TStringList;
  S: string;
begin
  E := M.Entry;
  L := TStringList.Create;
  try
    case E.Virtualness of
      vtVirtual: L.Add('virtual');
      vtDynamic: L.Add('dynamic');
      vtOverride: L.Add('override');
    end;
    if efAbstract in E.Flags then L.Add('abstract');
    if efOverload in E.Flags then L.Add('overload');
    if efReintroduce in E.Flags then L.Add('reintroduce');
    if efFinal in E.Flags then L.Add('final');
    if efInline in E.Flags then L.Add('inline');
    if efStatic in E.Flags then L.Add('static');
    if E.CallConv <> '' then L.Add(E.CallConv);
    for S in E.Directives do
      L.Add(S);
    Result := '';
    for S in L do
      Result := Result + '; ' + KeywordSpan(S);
  finally
    L.Free;
  end;
end;

function RoutineWord(M: TMemberDef): string;
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

function THtmlGenerator.LeftHtml(M: TMemberDef): string;
begin
  case M.Kind of
    memFunction: Result := RoutineWord(M);
    memProperty: Result := 'property';
    memConstant: Result := 'const';
    memTypedef: Result := 'type';
    memEnumeration: Result := 'enum';
    memVariable: if M.Scope is TClassDef then Result := '' else Result := 'var';
  else
    Result := '';
  end;
  if Result = '' then
    Result := '&#160;'
  else
    Result := KeywordSpan(Result) + '&#160;';
end;

function THtmlGenerator.RightHtml(M: TMemberDef): string;
var
  E: TEntry;
  V: TMemberDef;
  Vals: string;
  N: Integer;
begin
  E := M.Entry;
  Result := FDoc.Link(M, M.Name);
  case M.Kind of
    memFunction:
      begin
        Result := Result + ' ' + ArgsHtml(M, True);
        if E.TypeText <> '' then
          Result := Result + ': ' + FDoc.LinkedText(E.TypeText, M);
        Result := Result + DirectivesText(M);
      end;
    memProperty:
      begin
        if E.Args.Count > 0 then
          Result := Result + '[' + ArgsHtml(M, False).Trim(['(', ')']) + ']';
        if E.TypeText <> '' then
          Result := Result + ': ' + FDoc.LinkedText(E.TypeText, M);
      end;
    memVariable, memConstant:
      begin
        if E.TypeText <> '' then
          Result := Result + ': ' + FDoc.LinkedText(E.TypeText, M);
        if E.InitText <> '' then
          Result := Result + ' = ' + FDoc.LinkedText(E.InitText, M);
      end;
    memTypedef:
      if E.TypeText <> '' then
        Result := Result + ' = ' + FDoc.LinkedText(E.TypeText, M);
    memEnumeration:
      begin
        Vals := '';
        N := 0;
        for V in M.EnumValues do
        begin
          if N >= 6 then
          begin
            Vals := Vals + ', ...';
            Break;
          end;
          if Vals <> '' then
            Vals := Vals + ', ';
          Vals := Vals + FDoc.Link(V, V.Name);
          Inc(N);
        end;
        if Vals <> '' then
          Result := Result + ' { ' + Vals + ' }';
      end;
  end;
end;

function THtmlGenerator.ProtoHtml(M: TMemberDef): string;
var
  E: TEntry;
  Name: string;
begin
  E := M.Entry;
  if M.Scope is TClassDef then
    Name := HtmlEscape(M.Scope.Name + '.' + M.Name)
  else
    Name := HtmlEscape(M.Name);
  case M.Kind of
    memFunction:
      begin
        Result := KeywordSpan(RoutineWord(M)) + ' ' + Name + ' ' + ArgsHtml(M, True);
        if E.TypeText <> '' then
          Result := Result + ': ' + FDoc.LinkedText(E.TypeText, M);
        Result := Result + DirectivesText(M);
      end;
    memProperty:
      begin
        Result := KeywordSpan('property') + ' ' + Name;
        if E.Args.Count > 0 then
          Result := Result + '[' + ArgsHtml(M, False).Trim(['(', ')']) + ']';
        if E.TypeText <> '' then
          Result := Result + ': ' + FDoc.LinkedText(E.TypeText, M);
        if E.ReadAccessor <> '' then
          Result := Result + ' ' + KeywordSpan('read') + ' ' + HtmlEscape(E.ReadAccessor);
        if E.WriteAccessor <> '' then
          Result := Result + ' ' + KeywordSpan('write') + ' ' + HtmlEscape(E.WriteAccessor);
      end;
    memConstant:
      begin
        Result := KeywordSpan('const') + ' ' + Name;
        if E.TypeText <> '' then
          Result := Result + ': ' + FDoc.LinkedText(E.TypeText, M);
        if E.InitText <> '' then
          Result := Result + ' = ' + FDoc.LinkedText(E.InitText, M);
      end;
    memTypedef:
      begin
        Result := KeywordSpan('type') + ' ' + Name;
        if E.TypeText <> '' then
          Result := Result + ' = ' + FDoc.LinkedText(E.TypeText, M);
      end;
    memEnumeration: Result := KeywordSpan('enum') + ' ' + Name;
  else
    begin
      Result := Name;
      if E.TypeText <> '' then
        Result := Result + ': ' + FDoc.LinkedText(E.TypeText, M);
      if E.InitText <> '' then
        Result := Result + ' = ' + FDoc.LinkedText(E.InitText, M);
    end;
  end;
end;

function THtmlGenerator.MemberRows(M: TMemberDef; const AInheritClass: string): string;
var
  Cls, Brief, More: string;
  Id: string;
begin
  Id := M.DiskName;
  Cls := 'memitem:' + Id;
  if AInheritClass <> '' then
    Cls := Cls + ' ' + AInheritClass;
  Result := '<tr class="' + Cls + '" id="r_' + Id + '"><td class="memItemLeft" align="right" valign="top">' +
    LeftHtml(M) + '</td><td class="memItemRight" valign="bottom">' + RightHtml(M) + '</td></tr>'#10;
  Brief := BriefOf(M);
  if Brief <> '' then
  begin
    More := '';
    if IsDocPage(M) and (Trim(M.Detailed) <> '') and (AInheritClass = '') then
      More := ' <a href="#' + Id + '">More...</a>';
    Result := Result + '<tr class="memdesc:' + Id + '"><td class="mdescLeft">&#160;</td><td class="mdescRight">' +
      Brief + More + '<br /></td></tr>'#10;
  end;
  Result := Result + '<tr class="separator:' + Id + '"><td class="memSeparator" colspan="2">&#160;</td></tr>'#10;
end;

procedure THtmlGenerator.DeclSections(AMembers: TList<TMemberDef>; AInUnit: Boolean; ARows, ASummary: TStringBuilder);
const
  UnitOrder: array[0..3] of string = ('typedef-members', 'enum-members', 'func-members', 'var-members');
  Prots: array[0..2] of string = ('pub', 'pro', 'pri');
  Kinds: array[0..4] of string = ('types', 'methods', 'static-methods', 'attribs', 'static-attribs');
var
  Order: TList<string>;
  Key, P, K: string;
  M: TMemberDef;
  Any: Boolean;
begin
  Order := TList<string>.Create;
  try
    if AInUnit then
      Order.AddRange(UnitOrder)
    else
    begin
      for K in Kinds do
        Order.Add('pub-' + K);
      Order.Add('properties');
      for P in Prots do
        if P <> 'pub' then
          for K in Kinds do
            Order.Add(P + '-' + K);
    end;
    for Key in Order do
    begin
      Any := False;
      for M in AMembers do
        if SectionKey(M, AInUnit) = Key then
          Any := True;
      if not Any then
        Continue;
      ARows.Append('<tr class="heading"><td colspan="2"><h2 class="groupheader"><a id="' + Key + '" name="' + Key +
        '"></a>'#10 + SectionTitle(Key) + '</h2></td></tr>'#10);
      if ASummary.Length > 0 then
        ASummary.Append(' &#124;'#10);
      ASummary.Append('<a href="#' + Key + '">' + SectionTitle(Key) + '</a>');
      for M in AMembers do
        if SectionKey(M, AInUnit) = Key then
          ARows.Append(MemberRows(M, ''));
    end;
  finally
    Order.Free;
  end;
end;

procedure THtmlGenerator.InheritedSections(C: TClassDef; ARows: TStringBuilder);
const
  Keys: array[0..5] of string = ('pub-types', 'pub-methods', 'pub-static-methods', 'pub-attribs',
    'pub-static-attribs', 'properties');
var
  Froms: TList<TClassDef>;
  IM: TInheritedMember;
  F: TClassDef;
  Key, Cls: string;
  Any: Boolean;

  function Wanted(const AIM: TInheritedMember): Boolean;
  begin
    Result := (AIM.From <> C) and FProject.IsVisible(AIM.Member) and (AIM.Member.Kind <> memEnumValue) and
      FLinks.IsLinkable(AIM.Member) and (AIM.Member.Protection in [prPublic, prPublished, prProtected,
      prStrictProtected]);
  end;

begin
  Froms := TList<TClassDef>.Create;
  try
    for IM in C.AllMembers do
      if Wanted(IM) and (Froms.IndexOf(IM.From) < 0) then
        Froms.Add(IM.From);
    if Froms.Count = 0 then
      Exit;
    ARows.Append('<tr class="heading"><td colspan="2"><h2 class="groupheader"><a id="inherited" name="inherited"></a>'#10 +
      'Additional Inherited Members</h2></td></tr>'#10);
    for F in Froms do
    begin
      Cls := 'inherit ' + FDoc.DefUrl(F).Replace('.', '_');
      Any := False;
      for IM in C.AllMembers do
        if Wanted(IM) and (IM.From = F) then
          Any := True;
      if not Any then
        Continue;
      for Key in Keys do
      begin
        Any := False;
        for IM in C.AllMembers do
          if Wanted(IM) and (IM.From = F) and (SectionKey(IM.Member, False) = Key) then
          begin
            if not Any then
              ARows.Append('<tr class="inherit_header ' + Key + '_' + F.DiskName + '"><td colspan="2">' +
                SectionTitle(Key) + ' ' + Tr('inherited from') + ' <a class="el" href="' + HtmlEscape(FDoc.DefUrl(F)) + '">' +
                HtmlEscape(F.Name) + '</a></td></tr>'#10);
            Any := True;
            ARows.Append(MemberRows(IM.Member, Key + '_' + F.DiskName));
          end;
      end;
    end;
  finally
    Froms.Free;
  end;
end;

function THtmlGenerator.MemberDoc(M: TMemberDef): string;
var
  E: TEntry;
  Title, Body, Tail, Rows, Init: string;
  V, O: TMemberDef;
  AnyInit: Boolean;
  SB: TStringBuilder;
begin
  E := M.Entry;
  Title := HtmlEscape(M.Name);
  if M.Kind = memFunction then
    Title := Title + '()';
  Body := FDoc.Render(M.Brief + #10#10 + M.Detailed, M);
  Tail := '';
  if M.Reimplements <> nil then
    Tail := Tail + '<p>' + Tr('Reimplemented from') + ' ' + FDoc.Link(M.Reimplements.Scope, M.Reimplements.Scope.Name) + '.</p>'#10;
  if M.ReimplementedBy.Count > 0 then
  begin
    Rows := '';
    for O in M.ReimplementedBy do
      if FProject.IsVisible(O) and (O.Scope <> nil) then
      begin
        if Rows <> '' then
          Rows := Rows + ', ';
        Rows := Rows + FDoc.Link(O.Scope, O.Scope.Name);
      end;
    if Rows <> '' then
      Tail := Tail + '<p>' + Tr('Reimplemented in') + ' ' + Rows + '.</p>'#10;
  end;
  if M.Kind = memEnumeration then
  begin
    AnyInit := False;
    for V in M.EnumValues do
      if (V.Entry <> nil) and (V.Entry.InitText <> '') then
        AnyInit := True;
    SB := TStringBuilder.Create;
    try
      if M.EnumValues.Count > 0 then
      begin
        SB.Append('<table class="fieldtable">'#10'<tr><th colspan="');
        if AnyInit then SB.Append('3') else SB.Append('2');
        SB.Append('">' + Tr('Enumerator') + '</th></tr>');
        for V in M.EnumValues do
        begin
          SB.Append('<tr><td class="fieldname"><a id="' + V.DiskName + '" name="' + V.DiskName + '"></a>' +
            HtmlEscape(V.Name) + '&#160;</td>');
          if AnyInit then
          begin
            Init := '';
            if (V.Entry <> nil) and (V.Entry.InitText <> '') then
              Init := '= ' + FDoc.LinkedText(V.Entry.InitText, M);
            SB.Append('<td class="fieldinit">' + Init + '&#160;</td>');
          end;
          SB.Append('<td class="fielddoc">' + FDoc.Render(V.Brief + #10#10 + V.Detailed, V).Trim + '</td></tr>'#10);
        end;
        SB.Append('</table>'#10);
      end;
      Body := Body + SB.ToString;
    finally
      SB.Free;
    end;
  end;
  Result := '<a id="' + M.DiskName + '" name="' + M.DiskName + '"></a>'#10 +
    '<h2 class="memtitle"><span class="permalink"><a href="#' + M.DiskName + '">&#9670;&#160;</a></span>' + Title +
    '</h2>'#10#10'<div class="memitem">'#10'<div class="memproto">'#10 +
    '      <table class="memname">'#10'        <tr>'#10'          <td class="memname">' + ProtoHtml(M) +
    '</td>'#10'        </tr>'#10'      </table>'#10'</div><div class="memdoc">'#10 + Body + Tail + DefinedAt(M) +
    #10'</div>'#10'</div>'#10;
end;

function THtmlGenerator.DocSections(AMembers: TList<TMemberDef>; AInUnit: Boolean): string;
const
  ClassGroups: array[0..5] of string = ('Constructor & Destructor Documentation', 'Member Typedef Documentation',
    'Member Enumeration Documentation', 'Member Function Documentation', 'Member Data Documentation',
    'Property Documentation');
  UnitGroups: array[0..5] of string = ('', 'Typedef Documentation', 'Enumeration Type Documentation',
    'Function Documentation', 'Variable Documentation', '');

  function GroupOf(M: TMemberDef): Integer;
  begin
    if IsConstructor(M) then Exit(0);
    case M.Kind of
      memTypedef: Result := 1;
      memEnumeration: Result := 2;
      memFunction: Result := 3;
      memProperty: Result := 5;
    else
      Result := 4;
    end;
  end;

var
  G: Integer;
  M: TMemberDef;
  Docs: TList<TMemberDef>;
  Title: string;
begin
  Result := '';
  Docs := TList<TMemberDef>.Create;
  try
    for G := 0 to 5 do
    begin
      Docs.Clear;
      for M in AMembers do
        if IsDocPage(M) and (GroupOf(M) = G) then
          Docs.Add(M);
      if Docs.Count = 0 then
        Continue;
      if FSortDocs then
        Docs.Sort(TComparer<TMemberDef>.Construct(
          function(const A, B: TMemberDef): Integer
          begin
            Result := CompareText(A.Name, B.Name);
          end));
      if AInUnit then Title := Tr(UnitGroups[G]) else Title := Tr(ClassGroups[G]);
      if (Title = '') and AInUnit then
        Title := Tr(UnitGroups[3]);
      Result := Result + '<h2 class="groupheader">' + HtmlEscape(Title) + '</h2>'#10;
      for M in Docs do
        Result := Result + MemberDoc(M);
    end;
  finally
    Docs.Free;
  end;
end;

function THtmlGenerator.DetailedBlock(ADef: TDefinition; AWithHeading: Boolean): string;
var
  Text: string;
begin
  Text := FDoc.Render(ADef.Detailed, ADef);
  if (Text = '') and (DefinedAt(ADef) = '') then
    Exit('');
  Result := '<a name="details" id="details"></a><h2 class="groupheader">Detailed Description</h2>'#10 +
    '<div class="textblock">' + Text + '</div>'#10 + DefinedAt(ADef);
end;

{ ------------------------------------------------------------------ pages }

// Doxygen's inheritance graph: all ancestors above the class, its descendants (three levels) below it.
function THtmlGenerator.ClassDot(C: TClassDef): string;
const
  MaxDepth = 3;
var
  SB: TStringBuilder;
  Ids: TDictionary<string, Integer>;
  Max: Integer;

  function NodeOf(const AKey, ALabel, AUrl: string; AStyle: string): Integer;
  begin
    if Ids.TryGetValue(AKey, Result) then
      Exit;
    Result := Ids.Count;
    Ids.Add(AKey, Result);
    SB.Append('  n').Append(Result).Append(' [label=').Append(DotQuote(ALabel)).Append(AStyle);
    if AUrl <> '' then
      SB.Append(', URL=').Append(DotQuote(AUrl)).Append(', target="_top"');
    SB.Append('];'#10);
  end;

  function ClassNode(X: TClassDef; ARoot: Boolean): Integer;
  begin
    if ARoot then
      Result := NodeOf(X.DiskName, X.Name, '', ', fillcolor="#bfbfbf"')
    else
      Result := NodeOf(X.DiskName, X.Name, FDoc.DefUrl(X), '');
  end;

  procedure Ancestors(X: TClassDef; AId: Integer);
  var
    B: TBaseRef;
    P: Integer;
  begin
    for B in X.Bases do
    begin
      if Ids.Count >= Max then
        Exit;
      if (B.ClassDef <> nil) and FLinks.IsLinkable(B.ClassDef) then
      begin
        P := ClassNode(B.ClassDef, False);
        SB.Append('  n').Append(P).Append(' -> n').Append(AId).Append(';'#10);
        Ancestors(B.ClassDef, P);
      end
      else
      begin
        P := NodeOf('?' + B.Text, B.Text, '', '');
        SB.Append('  n').Append(P).Append(' -> n').Append(AId).Append(';'#10);
      end;
    end;
  end;

  procedure Descendants(X: TClassDef; AId, ADepth: Integer);
  var
    D: TClassDef;
    N: Integer;
  begin
    if ADepth > MaxDepth then
      Exit;
    for D in X.Derived do
      if FLinks.IsLinkable(D) and (Ids.Count < Max) then
      begin
        N := ClassNode(D, False);
        SB.Append('  n').Append(AId).Append(' -> n').Append(N).Append(';'#10);
        Descendants(D, N, ADepth + 1);
      end;
  end;

var
  Root: Integer;
begin
  Max := FConfig.GetInt('DOT_GRAPH_MAX_NODES');
  if Max <= 0 then
    Max := MaxInt;
  SB := TStringBuilder.Create;
  Ids := TDictionary<string, Integer>.Create;
  try
    SB.Append('digraph "').Append(C.Name.Replace('"', '')).Append('" {'#10 +
      '  bgcolor="transparent";'#10 +
      '  edge [fontname="Helvetica", fontsize=10, labelfontname="Helvetica", labelfontsize=10, ' +
      'dir=back, color="midnightblue", style=solid];'#10 +
      '  node [fontname="Helvetica", fontsize=10, shape=box, height=0.2, width=0.4, color="gray40", ' +
      'fillcolor="white", style=filled];'#10);
    Root := ClassNode(C, True);
    Ancestors(C, Root);
    Descendants(C, Root, 1);
    SB.Append('}'#10);
    Result := SB.ToString;
  finally
    Ids.Free;
    SB.Free;
  end;
end;

// Runs dot on the class's graph; returns the HTML block that shows the SVG, or '' when there is nothing to draw.
function THtmlGenerator.ClassGraph(C: TClassDef): string;
{$IFDEF MSWINDOWS}
var
  D: TClassDef;
  HasLink: Boolean;
  Base, Dot: string;
begin
  Result := '';
  if not FDotGraphs then
    Exit;
  HasLink := C.Bases.Count > 0;
  for D in C.Derived do
    if FLinks.IsLinkable(D) then
      HasLink := True;
  if not HasLink then
    Exit;
  Base := C.DiskName + '_inherit_graph';
  Dot := TPath.Combine(FDir, Base + '.dot');
  TFile.WriteAllText(Dot, ClassDot(C), TUTF8Encoding.Create(False)); // dot 2.x rejects a BOM
  try
    if RunTool('"' + FDotPath + 'dot" -Tsvg -o "' + TPath.Combine(FDir, Base + '.svg') + '" "' + Dot + '"', FDir) then
    begin
      Inc(FFiles);
      Result := '<div class="dynheader">'#10 + Format(Tr('Inheritance diagram for %s:'), [HtmlEscape(C.Name)]) +
        '</div>'#10'<div class="dyncontent">'#10'<div class="center"><object type="image/svg+xml" data="' + Base +
        '.svg" class="inherit_graph">' + HtmlEscape(C.Name) + '</object></div>'#10'</div>'#10;
    end;
  finally
    if FConfig.GetBool('DOT_CLEANUP') then
      TFile.Delete(Dot);
  end;
end;
{$ELSE}
begin
  Result := '';
end;
{$ENDIF}

procedure THtmlGenerator.WriteMainPage;
var
  P, Q: TPageDef;
  Title, Body: string;
begin
  P := nil;
  for Q in FProject.Pages do
    if Q.IsMainPage then
      P := Q;
  if P <> nil then
  begin
    Title := P.Title;
    Body := FDoc.Render(P.Brief + #10#10 + P.Detailed, P);
  end
  else
  begin
    Title := '';
    Body := '';
  end;
  if Title = '' then
    Title := Tr('Main Page');
  BeginPage('index', Title);
  W('<div class="header">'#10'  <div class="headertitle"><div class="title">' + HtmlEscape(Title) +
    '</div></div>'#10'</div><!--header-->'#10'<div class="contents">'#10);
  W('<div class="textblock">' + Body + '</div>'#10);
  EndPage;
end;

procedure THtmlGenerator.WriteClass(C: TClassDef);
var
  Vis: TList<TMemberDef>;
  Rows, Summary: TStringBuilder;
  B: TBaseRef;
  D, N: TClassDef;
  Text, Brief, Detail, List: string;
  HasDetail: Boolean;
begin
  Vis := VisibleMembers(C.Members);
  Rows := TStringBuilder.Create;
  Summary := TStringBuilder.Create;
  try
    Detail := DetailedBlock(C, True);
    Brief := BriefOf(C);
    // nested classes
    List := '';
    for N in C.NestedClasses do
      if FLinks.IsLinkable(N) then
        List := List + '<tr class="memitem:' + N.DiskName + '"><td class="memItemLeft" align="right" valign="top">' +
          LowerCase(Tr(ClassKindText(N))) + '&#160;</td><td class="memItemRight" valign="bottom">' + FDoc.Link(N, N.Name) +
          '</td></tr>'#10'<tr class="separator:' + N.DiskName +
          '"><td class="memSeparator" colspan="2">&#160;</td></tr>'#10;
    if List <> '' then
    begin
      Rows.Append('<tr class="heading"><td colspan="2"><h2 class="groupheader"><a id="nested-classes" name="nested-classes"></a>'#10 +
        'Classes</h2></td></tr>'#10).Append(List);
      Summary.Append('<a href="#nested-classes">Classes</a>');
    end;
    DeclSections(Vis, False, Rows, Summary);
    InheritedSections(C, Rows);
    if Detail <> '' then
    begin
      if Summary.Length > 0 then
        Summary.Append(' &#124;'#10);
      Summary.Append('<a href="#details">Detailed Description</a>');
    end;
    BeginPage(C.DiskName, ClassTitle(C), C.DiskName + '-members' + FExt);
    PageHeader(ClassTitle(C), Summary.ToString);
    HasDetail := Trim(C.Detailed) <> '';
    if Brief <> '' then
    begin
      W('<p>' + Brief);
      if HasDetail then
        W(' <a href="#details">More...</a>');
      W('</p>'#10);
    end;
    Text := '';
    for B in C.Bases do
      if Text = '' then
        Text := FDoc.LinkedText(B.Text, C)
      else
        Text := Text + ', ' + FDoc.LinkedText(B.Text, C);
    if Text <> '' then
      W('<p>' + Tr('Inherits') + ' ' + Text + '.</p>'#10);
    Text := '';
    for D in C.Derived do
      if FLinks.IsLinkable(D) then
      begin
        if Text <> '' then
          Text := Text + ', ';
        Text := Text + FDoc.Link(D, D.Name);
      end;
    if Text <> '' then
      W('<p>' + Tr('Inherited by') + ' ' + Text + '.</p>'#10);
    W(ClassGraph(C));
    W('<p><a href="' + C.DiskName + '-members' + FExt + '">List of all members</a></p>'#10);
    if Rows.Length > 0 then
      W('<table class="memberdecls">'#10 + Rows.ToString + '</table>'#10);
    W(Detail);
    W(DocSections(Vis, False));
    EndPage(NavPathOf(C));
  finally
    Summary.Free;
    Rows.Free;
    Vis.Free;
  end;
end;

procedure THtmlGenerator.WriteMembersPage(C: TClassDef);
var
  IM: TInheritedMember;
  SB: TStringBuilder;
  Row: Integer;
  Cls, Label_: string;
begin
  SB := TStringBuilder.Create;
  try
    Row := 0;
    for IM in C.AllMembers do
    begin
      if (IM.Member.Kind = memEnumValue) or not FProject.IsVisible(IM.Member) or not FLinks.IsLinkable(IM.Member) then
        Continue;
      if IM.Member.Protection in [prPrivate, prStrictPrivate] then
        if IM.From <> C then
          Continue;
      if Odd(Row) then Cls := 'odd' else Cls := 'even';
      Inc(Row);
      Label_ := '';
      if (IM.Member.Entry <> nil) and (IM.Member.Entry.Virtualness <> vtNormal) then
        Label_ := Tr('virtual');
      SB.Append('<tr class="' + Cls + '"><td class="entry">' + FDoc.Link(IM.Member, IM.Member.Name) + '</td>' +
        '<td class="entry">' + FDoc.Link(IM.From, IM.From.Name) + '</td><td class="entry">' + Label_ +
        '</td></tr>'#10);
    end;
    BeginPage(C.DiskName + '-members', Format(Tr('%s Member List'), [C.QualifiedName]), C.DiskName + '-members' + FExt);
    PageHeader(Format(Tr('%s Member List'), [C.QualifiedName]));
    W('<p>' + Tr('This is the complete list of members for') + ' ' + FDoc.Link(C, C.QualifiedName) +
      ', ' + Tr('including all inherited members.') + '</p>'#10);
    W('<table class="directory">'#10 + SB.ToString + '</table>'#10);
    EndPage(NavPathOf(C));
  finally
    SB.Free;
  end;
end;

procedure THtmlGenerator.WriteUnit(U: TUnitDef);
var
  Vis: TList<TMemberDef>;
  Rows, Summary: TStringBuilder;
  C: TClassDef;
  Detail, Brief, Uses_, S: string;
  T: TUnitDef;
  HasClasses: Boolean;
begin
  Vis := VisibleMembers(U.Members);
  Rows := TStringBuilder.Create;
  Summary := TStringBuilder.Create;
  try
    HasClasses := False;
    for C in U.Classes do
      if FLinks.IsLinkable(C) and (C.Scope = U) then
      begin
        if not HasClasses then
        begin
          Rows.Append('<tr class="heading"><td colspan="2"><h2 class="groupheader"><a id="nested-classes" name="nested-classes"></a>'#10 +
            'Classes</h2></td></tr>'#10);
          Summary.Append('<a href="#nested-classes">Classes</a>');
          HasClasses := True;
        end;
        Rows.Append('<tr class="memitem:' + C.DiskName + '"><td class="memItemLeft" align="right" valign="top">' +
          LowerCase(Tr(ClassKindText(C))) + '&#160;</td><td class="memItemRight" valign="bottom">' + FDoc.Link(C, C.Name) +
          '</td></tr>'#10);
        Brief := BriefOf(C);
        if Brief <> '' then
          Rows.Append('<tr class="memdesc:' + C.DiskName + '"><td class="mdescLeft">&#160;</td><td class="mdescRight">' +
            Brief + '<br /></td></tr>'#10);
        Rows.Append('<tr class="separator:' + C.DiskName + '"><td class="memSeparator" colspan="2">&#160;</td></tr>'#10);
      end;
    DeclSections(Vis, True, Rows, Summary);
    Detail := DetailedBlock(U, True);
    if Detail <> '' then
    begin
      if Summary.Length > 0 then
        Summary.Append(' &#124;'#10);
      Summary.Append('<a href="#details">Detailed Description</a>');
    end;
    BeginPage(U.DiskName, UnitTitle(U));
    PageHeader(UnitTitle(U), Summary.ToString);
    Brief := BriefOf(U);
    if Brief <> '' then
    begin
      W('<p>' + Brief);
      if Trim(U.Detailed) <> '' then
        W(' <a href="#details">More...</a>');
      W('</p>'#10);
    end;
    Uses_ := '';
    for S in U.UsesInterfaceNames do
    begin
      T := FProject.FindUnit(S);
      if Uses_ <> '' then
        Uses_ := Uses_ + ', ';
      if (T <> nil) and FLinks.IsLinkable(T) then
        Uses_ := Uses_ + FDoc.Link(T, S)
      else
        Uses_ := Uses_ + HtmlEscape(S);
    end;
    if Uses_ <> '' then
      W('<p>' + Tr('Uses') + ': ' + Uses_ + '</p>'#10);
    Uses_ := '';
    for T in U.UsedBy do
      if FLinks.IsLinkable(T) then
      begin
        if Uses_ <> '' then
          Uses_ := Uses_ + ', ';
        Uses_ := Uses_ + FDoc.Link(T, T.Name);
      end;
    if Uses_ <> '' then
      W('<p>' + Tr('Used by') + ': ' + Uses_ + '</p>'#10);
    if Rows.Length > 0 then
      W('<table class="memberdecls">'#10 + Rows.ToString + '</table>'#10);
    W(Detail);
    W(DocSections(Vis, True));
    EndPage(NavPathOf(U));
  finally
    Summary.Free;
    Rows.Free;
    Vis.Free;
  end;
end;

procedure THtmlGenerator.WriteGroup(G: TGroupDef);
var
  Rows, Summary: TStringBuilder;
  Mem: TList<TMemberDef>;
  D: TDefinition;
  S: TGroupDef;
  Detail, Brief: string;
  Any: Boolean;
begin
  Rows := TStringBuilder.Create;
  Summary := TStringBuilder.Create;
  Mem := TList<TMemberDef>.Create;
  try
    if G.Subgroups.Count > 0 then
    begin
      Rows.Append('<tr class="heading"><td colspan="2"><h2 class="groupheader">Topics</h2></td></tr>'#10);
      for S in G.Subgroups do
        Rows.Append('<tr class="memitem:' + S.DiskName + '"><td class="memItemLeft" align="right" valign="top">&#160;</td>' +
          '<td class="memItemRight" valign="bottom">' + FDoc.Link(S, S.Title) + '</td></tr>'#10);
    end;
    Any := False;
    for D in G.Members do
      if (D is TClassDef) or (D is TUnitDef) then
        if FLinks.IsLinkable(D) then
        begin
          if not Any then
          begin
            Rows.Append('<tr class="heading"><td colspan="2"><h2 class="groupheader">Classes and Units</h2></td></tr>'#10);
            Any := True;
          end;
          Rows.Append('<tr class="memitem:' + D.DiskName + '"><td class="memItemLeft" align="right" valign="top">&#160;</td>' +
            '<td class="memItemRight" valign="bottom">' + FDoc.Link(D, D.QualifiedName) + '</td></tr>'#10);
        end;
    for D in G.Members do
      if (D is TMemberDef) and FProject.IsVisible(D) then
        Mem.Add(TMemberDef(D));
    DeclSections(Mem, True, Rows, Summary);
    Detail := DetailedBlock(G, True);
    if Detail <> '' then
    begin
      if Summary.Length > 0 then
        Summary.Append(' &#124;'#10);
      Summary.Append('<a href="#details">Detailed Description</a>');
    end;
    BeginPage(G.DiskName, G.Title);
    PageHeader(G.Title, Summary.ToString);
    Brief := BriefOf(G);
    if Brief <> '' then
    begin
      W('<p>' + Brief);
      if Trim(G.Detailed) <> '' then
        W(' <a href="#details">More...</a>');
      W('</p>'#10);
    end;
    if Rows.Length > 0 then
      W('<table class="memberdecls">'#10 + Rows.ToString + '</table>'#10);
    W(Detail);
    W(DocSections(Mem, True));
    EndPage;
  finally
    Mem.Free;
    Summary.Free;
    Rows.Free;
  end;
end;

procedure THtmlGenerator.WritePage(P: TPageDef);
begin
  BeginPage(P.DiskName, P.Title);
  PageHeader(P.Title);
  W('<div class="textblock">' + FDoc.Render(P.Brief + #10#10 + P.Detailed, P) + '</div>'#10);
  EndPage;
end;

{ ------------------------------------------------------------------ index pages }

procedure THtmlGenerator.DirRow(var ARow: Integer; ALevel: Integer; const AIcon, ALink, ABrief: string);
var
  Cls, Indent: string;
  I: Integer;
begin
  if Odd(ARow) then Cls := 'odd' else Cls := 'even';
  Indent := '';
  for I := 0 to ALevel do
    Indent := Indent + '<span style="width:16px;display:inline-block;">&#160;</span>';
  W('<tr class="' + Cls + '"><td class="entry">' + Indent + AIcon + ALink + '</td><td class="desc">' + ABrief +
    '</td></tr>'#10);
  Inc(ARow);
end;

procedure THtmlGenerator.ClassTreeRows(C: TClassDef; ALevel: Integer; var ARow: Integer; ASB: TStringBuilder);
var
  N: TClassDef;
begin
  DirRow(ARow, ALevel, IconSpan(ClassIcon(C)), FDoc.Link(C, C.Name), BriefOf(C));
  for N in C.NestedClasses do
    if FLinks.IsLinkable(N) then
      ClassTreeRows(N, ALevel + 1, ARow, ASB);
end;

procedure THtmlGenerator.HierarchyRows(C: TClassDef; ALevel: Integer; var ARow: Integer; ASB: TStringBuilder);
var
  D: TClassDef;
begin
  DirRow(ARow, ALevel, IconSpan(ClassIcon(C)), FDoc.Link(C, C.Name), BriefOf(C));
  if ALevel > 40 then
    Exit;
  for D in C.Derived do
    if FLinks.IsLinkable(D) then
      HierarchyRows(D, ALevel + 1, ARow, ASB);
end;

procedure THtmlGenerator.GroupRows(G: TGroupDef; ALevel: Integer; var ARow: Integer; ASB: TStringBuilder);
var
  S: TGroupDef;
begin
  DirRow(ARow, ALevel, '', FDoc.Link(G, G.Title), BriefOf(G));
  if ALevel > 20 then
    Exit;
  for S in G.Subgroups do
    GroupRows(S, ALevel + 1, ARow, ASB);
end;

procedure THtmlGenerator.WriteAnnotated;
var
  U: TUnitDef;
  C: TClassDef;
  Row: Integer;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    BeginPage('annotated', Tr('Class List'));
    PageHeader(Tr('Class List'));
    W('<div class="textblock">Here are the classes, records and interfaces with brief descriptions:</div><div class="directory">'#10 +
      '<table class="directory">'#10);
    Row := 0;
    for U in FProject.Units do
      if FLinks.IsLinkable(U) then
      begin
        DirRow(Row, 0, IconSpan('N'), FDoc.Link(U, U.Name), BriefOf(U));
        for C in U.Classes do
          if FLinks.IsLinkable(C) and (C.Scope = U) then
            ClassTreeRows(C, 1, Row, SB);
      end;
    W('</table>'#10'</div><!-- directory -->'#10);
    EndPage;
  finally
    SB.Free;
  end;
end;

procedure THtmlGenerator.WriteClassIndex;
var
  Sorted: TList<TClassDef>;
  C: TClassDef;
  Letter, Cur: string;
  Row: Integer;
begin
  Sorted := TList<TClassDef>.Create;
  try
    for C in FProject.Classes do
      if FLinks.IsLinkable(C) then
        Sorted.Add(C);
    Sorted.Sort(TComparer<TClassDef>.Construct(
      function(const A, B: TClassDef): Integer
      begin
        Result := CompareText(A.Name, B.Name);
        if Result = 0 then
          Result := CompareText(A.QualifiedName, B.QualifiedName);
      end));
    BeginPage('classes', Tr('Class Index'));
    PageHeader(Tr('Class Index'));
    W('<div class="classindex">'#10);
    Cur := '';
    Row := 0;
    for C in Sorted do
    begin
      Letter := UpperCase(Copy(C.Name, 1, 1));
      if Letter <> Cur then
      begin
        if Cur <> '' then
          W('</dl>'#10);
        if Odd(Row) then W('<dl class="odd">') else W('<dl class="even">');
        Inc(Row);
        W('<dt class="alphachar"><a id="letter_' + Letter + '" name="letter_' + Letter + '">' + HtmlEscape(Letter) +
          '</a></dt>'#10);
        Cur := Letter;
      end;
      W('<dd>' + FDoc.Link(C, C.Name));
      if (C.Scope <> nil) and (C.Scope.Name <> '') then
        W(' (' + FDoc.Link(C.Scope, C.Scope.QualifiedName) + ')');
      W('</dd>'#10);
    end;
    if Cur <> '' then
      W('</dl>'#10);
    W('</div><!-- classindex -->'#10);
    EndPage;
  finally
    Sorted.Free;
  end;
end;

procedure THtmlGenerator.WriteHierarchy;
var
  C: TClassDef;
  B: TBaseRef;
  Root: Boolean;
  Row: Integer;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    BeginPage('hierarchy', Tr('Class Hierarchy'));
    PageHeader(Tr('Class Hierarchy'));
    W('<div class="textblock">This inheritance list is sorted roughly, but not completely, alphabetically:</div>'#10 +
      '<div class="directory">'#10'<table class="directory">'#10);
    Row := 0;
    for C in FProject.Classes do
      if FLinks.IsLinkable(C) then
      begin
        Root := True;
        for B in C.Bases do
          if (B.ClassDef <> nil) and FLinks.IsLinkable(B.ClassDef) then
            Root := False;
        if Root then
          HierarchyRows(C, 0, Row, SB);
      end;
    W('</table>'#10'</div><!-- directory -->'#10);
    EndPage;
  finally
    SB.Free;
  end;
end;

procedure THtmlGenerator.WriteUnitList;
var
  U: TUnitDef;
  Row: Integer;
begin
  BeginPage('namespaces', Tr('Unit List'));
  PageHeader(Tr('Unit List'));
  W('<div class="textblock">Here is a list of all documented units with brief descriptions:</div>'#10 +
    '<div class="directory">'#10'<table class="directory">'#10);
  Row := 0;
  for U in FProject.Units do
    if FLinks.IsLinkable(U) then
      DirRow(Row, 0, IconSpan('N'), FDoc.Link(U, U.Name), BriefOf(U));
  W('</table>'#10'</div><!-- directory -->'#10);
  EndPage;
end;

procedure THtmlGenerator.WriteTopics;
var
  G: TGroupDef;
  Row: Integer;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    BeginPage('topics', Tr('Topics'));
    PageHeader(Tr('Topics'));
    W('<div class="textblock">Here is a list of all topics with brief descriptions:</div>'#10 +
      '<div class="directory">'#10'<table class="directory">'#10);
    Row := 0;
    for G in FProject.Groups do
      if G.Parent = nil then
        GroupRows(G, 0, Row, SB);
    W('</table>'#10'</div><!-- directory -->'#10);
    EndPage;
  finally
    SB.Free;
  end;
end;

procedure THtmlGenerator.WritePagesIndex;
var
  P: TPageDef;
  Row: Integer;
begin
  BeginPage('pages', Tr('Related Pages'));
  PageHeader(Tr('Related Pages'));
  W('<div class="textblock">Here is a list of all related documentation pages:</div>'#10 +
    '<div class="directory">'#10'<table class="directory">'#10);
  Row := 0;
  for P in FProject.Pages do
    if not P.IsMainPage then
      DirRow(Row, 0, '', FDoc.Link(P, P.Title), BriefOf(P));
  W('</table>'#10'</div><!-- directory -->'#10);
  EndPage;
end;

procedure THtmlGenerator.WriteFunctionsIndex;
var
  Items: TList<TMemberDef>;
  M: TMemberDef;
  C: TClassDef;
  Letter, Cur: string;
  Letters: TStringList;
  S: string;
begin
  Items := TList<TMemberDef>.Create;
  Letters := TStringList.Create;
  try
    for C in FProject.Classes do
      if FLinks.IsLinkable(C) then
        for M in C.Members do
          if FProject.IsVisible(M) and FLinks.IsLinkable(M) then
            Items.Add(M);
    Items.Sort(TComparer<TMemberDef>.Construct(
      function(const A, B: TMemberDef): Integer
      begin
        Result := CompareText(A.Name, B.Name);
        if Result = 0 then
          Result := CompareText(A.Scope.Name, B.Scope.Name);
      end));
    for M in Items do
    begin
      Letter := UpperCase(Copy(M.Name, 1, 1));
      if Letters.IndexOf(Letter) < 0 then
        Letters.Add(Letter);
    end;
    BeginPage('functions', Tr('Class Members'));
    PageHeader(Tr('Class Members'));
    W('<div class="textblock">Here is a list of all documented class members with links to the class documentation for each member:</div>'#10);
    S := '';
    for Letter in Letters do
      S := S + '<a class="qindex" href="#index_' + LowerCase(Letter) + '">' + HtmlEscape(Letter) + '</a>&#160;';
    W('<div class="qindex">' + S + '</div>'#10'<ul>'#10);
    Cur := '';
    for M in Items do
    begin
      Letter := UpperCase(Copy(M.Name, 1, 1));
      if Letter <> Cur then
      begin
        Cur := Letter;
        W('<a id="index_' + LowerCase(Letter) + '" name="index_' + LowerCase(Letter) + '"></a><h3 class="doxsection">' +
          HtmlEscape(Letter) + '</h3>'#10);
      end;
      W('<li>' + HtmlEscape(M.Name));
      if M.Kind = memFunction then
        W('()');
      W('&#160;:&#160;' + FDoc.Link(M.Scope, M.Scope.QualifiedName).Replace('class="el"', 'class="el"') + '</li>'#10);
    end;
    W('</ul>'#10);
    EndPage;
  finally
    Letters.Free;
    Items.Free;
  end;
end;

{ ------------------------------------------------------------------ static files }

procedure THtmlGenerator.WriteStatic;
var
  Css, Dest, S: string;
begin
  // style sheet
  if FStyleSheet = '' then
    SaveText('doxygen.css', BuildStyleSheet(FColors, FLight, FDark, HtmlResourceText('doxygen.css'),
      HtmlResourceText('scrollbar.css'), DoxyPasVersion, FSidebar, Length(FExtraCss) = 0))
  else if TFile.Exists(FStyleSheet) then
    SaveText(ExtractFileName(FStyleSheet), TFile.ReadAllText(FStyleSheet, TEncoding.UTF8))
  else
    SaveText('doxygen.css', BuildStyleSheet(FColors, FLight, FDark, HtmlResourceText('doxygen.css'),
      HtmlResourceText('scrollbar.css'), DoxyPasVersion, FSidebar, Length(FExtraCss) = 0));
  for S in FExtraCss do
    if (S <> '') and TFile.Exists(S) then
    begin
      TFile.Copy(S, TPath.Combine(FDir, ExtractFileName(S)), True);
      Inc(FFiles);
    end;
  for S in [FProjectLogo, FProjectIcon] do
    if (S <> '') and TFile.Exists(S) then
    begin
      TFile.Copy(S, TPath.Combine(FDir, ExtractFileName(S)), True);
      Inc(FFiles);
    end;
  SaveText('tabs.css', ApplyColorStyle(HtmlResourceText('tabs.css'), FColors, FLight, FDark));
  SaveText('navtree.css', ApplyColorStyle(HtmlResourceText('navtree.css'), FColors, FLight, FDark));
  if not FNoIndex then
    SaveText('menu.js', HtmlResourceText('menu.js'));
  if FClip then
    SaveText('clipboard.js', HtmlResourceText('clipboard.js').Replace('$copy_to_clipboard_text', Tr('Copy to clipboard')));
  if FTree or FSearch or (FColors.Style = csToggle) then
    SaveText('cookie.js', HtmlResourceText('cookie.js'));
  if FColors.Style = csToggle then
    SaveText('darkmode_toggle.js', ReplaceColorMarkers(HtmlResourceText('darkmode_toggle.js'), FColors)
      .Replace('$PROJECTID', FProjectId));
  if FDynSec then
    SaveText('dynsections.js', ApplyColorStyle(HtmlResourceText('dynsections.js'), FColors, FLight, FDark));
  if FFold then
    SaveText('codefolding.js', ApplyColorStyle(HtmlResourceText('codefolding.js'), FColors, FLight, FDark));
  if FTree then
    SaveText('navtree.js', HtmlResourceText('navtree.js').Replace('$TREEVIEW_WIDTH',
      FConfig.GetInt('TREEVIEW_WIDTH').ToString).Replace('$PROJECTID', FProjectId));
  if FSearch then
  begin
    if FSidebar then Css := HtmlResourceText('search_sidebar.css')
    else if FNoIndex then
    begin
      if FColors.Style = csToggle then Css := HtmlResourceText('search_nomenu_toggle.css')
      else Css := HtmlResourceText('search_nomenu.css');
    end
    else Css := HtmlResourceText('search.css');
    Css := Css + HtmlResourceText('search_common.css');
    Dest := Css.Replace('$doxygenversion', DoxyPasVersion);
    SaveText('search/search.css', ApplyColorStyle(Dest, FColors, FLight, FDark));
    SaveText('search/search.js', HtmlResourceText('search.js').Replace('$PROJECTID', FProjectId));
  end;
end;

procedure THtmlGenerator.WriteMenuData;
var
  SB: TStringBuilder;
  First: Boolean;

  procedure Item(const AText, AUrl: string; AOpen: Boolean);
  begin
    if not First then
      SB.Append(','#10);
    First := False;
    SB.Append('{text:"' + JsString(AText) + '",url:"' + JsString(AUrl) + '"');
    if not AOpen then
      SB.Append('}');
  end;

begin
  if FNoIndex then
    Exit;
  SB := TStringBuilder.Create;
  try
    SB.Append(LicenseText).Append('var menudata={children:['#10);
    First := True;
    Item(Tr('Main Page'), 'index' + FExt, False);
    if FHasPages then
      Item(Tr('Related Pages'), 'pages' + FExt, False);
    if FHasGroups then
      Item(Tr('Topics'), 'topics' + FExt, False);
    if FHasUnits then
    begin
      Item(Tr('Units'), 'namespaces' + FExt, True);
      SB.Append(',children:['#10);
      First := True;
      Item(Tr('Unit List'), 'namespaces' + FExt, False);
      SB.Append(']}');
      First := False;
    end;
    if FHasClasses then
    begin
      Item(Tr('Classes'), 'annotated' + FExt, True);
      SB.Append(',children:['#10);
      First := True;
      Item(Tr('Class List'), 'annotated' + FExt, False);
      Item(Tr('Class Index'), 'classes' + FExt, False);
      Item(Tr('Class Hierarchy'), 'hierarchy' + FExt, False);
      Item(Tr('Class Members'), 'functions' + FExt, False);
      SB.Append(']}');
    end;
    SB.Append(']}'#10);
    SaveText('menudata.js', SB.ToString);
  finally
    SB.Free;
  end;
end;

{ ------------------------------------------------------------------ navigation tree }

procedure THtmlGenerator.BuildNav;
var
  P: TPageDef;
  G: TGroupDef;
  U: TUnitDef;
  C: TClassDef;
  Topics, Units, Classes, List, Node: TNavNode;

  procedure AddGroup(AParent: TNavNode; AGroup: TGroupDef);
  var
    N: TNavNode;
    S: TGroupDef;
  begin
    N := AParent.Add(AGroup.Title, Url(AGroup.DiskName));
    for S in AGroup.Subgroups do
      AddGroup(N, S);
  end;

  procedure AddClass(AParent: TNavNode; AClass: TClassDef);
  var
    N: TNavNode;
    K: TClassDef;
  begin
    N := AParent.Add(AClass.Name, Url(AClass.DiskName));
    for K in AClass.NestedClasses do
      if FLinks.IsLinkable(K) then
        AddClass(N, K);
  end;

begin
  for P in FProject.Pages do
    if not P.IsMainPage then
      FNav.Add(TNavNode.Create(P.Title, Url(P.DiskName)));
  if FHasGroups then
  begin
    Topics := TNavNode.Create(Tr('Topics'), Url('topics'));
    FNav.Add(Topics);
    for G in FProject.Groups do
      if G.Parent = nil then
        AddGroup(Topics, G);
  end;
  if FHasUnits then
  begin
    Units := TNavNode.Create(Tr('Units'), Url('namespaces'));
    FNav.Add(Units);
    for U in FProject.Units do
      if FLinks.IsLinkable(U) then
        Units.Add(U.Name, Url(U.DiskName));
  end;
  if FHasClasses then
  begin
    Classes := TNavNode.Create(Tr('Classes'), Url('annotated'));
    FNav.Add(Classes);
    List := Classes.Add('Class List', Url('annotated'));
    for U in FProject.Units do
      if FLinks.IsLinkable(U) then
      begin
        Node := nil;
        for C in U.Classes do
          if FLinks.IsLinkable(C) and (C.Scope = U) then
          begin
            if Node = nil then
              Node := List.Add(U.Name, '');
            AddClass(Node, C);
          end;
      end;
    Classes.Add('Class Index', Url('classes'));
    Classes.Add('Class Hierarchy', Url('hierarchy'));
    Classes.Add('Class Members', Url('functions'));
  end;
end;

// one node per line as in Doxygen's navtreedata.js; the children are written inline
function THtmlGenerator.NavJs(ANodes: TObjectList<TNavNode>; ALevel: Integer; const APath: string;
  var AFirst: Boolean): Boolean;
var
  Indent, Link: string;
  Idx: Integer;
  N: TNavNode;
  FirstChild, Empty: Boolean;
begin
  Result := False;
  Indent := StringOfChar(' ', ALevel * 2);
  Idx := 0;
  for N in ANodes do
  begin
    if not AFirst then
      W(','#10);
    AFirst := False;
    if not Result then
      W('[' + #10);
    Result := True;
    if N.Url = '' then
      Link := '"' + JsString(N.Name) + '", null, '
    else
      Link := '"' + JsString(N.Name) + '", "' + JsString(N.Url) + '", ';
    W(Indent + '  [ ' + Link);
    FirstChild := True;
    Empty := not NavJs(N.Kids, ALevel + 1, APath, FirstChild);
    if Empty then
      W('null ]')
    else
      W(#10 + Indent + '  ] ]');
    Inc(Idx);
  end;
end;

procedure THtmlGenerator.RegisterNav(ANodes: TObjectList<TNavNode>; const APath: string);
var
  I: Integer;
  P: string;
  N: TNavNode;
  Pair: TPair<string, string>;
  Known: Boolean;
begin
  for I := 0 to ANodes.Count - 1 do
  begin
    N := ANodes[I];
    if APath = '' then P := I.ToString else P := APath + ',' + I.ToString;
    if N.Url <> '' then
    begin
      Known := False;
      for Pair in FNavIndex do
        if Pair.Key = N.Url then
          Known := True;
      if not Known then
        FNavIndex.Add(TPair<string, string>.Create(N.Url, P));
    end;
    RegisterNav(N.Kids, P);
  end;
end;

procedure THtmlGenerator.WriteNavTree;
const
  MaxElems = 250;
var
  Saved: TStringBuilder;
  First: Boolean;
  Idx, Sub, Count: Integer;
  Index: TStringBuilder;
  Heads: TStringBuilder;
  E: TPair<string, string>;
  Entries: TArray<TPair<string, string>>;
begin
  if not FTree then
    Exit;
  if FNav.Count = 0 then
    BuildNav;
  FNavIndex.Clear;
  FNavIndex.Add(TPair<string, string>.Create('index' + FExt, ''));
  if FHasPages then
    FNavIndex.Add(TPair<string, string>.Create('pages' + FExt, ''));
  RegisterNav(FNav, '');
  Saved := FPage;
  FPage := TStringBuilder.Create;
  try
    W(LicenseText + 'var NAVTREE =' + #10 + '[' + #10 + '  [ ');
    if FProjectName <> '' then
      W('"' + JsString(FProjectName) + '", ')
    else
      W('"Main Page", ');
    W('"index' + FExt + '", ');
    First := True;
    NavJs(FNav, 1, '', First);
    if First then
      W(']'#10)
    else
      W(#10'  ] ]'#10);
    W('];'#10#10);
    // the quick navigation index: url -> path in the tree, in files of MaxElems entries
    Entries := FNavIndex.ToArray;
    TArray.Sort<TPair<string, string>>(Entries, TComparer<TPair<string, string>>.Construct(
      function(const A, B: TPair<string, string>): Integer
      begin
        Result := string.CompareOrdinal(A.Key, B.Key);
      end));
    Heads := TStringBuilder.Create;
    Index := TStringBuilder.Create;
    try
      Sub := 0;
      Count := 0;
      Heads.Append('var NAVTREEINDEX ='#10'['#10);
      Index.Append('var NAVTREEINDEX0 ='#10'{'#10);
      Idx := 0;
      for E in Entries do
      begin
        if Count = 0 then
        begin
          if Heads.Length > Length('var NAVTREEINDEX ='#10'['#10) then
            Heads.Append(','#10);
          Heads.Append('"' + E.Key + '"');
        end;
        Index.Append('"' + E.Key + '":[' + E.Value + ']');
        Inc(Idx);
        Inc(Count);
        if (Idx < Length(Entries)) and (Count < MaxElems) then
          Index.Append(',');
        Index.Append(#10);
        if (Idx < Length(Entries)) and (Count >= MaxElems) then
        begin
          Index.Append('};'#10);
          SaveText('navtreeindex' + Sub.ToString + '.js', Index.ToString);
          Index.Clear;
          Count := 0;
          Inc(Sub);
          Index.Append('var NAVTREEINDEX' + Sub.ToString + ' ='#10'{'#10);
        end;
      end;
      Index.Append('};'#10);
      SaveText('navtreeindex' + Sub.ToString + '.js', Index.ToString);
      Heads.Append(#10'];'#10);
      W(Heads.ToString);
    finally
      Index.Free;
      Heads.Free;
    end;
    W(#10'const SYNCONMSG = ''' + JsString(Tr('click to disable panel synchronisation')) + ''';');
    W(#10'const SYNCOFFMSG = ''' + JsString(Tr('click to enable panel synchronisation')) + ''';');
    W(#10'const LISTOFALLMEMBERS = ''' + JsString(Tr('List of all members')) + ''';');
    SaveText('navtreedata.js', FPage.ToString);
  finally
    FPage.Free;
    FPage := Saved;
  end;
end;

{ ------------------------------------------------------------------ HTML Help (CHM) }

function HelpEscape(const S: string): string;
begin
  Result := S.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;');
end;

procedure THtmlGenerator.WriteHtmlHelp;
const
  Head = '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">'#10'<HTML>'#10'<HEAD>'#10 +
    '<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">'#10 +
    '<meta name="GENERATOR" content="DoxyPas">'#10'<!-- Sitemap 1.0 -->'#10'</HEAD><BODY>'#10;
var
  Toc, Idx, Hhp: TStringBuilder;
  Chm, Title, F, Rel, Hhc: string;
  Files: TStringList;
  Entries: TList<TPair<string, string>>;
  Pair: TPair<string, string>;
  C: TClassDef;
  U: TUnitDef;
  M: TMemberDef;

  procedure Item(ASB: TStringBuilder; const AName, AUrl: string);
  begin
    ASB.Append('<LI><OBJECT type="text/sitemap"><param name="Name" value="' + HelpEscape(AName) + '">');
    if AUrl <> '' then
      ASB.Append('<param name="Local" value="' + AUrl + '">');
    ASB.Append('</OBJECT>'#10);
  end;

  procedure Nodes(ANodes: TObjectList<TNavNode>);
  var
    N: TNavNode;
  begin
    if ANodes.Count = 0 then
      Exit;
    Toc.Append('<UL>'#10);
    for N in ANodes do
    begin
      Item(Toc, N.Name, N.Url);
      Nodes(N.Kids);
    end;
    Toc.Append('</UL>'#10);
  end;

begin
  if FNav.Count = 0 then
    BuildNav;
  Title := FProjectName;
  if Title = '' then
    Title := 'Documentation';
  Chm := FConfig.GetString('CHM_FILE');
  if Chm = '' then
    Chm := 'index.chm';
  Toc := TStringBuilder.Create;
  Idx := TStringBuilder.Create;
  Hhp := TStringBuilder.Create;
  Files := TStringList.Create;
  Entries := TList<TPair<string, string>>.Create;
  try
    Toc.Append(Head).Append('<OBJECT type="text/site properties"><param name="FrameName" value="right"></OBJECT>'#10);
    Toc.Append('<UL>'#10);
    Item(Toc, Tr('Main Page'), 'index' + FExt);
    Nodes(FNav);
    Toc.Append('</UL>'#10'</BODY></HTML>'#10);
    for C in FProject.Classes do
      if FLinks.IsLinkable(C) then
      begin
        Entries.Add(TPair<string, string>.Create(C.Name, FDoc.DefUrl(C)));
        for M in C.Members do
          if FProject.IsVisible(M) and FLinks.IsLinkable(M) then
            Entries.Add(TPair<string, string>.Create(M.Name + ' (' + C.Name + ')', FDoc.DefUrl(M)));
      end;
    for U in FProject.Units do
      if FLinks.IsLinkable(U) then
      begin
        Entries.Add(TPair<string, string>.Create(U.Name, FDoc.DefUrl(U)));
        for M in U.Members do
          if FProject.IsVisible(M) and FLinks.IsLinkable(M) then
            Entries.Add(TPair<string, string>.Create(M.Name + ' (' + U.Name + ')', FDoc.DefUrl(M)));
      end;
    Entries.Sort(TComparer<TPair<string, string>>.Construct(
      function(const A, B: TPair<string, string>): Integer
      begin
        Result := CompareText(A.Key, B.Key);
      end));
    Idx.Append(Head).Append('<UL>'#10);
    for Pair in Entries do
      Item(Idx, Pair.Key, Pair.Value);
    Idx.Append('</UL>'#10'</BODY></HTML>'#10);
    SaveText('index.hhc', Toc.ToString);
    SaveText('index.hhk', Idx.ToString);
    // every file of the output except the search data (it needs scripts that a CHM cannot run) and the help files
    for F in TDirectory.GetFiles(FDir, '*', TSearchOption.soAllDirectories) do
    begin
      Rel := ExtractRelativePath(IncludeTrailingPathDelimiter(FDir), F).Replace('\', '/');
      if Rel.StartsWith('search/') or SameText(ExtractFileExt(F), '.hhp') or SameText(ExtractFileExt(F), '.chm') then
        Continue;
      Files.Add(Rel);
    end;
    Hhp.Append('[OPTIONS]'#10'Compatibility=1.1'#10'Compiled file=' + Chm + #10'Contents file=index.hhc'#10 +
      'Default Window=main'#10'Default topic=index' + FExt + #10'Display compile progress=No'#10 +
      'Full-text search=Yes'#10'Index file=index.hhk'#10'Language=0x409 English (United States)'#10 +
      'Title=' + Title + #10#10'[WINDOWS]'#10'main="' + Title + '","index.hhc","index.hhk","index' + FExt +
      '","index' + FExt + '",,,,,0x23520,,0x387e,,,,,,,,0'#10#10'[FILES]'#10);
    for F in Files do
      Hhp.Append(F).Append(#10);
    Hhp.Append(#10'[INFOTYPES]'#10);
    SaveText('index.hhp', Hhp.ToString);
{$IFDEF MSWINDOWS}
    Hhc := FConfig.GetString('HHC_LOCATION');
    if (Hhc <> '') and TFile.Exists(Hhc) then
      RunHhc(Hhc, FDir);
{$ELSE}
    Hhc := FConfig.GetString('HHC_LOCATION');
    if Hhc <> '' then
      Writeln(ErrOutput, 'warning: the CHM compiler (hhc) runs on Windows only; compile index.hhp there');
{$ENDIF}
  finally
    Entries.Free;
    Files.Free;
    Hhp.Free;
    Idx.Free;
    Toc.Free;
  end;
end;

{ ------------------------------------------------------------------ search data }

function CompareLetters(List: TStringList; A, B: Integer): Integer;
begin
  Result := string.CompareOrdinal(List[A], List[B]);
end;

function SearchLetter(const AWord: string): string;
begin
  Result := LowerCase(Copy(AWord, 1, 1));
end;

function TermId(const AWord: string): string;
var
  C: Char;
begin
  Result := '';
  for C in AWord do
    if (Ord(C) > 127) or CharInSet(C, ['0'..'9', 'a'..'z', 'A'..'Z']) then
      Result := Result + C
    else
      Result := Result + '_' + IntToHex(Ord(C), 2);
  Result := LowerCase(Result);
end;

procedure THtmlGenerator.AddTerm(ACategory: Integer; const AWord, ATitle, AUrl, AScope, ANamed: string);
var
  T: TSearchTerm;
begin
  T.Word := AWord;
  T.Title := ATitle;
  T.Url := AUrl;
  T.Scope := AScope;
  T.Named := ANamed;
  FSearchTerms[CAll].Add(T);
  if ACategory <> CAll then
    FSearchTerms[ACategory].Add(T);
end;

procedure THtmlGenerator.CollectSearch;

  procedure AddTitle(ACategory: Integer; const ATitle, AUrl: string);
  var
    I: Integer;
    InWord: Boolean;
    Plain: string;
  begin
    Plain := ATitle;
    InWord := False;
    for I := 1 to Length(Plain) do
      if CharInSet(Plain[I], ['0'..'9', 'a'..'z', 'A'..'Z', '_']) or (Ord(Plain[I]) > 127) then
      begin
        if not InWord then
          AddTerm(ACategory, Copy(Plain, I, MaxInt), Plain, AUrl, '', Plain);
        InWord := True;
      end
      else
        InWord := False;
  end;

  procedure AddMember(M: TMemberDef);
  var
    Cat: Integer;
    ScopeName, Named: string;
  begin
    case M.Kind of
      memFunction: Cat := CFunctions;
      memVariable, memConstant: Cat := CVariables;
      memTypedef: Cat := CTypedefs;
      memEnumeration: Cat := CEnums;
      memEnumValue: Cat := CEnumValues;
      memProperty: Cat := CProperties;
    else
      Exit;
    end;
    if M.Scope <> nil then
      ScopeName := M.Scope.QualifiedName
    else
      ScopeName := '';
    Named := M.Name;
    if M.Kind = memFunction then
      Named := Named + '()';
    if ScopeName <> '' then
      Named := ScopeName + '.' + Named;
    AddTerm(Cat, M.Name, M.Name, FDoc.DefUrl(M), ScopeName, Named);
  end;

var
  C: TClassDef;
  U: TUnitDef;
  G: TGroupDef;
  P: TPageDef;
  M, V: TMemberDef;
begin
  for C in FProject.Classes do
    if FLinks.IsLinkable(C) then
    begin
      if C.Scope <> nil then
        AddTerm(CClasses, C.Name, C.Name, FDoc.DefUrl(C), C.Scope.QualifiedName, C.QualifiedName)
      else
        AddTerm(CClasses, C.Name, C.Name, FDoc.DefUrl(C), '', C.QualifiedName);
    end;
  for U in FProject.Units do
    if FLinks.IsLinkable(U) then
      AddTerm(CUnits, U.Name, U.Name, FDoc.DefUrl(U), '', U.Name);
  for M in FProject.Members do
    if FProject.IsVisible(M) and FLinks.IsLinkable(M) and (M.Scope <> nil) and
      ((M.Scope is TUnitDef) or FLinks.IsLinkable(M.Scope)) then
    begin
      AddMember(M);
      for V in M.EnumValues do
        if FLinks.IsLinkable(V) then
          AddMember(V);
    end;
  for G in FProject.Groups do
    AddTitle(CGroups, G.Title, FDoc.DefUrl(G));
  for P in FProject.Pages do
    if P.IsMainPage then
      AddTitle(CPages, P.Title, FDoc.DefUrl(P))
    else
      AddTitle(CPages, P.Title, FDoc.DefUrl(P));
end;

procedure THtmlGenerator.WriteSearchData;
var
  Cat, J, P, I, K, Cnt: Integer;
  List: TList<TSearchTerm>;
  Letters: TStringList;
  Per: TDictionary<string, TList<TSearchTerm>>;
  Sections, Names, Labels, Page: TStringBuilder;
  Term: TSearchTerm;
  Key, Last, Unique, Show: string;
  Pair: TPair<string, TList<TSearchTerm>>;
  Group: TList<TSearchTerm>;
  Hex: string;
begin
  if not FSearch then
    Exit;
  CollectSearch;
  Sections := TStringBuilder.Create;
  Names := TStringBuilder.Create;
  Labels := TStringBuilder.Create;
  try
    J := 0;
    for Cat := 0 to High(SearchNames) do
    begin
      List := FSearchTerms[Cat];
      if List.Count = 0 then
        Continue;
      List.Sort(TComparer<TSearchTerm>.Construct(
        function(const A, B: TSearchTerm): Integer
        begin
          Result := CompareText(A.Word, B.Word);
          if Result = 0 then
            Result := CompareText(A.Title, B.Title);
          if Result = 0 then
            Result := CompareText(A.Named, B.Named);
        end));
      Per := TDictionary<string, TList<TSearchTerm>>.Create;
      Letters := TStringList.Create;
      try
        for Term in List do
        begin
          Key := SearchLetter(Term.Word);
          if not Per.TryGetValue(Key, Group) then
          begin
            Group := TList<TSearchTerm>.Create;
            Per.Add(Key, Group);
            Letters.Add(Key);
          end;
          Group.Add(Term);
        end;
        Letters.CustomSort(CompareLetters);
        if J > 0 then
        begin
          Sections.Append(','#10);
          Names.Append(','#10);
          Labels.Append(','#10);
        end;
        Sections.Append('  ' + J.ToString + ': "');
        for K := 0 to Letters.Count - 1 do
        begin
          if Letters[K] = '"' then
            Sections.Append('\');
          Sections.Append(Letters[K]);
        end;
        Sections.Append('"');
        Names.Append('  ' + J.ToString + ': "' + SearchNames[Cat] + '"');
        Labels.Append('  ' + J.ToString + ': "' + JsString(Tr(SearchLabels[Cat])) + '"');
        Inc(J);
        // one file per first letter
        for P := 0 to Letters.Count - 1 do
        begin
          Group := Per[Letters[P]];
          Page := TStringBuilder.Create;
          try
            Page.Append('var searchData='#10'['#10);
            Cnt := 0;
            Last := '';
            I := 0;
            while I < Group.Count do
            begin
              // the run of terms with the same word
              K := I;
              while (K + 1 < Group.Count) and SameText(Group[K + 1].Word, Group[I].Word) do
                Inc(K);
              if I > 0 then
                Page.Append(','#10);
              Page.Append('  [''' + TermId(Group[I].Word) + '_' + Cnt.ToString + ''',[''');
              Inc(Cnt);
              if K = I then
                Show := Group[I].Title
              else
                Show := Group[I].Word;
              Page.Append(JsString(HtmlEscape(Show)) + ''',[');
              Term := Group[I];
              while True do
              begin
                Page.Append('''' + JsString(Term.Url) + ''',1,');
                if K = I then
                  Unique := Term.Scope
                else
                  Unique := Term.Named;
                Page.Append('''' + JsString(HtmlEscape(Unique)) + '''');
                Inc(I);
                if I > K then
                  Break;
                Page.Append('],[');
                Term := Group[I];
              end;
              Page.Append(']]]');
            end;
            Page.Append(#10'];'#10);
            Hex := LowerCase(IntToHex(P, 1));
            SaveText('search/' + SearchNames[Cat] + '_' + Hex + '.js', Page.ToString);
          finally
            Page.Free;
          end;
        end;
      finally
        for Pair in Per do
          Pair.Value.Free;
        Per.Free;
        Letters.Free;
      end;
    end;
    SaveText('search/searchdata.js', 'var indexSectionsWithContent ='#10'{'#10 + Sections.ToString + #10'};'#10#10 +
      'var indexSectionNames ='#10'{'#10 + Names.ToString + #10'};'#10#10 +
      'var indexSectionLabels ='#10'{'#10 + Labels.ToString + #10'};'#10#10);
  finally
    Labels.Free;
    Names.Free;
    Sections.Free;
  end;
end;

{ ------------------------------------------------------------------ driver }

function THtmlGenerator.Run: Integer;
var
  C: TClassDef;
  U: TUnitDef;
  G: TGroupDef;
  P: TPageDef;
begin
  TDirectory.CreateDirectory(FDir);
  for C in FProject.Classes do
    if FLinks.IsLinkable(C) then
      FHasClasses := True;
  for U in FProject.Units do
    if FLinks.IsLinkable(U) then
      FHasUnits := True;
  FHasGroups := FProject.Groups.Count > 0;
  for P in FProject.Pages do
    if not P.IsMainPage then
      FHasPages := True;
  WriteStatic;
  WriteMainPage;
  for C in FProject.Classes do
    if FLinks.IsLinkable(C) then
    begin
      WriteClass(C);
      WriteMembersPage(C);
    end;
  for U in FProject.Units do
    if FLinks.IsLinkable(U) then
      WriteUnit(U);
  for G in FProject.Groups do
    WriteGroup(G);
  for P in FProject.Pages do
    if not P.IsMainPage then
      WritePage(P);
  if FHasPages then
    WritePagesIndex;
  if FHasGroups then
    WriteTopics;
  if FHasUnits then
    WriteUnitList;
  if FHasClasses then
  begin
    WriteAnnotated;
    WriteClassIndex;
    WriteHierarchy;
    WriteFunctionsIndex;
  end;
  WriteMenuData;
  WriteNavTree;
  WriteSearchData;
  if FConfig.GetBool('GENERATE_HTMLHELP') then
    WriteHtmlHelp;
  Result := FFiles;
end;

function GenerateHtml(AProject: TProject; AConfig: TConfig; const AOutDir: string): Integer;
var
  G: THtmlGenerator;
begin
  G := THtmlGenerator.Create(AProject, AConfig, AOutDir);
  try
    Result := G.Run;
  finally
    G.Free;
  end;
end;

end.
