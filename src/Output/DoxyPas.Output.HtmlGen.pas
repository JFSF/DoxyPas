unit DoxyPas.Output.HtmlGen;

{ HTML output (Doxygen's htmlgen + index + ftvhelp + searchindex_js): one page per class, unit, group and page, the
  index pages, the menu / navigation tree / search data and the style sheets and scripts of Doxygen's own templates.
  Units are the "namespaces" of the output. Not (yet) supported: call graphs, LaTeX formulas, server
  based search, static tabs (HTML_DYNAMIC_MENUS = NO), LAYOUT_FILE. }

interface

uses
  DoxyPas.Config,
  DoxyPas.Model.Project;

/// <summary>Writes the HTML files into AOutDir (created if needed). Returns the number of files written.</summary>
function GenerateHtml(AProject: TProject; AConfig: TConfig; const AOutDir: string): Integer;

implementation

uses
  System.Character,
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
{$IFDEF POSIX}
  Posix.Stdlib,
{$ENDIF}
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Hash,
  System.Math,
  System.RegularExpressions,
  System.Generics.Collections,
  System.Generics.Defaults,
  DoxyPas.Core.Version,
  DoxyPas.Core.Log,
  DoxyPas.Core.Timing,
  DoxyPas.Model.Entry,
  DoxyPas.Model.Defs,
  DoxyPas.Model.Links,
  DoxyPas.Model.Calls,
  DoxyPas.Model.Dirs,
  DoxyPas.Config.Layout,
  DoxyPas.Output.DotGraphs,
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
    FTree, FSearch, FNoIndex, FDynMenus, FSidebar, FFold, FDynSec, FClip: Boolean;
    FLayout: TLayout;         // LAYOUT_FILE
    FAlphabeticalIndex: Boolean;   // ALPHABETICAL_INDEX: the class index
    FIgnorePrefix: TArray<string>; // IGNORE_PREFIX
    FBriefMemberDesc, FRepeatBrief, FInlineInfo, FShowEnumValues: Boolean;
    FCtorsFirst, FSortByScope, FShowUsedFiles: Boolean;
    FTimestamp: string;            // TIMESTAMP: NO, YES / DATETIME or DATE
    FMaxInitLines, FEnumPerLine: Integer;
    FPageLayout: string;      // the layout page the member tables follow when it is not the one of the kind of definition ('group')
    FTabs: TDictionary<string, TLayoutEntry>;   // type of tab -> its <tab> element
    FMenu: TNavNode;          // the tabs, for HTML_DYNAMIC_MENUS = NO
    FPageMenu: TDictionary<string, TPair<string, string>>;   // page -> the URL bases of its tab and sub-tab
    FSortDocs, FSortBrief: Boolean;
    FProjectName, FProjectNumber, FProjectBrief, FProjectLogo, FProjectIcon, FStyleSheet: string;
    FExtraCss: TArray<string>;
    FHeader, FFooter: string;
    FProjectId: string;
    FPage: TStringBuilder;
    FPageFile, FPageTitle: string;
    FHasPages, FHasGroups, FHasClasses, FHasUnits: Boolean;
    FDotGraphs: Boolean;      // HAVE_DOT: draw the graphs (Windows only for now)
    FDot: TDotGraphs;
    FRunner: TDotRunner;
    FDirs: TDirTree;          // SHOW_FILES: the directories of the unit files, nil when there is none
    FBodies: TBodyLocator;    // INLINE_SOURCES / CALL_GRAPH / CALLER_GRAPH: where the bodies are
    FCalls: TCallIndex;       // CALL_GRAPH / CALLER_GRAPH, nil otherwise
    FMathJax: string;         // the script elements that load MathJax ($mathjax of the header), '' when not used
    FRelations: Boolean;      // REFERENCES_RELATION / REFERENCED_BY_RELATION
    FInline: Boolean;         // INLINE_SOURCES: the body of each routine in its documentation
    FWordCache: TDictionary<string, string>;
    FSource: Boolean;         // SOURCE_BROWSER: a highlighted page with line numbers for every unit
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
    procedure BuildMenu;
    function TabUrl(const AType: string; out AAvailable: Boolean): string;
    function TabHref(const AUrl: string): string;
    function NavTitle(const AType: string): string;
    function NavIntro(const AType, ADefault: string): string;
    procedure CollectTabs(AParent: TLayoutEntry);
    procedure AddTabs(AParent: TNavNode; ALayout: TLayoutEntry);
    procedure BuildPageMenu;
    procedure StaticTabs;
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
    function LayoutListsDecl(AInUnit: Boolean; const AStart, AEnd: string): Boolean;
    function IsConstructor(M: TMemberDef): Boolean;
    function ArgsHtml(M: TMemberDef; ADefaults: Boolean): string;
    function DirectivesText(M: TMemberDef): string;
    function LeftHtml(M: TMemberDef): string;
    function RightHtml(M: TMemberDef): string;
    function ProtoHtml(M: TMemberDef): string;
    function MemberRows(M: TMemberDef; const AInheritClass: string): string;
    procedure DeclSections(AMembers: TList<TMemberDef>; AInUnit: Boolean; ARows, ASummary: TStringBuilder);
    function DirTable(D: TDirDef; const AHeading: string; ADirs: Boolean): string;
    procedure DeclSection(AMembers: TList<TMemberDef>; AInUnit: Boolean; const AKey: string; ARows, ASummary: TStringBuilder);
    procedure InheritedSections(C: TClassDef; ARows: TStringBuilder);
    function MemberDoc(M: TMemberDef): string;
    function DocSections(AMembers: TList<TMemberDef>; AInUnit: Boolean): string;
    function DetailedBlock(ADef: TDefinition; AWithHeading: Boolean): string;
    function PageKind(ADef: TDefinition): string;
    function LayoutElement(const APage, AName: string): TLayoutEntry;
    function LayoutShows(const APage, AName: string): Boolean;
    function LayoutTitle(const APage, AName, ADefault: string): string;
    function DetailTitle(ADef: TDefinition): string;
    function LayoutMembers(AInUnit: Boolean; const AKind: string): TLayoutEntry;
    function NavPathOf(ADef: TDefinition): string;
    // pages
    function RunGraph(const ABase, ATitle, ADot: string): string;
    procedure FlushGraphs;
    function MathJaxScript: string;
    procedure WriteFormulas;
    function ClassGraph(C: TClassDef): string;
    function UnitGraph(U: TUnitDef): string;
    function MemberGraphs(M: TMemberDef): string;
    procedure WriteMainPage;
    procedure WriteClass(C: TClassDef);
    procedure WriteMembersPage(C: TClassDef);
    procedure WriteUnit(U: TUnitDef);
    function DirDot(D: TDirDef): string;
    function DirNavPath(D: TDirDef): string;
    procedure WriteDirectory(D: TDirDef);
    procedure DirTreeRows(D: TDirDef; ALevel: Integer; var ARow: Integer);
    procedure WriteDirsIndex;
    function HasSource(U: TUnitDef): Boolean;
    function SourceUrl(U: TUnitDef): string;
    procedure WriteSource(U: TUnitDef);
    function WordLinker(AScope: TDefinition): TWordLinker;
    function InlineSource(M: TMemberDef): string;
    function RelationLink(X: TMemberDef; const AText: string): string;
    function Relations(M: TMemberDef): string;
    procedure WriteGroup(G: TGroupDef);
    procedure WritePage(P: TPageDef);
    // index pages
    procedure DirRow(var ARow: Integer; ALevel: Integer; const AIcon, ALink, ABrief: string);
    procedure ClassTreeRows(C: TClassDef; ALevel: Integer; var ARow: Integer; ASB: TStringBuilder);
    procedure HierarchyRows(C: TClassDef; ALevel: Integer; var ARow: Integer; ASB: TStringBuilder);
    procedure GroupRows(G: TGroupDef; ALevel: Integer; var ARow: Integer; ASB: TStringBuilder);
    procedure WriteAnnotated;
    procedure WriteClassIndex;
    function IndexName(const AName: string): string;
    function ShowInitializer(E: TEntry): Boolean;
    function MemberCompare(A, B: TMemberDef): Integer;
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
  SearchLabels: array[0..10] of string = ('All', 'Classes', 'Units', 'Routines', 'Variables', 'Types',
    'Enumerations', 'Enumerator', 'Properties', 'Topics', 'Pages');
  CAll = 0; CClasses = 1; CUnits = 2; CFunctions = 3; CVariables = 4; CTypedefs = 5; CEnums = 6; CEnumValues = 7;
  CProperties = 8; CGroups = 9; CPages = 10;

{$IFDEF MSWINDOWS}
// Runs hhc.exe on index.hhp and waits for it (it exits with 1 when the CHM was built).
procedure RunHhc(const AHhc, ADir: string);
begin
  RunTool('"' + AHhc + '" index.hhp', ADir);
end;
{$ENDIF}

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
  FSource := AConfig.GetBool('SOURCE_BROWSER');
  FWordCache := TDictionary<string, string>.Create;
  FDotGraphs := AConfig.GetBool('HAVE_DOT');
  FInline := AConfig.GetBool('INLINE_SOURCES');
  FRelations := AConfig.GetBool('REFERENCES_RELATION') or AConfig.GetBool('REFERENCED_BY_RELATION');
  if FRelations or FInline or (FDotGraphs and (AConfig.GetBool('CALL_GRAPH') or AConfig.GetBool('CALLER_GRAPH'))) then
    FBodies := TBodyLocator.Create(AProject, FLinks);
  if FRelations or (FDotGraphs and (AConfig.GetBool('CALL_GRAPH') or AConfig.GetBool('CALLER_GRAPH'))) then
    FCalls := TCallIndex.Create(FBodies, FLinks);
  FDot := TDotGraphs.Create(AProject, FLinks, AConfig, FCalls,
    function(ADef: TDefinition): string
    begin
      Result := FDoc.DefUrl(ADef);
    end);
  FRunner := TDotRunner.Create(ADir, AConfig.GetString('DOT_PATH'), AConfig.GetString('DOT_IMAGE_FORMAT'),
    AConfig.GetBool('DOT_CLEANUP'));
  FRunner.BatchSize := AConfig.GetInt('DOT_BATCH_SIZE');
  FRunner.Threads := AConfig.GetInt('DOT_NUM_THREADS');
  FColors := THtmlColors.Parse(AConfig.GetString('HTML_COLORSTYLE'), AConfig.GetInt('HTML_COLORSTYLE_HUE'),
    AConfig.GetInt('HTML_COLORSTYLE_SAT'), AConfig.GetInt('HTML_COLORSTYLE_GAMMA'));
  FLight := HtmlResourceText('lightmode_settings.css');
  FDark := HtmlResourceText('darkmode_settings.css');
  FTree := AConfig.GetBool('GENERATE_TREEVIEW');
  FSearch := AConfig.GetBool('SEARCHENGINE');
  FNoIndex := AConfig.GetBool('DISABLE_INDEX');
  FDynMenus := AConfig.GetBool('HTML_DYNAMIC_MENUS');
  FPageMenu := TDictionary<string, TPair<string, string>>.Create;
  FLayout := TLayout.Create(AConfig);
  FAlphabeticalIndex := AConfig.GetBool('ALPHABETICAL_INDEX');
  FIgnorePrefix := AConfig.GetList('IGNORE_PREFIX');
  FCtorsFirst := AConfig.GetBool('SORT_MEMBERS_CTORS_1ST');
  FSortByScope := AConfig.GetBool('SORT_BY_SCOPE_NAME');
  FShowUsedFiles := AConfig.GetBool('SHOW_USED_FILES');
  FTimestamp := UpperCase(AConfig.GetString('TIMESTAMP'));
  FBriefMemberDesc := AConfig.GetBool('BRIEF_MEMBER_DESC');
  FRepeatBrief := AConfig.GetBool('REPEAT_BRIEF');
  FInlineInfo := AConfig.GetBool('INLINE_INFO');
  FShowEnumValues := AConfig.GetBool('SHOW_ENUM_VALUES');
  FMaxInitLines := AConfig.GetInt('MAX_INITIALIZER_LINES');
  FEnumPerLine := AConfig.GetInt('ENUM_VALUES_PER_LINE');
  FTabs := TDictionary<string, TLayoutEntry>.Create;
  if FLayout.NavIndex <> nil then
    CollectTabs(FLayout.NavIndex);
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
  FRunner.Free;
  FMenu.Free;
  FTabs.Free;
  FLayout.Free;
  FPageMenu.Free;
  FDot.Free;
  FCalls.Free;
  FBodies.Free;
  FWordCache.Free;
  FDirs.Free;
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
    if (FTimestamp = 'YES') or (FTimestamp = 'DATETIME') then
      Keys.Add('$doxygenversion', DoxyPasVersion + ' (' + FormatDateTime('yyyy-mm-dd hh:nn', Now) + ')')
    else if FTimestamp = 'DATE' then
      Keys.Add('$doxygenversion', DoxyPasVersion + ' (' + FormatDateTime('yyyy-mm-dd', Now) + ')')
    else
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
    Keys.Add('$mathjax', FMathJax);
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
    '  "serverBasedSearch": false,'#10'  "disableIndex": ' + B(FNoIndex) + ','#10'  "dynamicMenus": ' + B(FDynMenus) + ','#10 +
    '  "fullSidebar": ' + B(FSidebar) + #10'}'#10'</script>'#10;
end;

procedure THtmlGenerator.QuickLinks(AMenu: Boolean);
begin
  W(ConfigScript);
  if not AMenu then
    Exit;
  if not FDynMenus then
  begin
    StaticTabs;
    if FTree and FSidebar then
      W('<div id="container"><div id="doc-content">'#10);
    Exit;
  end;
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

// Default title of the entries of the navigation index (the types of the <tab> elements of the layout).
function DefaultTabTitle(const AType: string): string;
begin
  if AType = 'mainpage' then Result := 'Main Page'
  else if AType = 'pages' then Result := 'Related Pages'
  else if AType = 'topics' then Result := 'Topics'
  else if AType = 'namespaces' then Result := 'Units'
  else if AType = 'namespacelist' then Result := 'Unit List'
  else if AType = 'classes' then Result := 'Classes'
  else if AType = 'classlist' then Result := 'Class List'
  else if AType = 'classindex' then Result := 'Class Index'
  else if AType = 'hierarchy' then Result := 'Class Hierarchy'
  else if AType = 'classmembers' then Result := 'Class Members'
  else if AType = 'files' then Result := 'Files'
  else if AType = 'filelist' then Result := 'Directory Hierarchy'
  else Result := '';
end;

// The URL (without the extension) of a type of tab and whether there is something to show.
function THtmlGenerator.TabUrl(const AType: string; out AAvailable: Boolean): string;
begin
  AAvailable := True;
  Result := '';
  if AType = 'mainpage' then Result := 'index'
  else if AType = 'pages' then begin Result := 'pages'; AAvailable := FHasPages; end
  else if AType = 'topics' then begin Result := 'topics'; AAvailable := FHasGroups; end
  else if (AType = 'namespaces') or (AType = 'namespacelist') then begin Result := 'namespaces'; AAvailable := FHasUnits; end
  else if (AType = 'classes') or (AType = 'classlist') then begin Result := 'annotated'; AAvailable := FHasClasses; end
  else if AType = 'classindex' then begin Result := 'classes'; AAvailable := FHasClasses and FAlphabeticalIndex; end
  else if AType = 'hierarchy' then begin Result := 'hierarchy'; AAvailable := FHasClasses; end
  else if AType = 'classmembers' then begin Result := 'functions'; AAvailable := FHasClasses; end
  else if (AType = 'files') or (AType = 'filelist') then begin Result := 'dirs'; AAvailable := FDirs <> nil; end
  else AAvailable := False;
end;

// Title of a type of tab (the title of the layout, else the default, translated).
function THtmlGenerator.NavTitle(const AType: string): string;
var
  E: TLayoutEntry;
begin
  if FTabs.TryGetValue(AType, E) and (E.Attr('title') <> '') then
    Result := E.Attr('title')
  else
    Result := Tr(DefaultTabTitle(AType));
end;

// The text before the list of an index page (intro="..." of the layout, else the default, translated).
function THtmlGenerator.NavIntro(const AType, ADefault: string): string;
var
  E: TLayoutEntry;
begin
  if FTabs.TryGetValue(AType, E) and (E.Attr('intro') <> '') then
    Result := E.Attr('intro')
  else
    Result := Tr(ADefault);
end;

procedure THtmlGenerator.CollectTabs(AParent: TLayoutEntry);
var
  E: TLayoutEntry;
begin
  for E in AParent.Children do
    if SameText(E.Name, 'tab') then
    begin
      if not FTabs.ContainsKey(E.Attr('type')) then
        FTabs.Add(E.Attr('type'), E);
      CollectTabs(E);
    end;
end;

// The visible tabs of a layout (navindex or a usergroup), with their sub-tabs.
procedure THtmlGenerator.AddTabs(AParent: TNavNode; ALayout: TLayoutEntry);
var
  E: TLayoutEntry;
  Typ, Url, Title: string;
  Avail: Boolean;
  N: TNavNode;
begin
  for E in ALayout.Children do
  begin
    if not SameText(E.Name, 'tab') or not FLayout.Visible(E) then
      Continue;
    Typ := E.Attr('type');
    if (Typ = 'user') or (Typ = 'usergroup') then
    begin
      Title := E.Attr('title');
      Url := E.Attr('url');
      if Title = '' then
        Continue;
      N := AParent.Add(Title, Url);
      if Typ = 'usergroup' then
      begin
        AddTabs(N, E);
        if (N.Url = '') and (N.Kids.Count > 0) then
          N.Url := N.Kids[0].Url;
      end;
      Continue;
    end;
    Url := TabUrl(Typ, Avail);
    if (Url = '') or not Avail then
      Continue;
    N := AParent.Add(NavTitle(Typ), Url);
    AddTabs(N, E);
  end;
end;

// The tabs of the menu: the navigation index of the layout, else Main Page, Related Pages, Topics, Units, Classes.
procedure THtmlGenerator.BuildMenu;
var
  N: TNavNode;
begin
  FMenu := TNavNode.Create('', '');
  if (FLayout.NavIndex <> nil) then
  begin
    AddTabs(FMenu, FLayout.NavIndex);
    Exit;
  end;
  FMenu.Add(NavTitle('mainpage'), 'index');
  if FHasPages then
    FMenu.Add(NavTitle('pages'), 'pages');
  if FHasGroups then
    FMenu.Add(NavTitle('topics'), 'topics');
  if FHasUnits then
  begin
    N := FMenu.Add(NavTitle('namespaces'), 'namespaces');
    N.Add(NavTitle('namespacelist'), 'namespaces');
    if FDirs <> nil then
      N.Add(NavTitle('filelist'), 'dirs');
  end;
  if FHasClasses then
  begin
    N := FMenu.Add(NavTitle('classes'), 'annotated');
    N.Add(NavTitle('classlist'), 'annotated');
    if FAlphabeticalIndex then
      N.Add(NavTitle('classindex'), 'classes');
    N.Add(NavTitle('hierarchy'), 'hierarchy');
    N.Add(NavTitle('classmembers'), 'functions');
  end;
end;

// A tab URL: a page of the output (no extension yet) or the address a user gave (it has a dot or a colon).
function THtmlGenerator.TabHref(const AUrl: string): string;
begin
  if (Pos('.', AUrl) > 0) or (Pos(':', AUrl) > 0) or (AUrl = '') then
    Result := AUrl
  else
    Result := AUrl + FExt;
end;

// Which tab and which sub-tab a page belongs to: AFile (without the extension) -> the URLs of the entries of the menu.
procedure THtmlGenerator.BuildPageMenu;

  procedure Put(const AFile, ATop, ASub: string);
  begin
    FPageMenu.AddOrSetValue(AFile, TPair<string, string>.Create(ATop, ASub));
  end;

var
  P: TPageDef;
  G: TGroupDef;
  U: TUnitDef;
  C: TClassDef;
  D: TDirDef;
begin
  Put('index', 'index', '');
  Put('pages', 'pages', '');
  for P in FProject.Pages do
    if not P.IsMainPage then
      Put(P.DiskName, 'pages', '');
  Put('topics', 'topics', '');
  for G in FProject.Groups do
    Put(G.DiskName, 'topics', '');
  Put('namespaces', 'namespaces', 'namespaces');
  for U in FProject.Units do
  begin
    Put(U.DiskName, 'namespaces', 'namespaces');
    Put(U.DiskName + '_source', 'namespaces', 'namespaces');
  end;
  if FDirs <> nil then
  begin
    Put('dirs', 'namespaces', 'dirs');
    for D in FDirs.All do
      Put(D.DiskName, 'namespaces', 'dirs');
  end;
  Put('annotated', 'annotated', 'annotated');
  Put('classes', 'annotated', 'classes');
  Put('hierarchy', 'annotated', 'hierarchy');
  Put('functions', 'annotated', 'functions');
  for C in FProject.Classes do
  begin
    Put(C.DiskName, 'annotated', 'annotated');
    Put(C.DiskName + '-members', 'annotated', 'annotated');
  end;
end;

// HTML_DYNAMIC_MENUS = NO: the tabs are part of every page (navrow1 and, below the current tab, navrow2).
procedure THtmlGenerator.StaticTabs;
var
  Hit: TPair<string, string>;
  Top, N: TNavNode;

  procedure Row(const AId, AClass: string; AItems: TObjectList<TNavNode>; const ACurrent: string; ASearch: Boolean);
  var
    Item: TNavNode;
  begin
    W('  <div id="' + AId + '" class="' + AClass + '">'#10'    <ul class="tablist">'#10);
    for Item in AItems do
    begin
      if Item.Url = ACurrent then
        W('      <li class="current">')
      else
        W('      <li>');
      W('<a href="' + TabHref(Item.Url) + '"><span>' + HtmlEscape(Item.Name).Replace(' ', '&#160;') + '</span></a></li>'#10);
    end;
    if ASearch and FSearch and not (FTree and FSidebar) then
      W('      <li>'#10 + SearchBoxHtml + '      </li>'#10);
    W('    </ul>'#10'  </div>'#10);
  end;

begin
  if FMenu = nil then
    BuildMenu;
  Top := nil;
  if FPageMenu.TryGetValue(FPageFile, Hit) then
    for N in FMenu.Kids do
      if N.Url = Hit.Key then
        Top := N;
  W('<div id="main-nav">'#10);
  if Top <> nil then
    Row('navrow1', 'tabs', FMenu.Kids, Top.Url, True)
  else
    Row('navrow1', 'tabs', FMenu.Kids, '', True);
  if (Top <> nil) and (Top.Kids.Count > 0) then
    Row('navrow2', 'tabs2', Top.Kids, Hit.Value, False);
  W('</div><!-- main-nav -->'#10);
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
  U: TUnitDef;
  Line, Name: string;
begin
  E := ADef.Entry;
  if (E = nil) or (E.FileName = '') then
    Exit('');
  Line := IntToStr(E.Line);
  Name := HtmlEscape(ExtractFileName(FProject.OutputPath(E.FileName)));
  U := ADef.OwnerUnit;
  if (U <> nil) and HasSource(U) and SameText(E.FileName, U.FileName) then
  begin
    Line := '<a href="' + SourceUrl(U) + '#l' + Format('%.5d', [E.Line]) + '">' + Line + '</a>';
    Name := '<a href="' + SourceUrl(U) + '">' + Name + '</a>';
  end;
  Result := '<p class="definition">' + Format(Tr('Definition at line %d of file %s.').Replace('%d', '%s'),
    [Line, Name]) + '</p>'#10;
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
        Result := MemberCompare(A, B);
      end));
end;

// By name; with SORT_MEMBERS_CTORS_1ST the constructors and destructors come first.
function THtmlGenerator.MemberCompare(A, B: TMemberDef): Integer;
begin
  if FCtorsFirst and (IsConstructor(A) <> IsConstructor(B)) then
  begin
    if IsConstructor(A) then Exit(-1) else Exit(1);
  end;
  Result := CompareText(A.Name, B.Name);
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

// The section of the declaration tables a <memberdecl> element stands for ('' for the ones DoxyPas does not have).
// The names are the ones of Doxygen (publicmethods, ...) plus the ones of Pascal: published, strictprotected,
// strictprivate and the constants.
function DeclKeyOf(const AName: string; AInUnit: Boolean): string;
const
  Prot: array[0..5] of string = ('public', 'published', 'protected', 'strictprotected', 'private', 'strictprivate');
  Short: array[0..5] of string = ('pub', 'pbl', 'pro', 'spr', 'pri', 'spv');
  Kinds: array[0..5] of string = ('types', 'constants', 'methods', 'staticmethods', 'attributes', 'staticattributes');
  Keys: array[0..5] of string = ('types', 'consts', 'methods', 'static-methods', 'attribs', 'static-attribs');
var
  I, K: Integer;
begin
  Result := '';
  if AInUnit then
  begin
    if AName = 'typedefs' then Result := 'typedef-members'
    else if AName = 'enums' then Result := 'enum-members'
    else if AName = 'constants' then Result := 'const-members'
    else if AName = 'functions' then Result := 'func-members'
    else if AName = 'variables' then Result := 'var-members';
    Exit;
  end;
  if AName = 'properties' then
    Exit('properties');
  for I := 0 to 5 do
    for K := 0 to 5 do
      if AName = Prot[I] + Kinds[K] then
        Exit(Short[I] + '-' + Keys[K]);
end;

// The group of documentation (see DocSections) a <memberdef> element stands for, -1 for the others.
function DefGroupOf(const AName: string; AInUnit: Boolean): Integer;
begin
  Result := -1;
  if (AName = 'constructors') and not AInUnit then Result := 0
  else if AName = 'typedefs' then Result := 1
  else if AName = 'enums' then Result := 2
  else if AName = 'functions' then Result := 3
  else if AName = 'variables' then Result := 4
  else if (AName = 'properties') and not AInUnit then Result := 5
  else if AName = 'constants' then Result := 6;
end;
function THtmlGenerator.IsConstructor(M: TMemberDef): Boolean;
begin
  Result := (M.Kind = memFunction) and (M.Entry <> nil) and (M.Entry.MethodKind in [rkConstructor, rkDestructor]);
end;

// Does the <memberdecl> of the layout have an element that starts with / ends with the text? (A layout that does not
// have the elements of Pascal, one from Doxygen for instance, shows the members of those sections with the others.)
function THtmlGenerator.LayoutListsDecl(AInUnit: Boolean; const AStart, AEnd: string): Boolean;
var
  MD, E: TLayoutEntry;
begin
  MD := LayoutMembers(AInUnit, 'memberdecl');
  if MD = nil then
    Exit(True);
  for E in MD.Children do
    if (AStart <> '') and E.Name.StartsWith(AStart) or (AEnd <> '') and E.Name.EndsWith(AEnd) then
      Exit(True);
  Result := False;
end;

function THtmlGenerator.SectionKey(M: TMemberDef; AInUnit: Boolean): string;
var
  P, What: string;
  Static, Consts: Boolean;
begin
  if M.Kind = memProperty then
    Exit('properties');
  // the constants have a section of their own when the layout has one
  Consts := (M.Kind = memConstant) and LayoutListsDecl(AInUnit, '', 'constants');
  if AInUnit then
  begin
    case M.Kind of
      memTypedef: Result := 'typedef-members';
      memEnumeration: Result := 'enum-members';
      memFunction: Result := 'func-members';
    else
      if Consts then Result := 'const-members' else Result := 'var-members';
    end;
    Exit;
  end;
  case M.Protection of
    prPublished: if LayoutListsDecl(False, 'published', '') then P := 'pbl' else P := 'pub';
    prProtected: P := 'pro';
    prStrictProtected: if LayoutListsDecl(False, 'strictprotected', '') then P := 'spr' else P := 'pro';
    prPrivate: P := 'pri';
    prStrictPrivate: if LayoutListsDecl(False, 'strictprivate', '') then P := 'spv' else P := 'pri';
  else
    P := 'pub';
  end;
  Static := (M.Entry <> nil) and ([efClassMember, efStatic] * M.Entry.Flags <> []);
  case M.Kind of
    memTypedef, memEnumeration: What := 'types';
    memFunction: if Static then What := 'static-methods' else What := 'methods';
  else
    if Consts then What := 'consts'
    else if Static then What := 'static-attribs'
    else What := 'attribs';
  end;
  Result := P + '-' + What;
end;
function THtmlGenerator.SectionTitle(const AKey: string): string;
var
  P, What: string;
begin
  if AKey = 'properties' then Exit(Tr('Properties'));
  if AKey = 'typedef-members' then Exit(Tr('Types'));
  if AKey = 'enum-members' then Exit(Tr('Enumerations'));
  if AKey = 'const-members' then Exit(Tr('Constants'));
  if AKey = 'func-members' then Exit(Tr('Routines'));
  if AKey = 'var-members' then Exit(Tr('Variables'));
  if AKey.StartsWith('pub-') then P := 'Public'
  else if AKey.StartsWith('pbl-') then P := 'Published'
  else if AKey.StartsWith('pro-') then P := 'Protected'
  else if AKey.StartsWith('spr-') then P := 'Strict Protected'
  else if AKey.StartsWith('spv-') then P := 'Strict Private'
  else P := 'Private';
  What := Copy(AKey, 5, MaxInt);
  if What = 'types' then Result := TrSection(P, 'Types')
  else if What = 'consts' then Result := TrSection(P, 'Constants')
  else if What = 'methods' then Result := TrSection(P, 'Methods')
  else if What = 'static-methods' then Result := TrSection(P, 'Class Methods')
  else if What = 'attribs' then Result := TrSection(P, 'Fields')
  else Result := TrSection(P, 'Class Fields');
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
    if (efInline in E.Flags) and FInlineInfo then L.Add('inline');
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

// The initial value of a variable or constant is shown unless \hideinitializer, or when it has more lines than
// MAX_INITIALIZER_LINES (0: never) and there is no \showinitializer.
function THtmlGenerator.ShowInitializer(E: TEntry): Boolean;
var
  Lines, I: Integer;
begin
  if (E.InitText = '') or (efHideInitializer in E.Flags) then
    Exit(False);
  if efShowInitializer in E.Flags then
    Exit(True);
  Lines := 1;
  for I := 1 to Length(E.InitText) do
    if E.InitText[I] = #10 then
      Inc(Lines);
  Result := (FMaxInitLines > 0) and (Lines <= FMaxInitLines);
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
        if ShowInitializer(E) then
          Result := Result + ' = ' + FDoc.LinkedText(E.InitText, M);
      end;
    memTypedef:
      if E.TypeText <> '' then
        Result := Result + ' = ' + FDoc.LinkedText(E.TypeText, M);
    memEnumeration:
      // the values, ENUM_VALUES_PER_LINE on each line (0: not in the table); SHOW_ENUM_VALUES adds "= value"
      if FEnumPerLine > 0 then
      begin
        Vals := '';
        N := 0;
        for V in M.EnumValues do
        begin
          if N > 0 then
          begin
            Vals := Vals + ',';
            if N mod FEnumPerLine = 0 then
              Vals := Vals + '<br />&#160;&#160;&#160;&#160;'
            else
              Vals := Vals + ' ';
          end;
          Vals := Vals + FDoc.Link(V, V.Name);
          if FShowEnumValues and (V.Entry <> nil) and (V.Entry.InitText <> '') then
            Vals := Vals + ' = ' + FDoc.LinkedText(V.Entry.InitText, M);
          Inc(N);
        end;
        if Vals <> '' then
          Result := Result + ' { ' + Vals + ' }';
      end;  end;
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
        if ShowInitializer(E) then
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
      if ShowInitializer(E) then
        Result := Result + ' = ' + FDoc.LinkedText(E.InitText, M);
    end;
  end;
end;

function THtmlGenerator.MemberRows(M: TMemberDef; const AInheritClass: string): string;
var
  Cls, Brief, More: string;
  Id: string;
  T1: Int64;
begin
  Id := M.DiskName;
  Cls := 'memitem:' + Id;
  if AInheritClass <> '' then
    Cls := Cls + ' ' + AInheritClass;
  T1 := Tick;
  Result := '<tr class="' + Cls + '" id="r_' + Id + '"><td class="memItemLeft" align="right" valign="top">' +
    LeftHtml(M) + '</td><td class="memItemRight" valign="bottom">' + RightHtml(M) + '</td></tr>'#10;
  Add('rows: Left+Right', T1);
  T1 := Tick;
  Brief := BriefOf(M);
  Add('rows: BriefOf', T1);
  if (Brief <> '') and FBriefMemberDesc then
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
  UnitOrder: array[0..4] of string = ('typedef-members', 'enum-members', 'const-members', 'func-members', 'var-members');
  Prots: array[0..5] of string = ('pub', 'pbl', 'pro', 'spr', 'pri', 'spv');
  Kinds: array[0..5] of string = ('types', 'consts', 'methods', 'static-methods', 'attribs', 'static-attribs');
var
  Order: TList<string>;
  Key, P, K: string;
  MD, E: TLayoutEntry;
begin
  Order := TList<string>.Create;
  try
    if AInUnit then
      Order.AddRange(UnitOrder)
    else
    begin
      for K in Kinds do
        Order.Add('pub-' + K);
      Order.Add('properties');                // after the public ones, then the other visibilities
      for P in Prots do
        if P <> 'pub' then
          for K in Kinds do
            Order.Add(P + '-' + K);
    end;
    MD := LayoutMembers(AInUnit, 'memberdecl');
    if MD <> nil then
    begin
      Order.Clear;                       // only what the layout lists, in its order
      for E in MD.Children do
      begin
        Key := DeclKeyOf(E.Name, AInUnit);
        if (Key <> '') and FLayout.Visible(E) and not Order.Contains(Key) then
          Order.Add(Key);
      end;
    end;
    for Key in Order do
      DeclSection(AMembers, AInUnit, Key, ARows, ASummary);
  finally
    Order.Free;
  end;
end;

// The table of one section (AKey, see SectionKey) of the declarations of AMembers; nothing when it has no members.
procedure THtmlGenerator.DeclSection(AMembers: TList<TMemberDef>; AInUnit: Boolean; const AKey: string; ARows, ASummary: TStringBuilder);
var
  Title: string;
  M: TMemberDef;
  T0: Int64;
  Any: Boolean;
  MD, E: TLayoutEntry;
begin
  Any := False;
  for M in AMembers do
    if SectionKey(M, AInUnit) = AKey then
      Any := True;
  if not Any then
    Exit;
  Title := SectionTitle(AKey);
  MD := LayoutMembers(AInUnit, 'memberdecl');
  if MD <> nil then
    for E in MD.Children do
      if (DeclKeyOf(E.Name, AInUnit) = AKey) and (E.Attr('title') <> '') then
        Title := E.Attr('title');
  ARows.Append('<tr class="heading"><td colspan="2"><h2 class="groupheader"><a id="' + AKey + '" name="' + AKey +
    '"></a>'#10 + HtmlEscape(Title) + '</h2></td></tr>'#10);
  if ASummary.Length > 0 then
    ASummary.Append(' &#124;'#10);
  ASummary.Append('<a href="#' + AKey + '">' + HtmlEscape(Title) + '</a>');
  for M in AMembers do
    if SectionKey(M, AInUnit) = AKey then
    begin
      T0 := Tick;
      ARows.Append(MemberRows(M, ''));
      Add('decl: MemberRows', T0);
    end;
end;

procedure THtmlGenerator.InheritedSections(C: TClassDef; ARows: TStringBuilder);
const
  Prots: array[0..3] of string = ('pub', 'pbl', 'pro', 'spr');
  Kinds: array[0..5] of string = ('types', 'consts', 'methods', 'static-methods', 'attribs', 'static-attribs');
var
  Froms: TList<TClassDef>;
  IM: TInheritedMember;
  F: TClassDef;
  Key, Cls, Prot, Kind: string;
  Any: Boolean;
  Keys: TList<string>;

  function Wanted(const AIM: TInheritedMember): Boolean;
  begin
    Result := (AIM.From <> C) and FProject.IsVisible(AIM.Member) and (AIM.Member.Kind <> memEnumValue) and
      FLinks.IsLinkable(AIM.Member) and (AIM.Member.Protection in [prPublic, prPublished, prProtected,
      prStrictProtected]);
  end;

begin
  Froms := TList<TClassDef>.Create;
  Keys := TList<string>.Create;
  try
    for Prot in Prots do
      for Kind in Kinds do
        Keys.Add(Prot + '-' + Kind);
    Keys.Add('properties');
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
    Keys.Free;
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
  if FRepeatBrief or (Trim(M.Detailed) = '') then
    Body := FDoc.Render(M.Brief + #10#10 + M.Detailed, M)       // REPEAT_BRIEF: the brief before the detailed text
  else
    Body := FDoc.Render(M.Detailed, M);
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
    '</td>'#10'        </tr>'#10'      </table>'#10'</div><div class="memdoc">'#10 + Body + Tail + DefinedAt(M) + InlineSource(M) + Relations(M) + MemberGraphs(M) +
    #10'</div>'#10'</div>'#10;
end;

function THtmlGenerator.DocSections(AMembers: TList<TMemberDef>; AInUnit: Boolean): string;
const
  ClassGroups: array[0..6] of string = ('Constructor & Destructor Documentation', 'Type Documentation',
    'Member Enumeration Documentation', 'Method Documentation', 'Field Documentation',
    'Property Documentation', 'Constant Documentation');
  UnitGroups: array[0..6] of string = ('', 'Type Documentation', 'Enumeration Type Documentation',
    'Routine Documentation', 'Variable Documentation', '', 'Constant Documentation');
  // the order of the groups when there is no layout: the constants after the types and the enumerations
  GroupOrder: array[0..6] of Integer = (0, 1, 2, 6, 3, 4, 5);

  // does the <memberdef> of the layout have the element? (a layout of Doxygen does not have the constants)
  function LayoutListsDef(AUnit: Boolean; const AName: string): Boolean;
  var
    MD: TLayoutEntry;
  begin
    MD := LayoutMembers(AUnit, 'memberdef');
    Result := (MD = nil) or (MD.Child(AName) <> nil);
  end;

  function GroupOf(M: TMemberDef): Integer;
  begin
    if IsConstructor(M) then Exit(0);
    case M.Kind of
      memTypedef: Result := 1;
      memEnumeration: Result := 2;
      memFunction: Result := 3;
      memProperty: Result := 5;
      memConstant: if LayoutListsDef(AInUnit, 'constants') then Result := 6 else Result := 4;
    else
      Result := 4;
    end;
  end;

var
  G, I: Integer;
  M: TMemberDef;
  Docs: TList<TMemberDef>;
  Title: string;
  MD, E: TLayoutEntry;
  Groups: TList<Integer>;
  Titles: array[0..6] of string;
begin
  Result := '';
  Docs := TList<TMemberDef>.Create;
  Groups := TList<Integer>.Create;
  try
    for G in GroupOrder do
    begin
      Groups.Add(G);
      Titles[G] := '';
    end;
    MD := LayoutMembers(AInUnit, 'memberdef');
    if MD <> nil then
    begin
      Groups.Clear;
      for E in MD.Children do
      begin
        I := DefGroupOf(E.Name, AInUnit);
        if (I >= 0) and FLayout.Visible(E) and not Groups.Contains(I) then
        begin
          Groups.Add(I);
          Titles[I] := E.Attr('title');
        end;
      end;
    end;
    for G in Groups do
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
            Result := MemberCompare(A, B);
          end));
      if AInUnit then Title := Tr(UnitGroups[G]) else Title := Tr(ClassGroups[G]);
      if (Title = '') and AInUnit then
        Title := Tr(UnitGroups[3]);          // (the constructors of a unit: none)
      if Titles[G] <> '' then
        Title := Titles[G];
      Result := Result + '<h2 class="groupheader">' + HtmlEscape(Title) + '</h2>'#10;
      for M in Docs do
        Result := Result + MemberDoc(M);
    end;
  finally
    Groups.Free;
    Docs.Free;
  end;
end;

// The layout kind of a page: "class" for classes, "namespace" for units, "group" for groups.
function THtmlGenerator.PageKind(ADef: TDefinition): string;
begin
  if ADef is TClassDef then Result := 'class'
  else if ADef is TUnitDef then Result := 'namespace'
  else if ADef is TGroupDef then Result := 'group'
  else Result := '';
end;

// An element of the layout of a kind of page (nil without layout or when it does not say anything about it).
function THtmlGenerator.LayoutElement(const APage, AName: string): TLayoutEntry;
var
  P: TLayoutEntry;
begin
  Result := nil;
  P := FLayout.Page(APage);
  if P <> nil then
    Result := P.Child(AName);
end;

// A page element is shown unless the layout says visible="no".
function THtmlGenerator.LayoutShows(const APage, AName: string): Boolean;
var
  E: TLayoutEntry;
begin
  E := LayoutElement(APage, AName);
  Result := (E = nil) or FLayout.Visible(E);
end;

function THtmlGenerator.LayoutTitle(const APage, AName, ADefault: string): string;
var
  E: TLayoutEntry;
begin
  E := LayoutElement(APage, AName);
  if (E <> nil) and (E.Attr('title') <> '') then
    Result := E.Attr('title')
  else
    Result := ADefault;
end;

function THtmlGenerator.DetailTitle(ADef: TDefinition): string;
begin
  Result := LayoutTitle(PageKind(ADef), 'detaileddescription', Tr('Detailed Description'));
end;

// <memberdecl> (the declaration tables) or <memberdef> (the documentation) of the layout of a class or unit page.
function THtmlGenerator.LayoutMembers(AInUnit: Boolean; const AKind: string): TLayoutEntry;
begin
  if FPageLayout <> '' then
    Result := LayoutElement(FPageLayout, AKind)
  else if AInUnit then
    Result := LayoutElement('namespace', AKind)
  else
    Result := LayoutElement('class', AKind);
end;

function THtmlGenerator.DetailedBlock(ADef: TDefinition; AWithHeading: Boolean): string;
var
  Text: string;
begin
  if (PageKind(ADef) <> '') and not LayoutShows(PageKind(ADef), 'detaileddescription') then
    Exit('');
  if (ADef is TUnitDef) and not LayoutShows('file', 'detaileddescription') then
    Exit('');       // a unit is also a file
  Text := FDoc.Render(ADef.Detailed, ADef);
  if (Text = '') and (DefinedAt(ADef) = '') then
    Exit('');
  Result := '<a name="details" id="details"></a><h2 class="groupheader">' + HtmlEscape(DetailTitle(ADef)) + '</h2>'#10 +
    '<div class="textblock">' + Text + '</div>'#10 + DefinedAt(ADef);
end;

{ ------------------------------------------------------------------ pages }

// FORMULA_MACROFILE: the \newcommand lines as MathJax macros ("name: 'text'," / "name: ['text', args],").
function MathJaxMacros(const AFile: string): string;
var
  M: TMatch;
  Args: string;
begin
  Result := '';
  if (AFile = '') or not TFile.Exists(AFile) then
    Exit;
  for M in TRegEx.Matches(TFile.ReadAllText(AFile), '\\(?:re)?newcommand\s*\{\\(\w+)\}\s*(?:\[(\d+)\])?\s*\{(.*)\}') do
  begin
    Args := M.Groups[2].Value;
    if Args <> '' then
      Result := Result + '      ' + M.Groups[1].Value + ': [''' + M.Groups[3].Value.Replace('\', '\\').Replace('''', '\''') +
        ''', ' + Args + '],'#10
    else
      Result := Result + '      ' + M.Groups[1].Value + ': ''' + M.Groups[3].Value.Replace('\', '\\').Replace('''', '\''') +
        ''','#10;
  end;
end;

// The scripts that load MathJax (USE_MATHJAX), like Doxygen's htmlgen: versions 2, 3 and 4.
function THtmlGenerator.MathJaxScript: string;
var
  Version, Format, Path, Macros, Ext, Code, Pkg: string;
  Exts: TArray<string>;
  First: Boolean;
  SB: TStringBuilder;
begin
  Version := FConfig.GetString('MATHJAX_VERSION');
  Format := FConfig.GetString('MATHJAX_FORMAT');
  Path := FConfig.GetString('MATHJAX_RELPATH');
  Exts := FConfig.GetList('MATHJAX_EXTENSIONS');
  Macros := MathJaxMacros(FConfig.GetString('FORMULA_MACROFILE'));
  Code := '';
  if (FConfig.GetString('MATHJAX_CODEFILE') <> '') and TFile.Exists(FConfig.GetString('MATHJAX_CODEFILE')) then
    Code := TFile.ReadAllText(FConfig.GetString('MATHJAX_CODEFILE')) + #10;
  if Version = '' then
    Version := 'MathJax_2';
  if Path = '' then
    Path := 'https://cdn.jsdelivr.net/npm/mathjax@' + Copy(Version, Length(Version), 1);
  SB := TStringBuilder.Create;
  try
    if SameText(Version, 'MathJax_2') then
    begin
      if Format = '' then
        Format := 'HTML-CSS';
      SB.Append('<script type="text/x-mathjax-config">'#10'MathJax.Hub.Config({'#10'  extensions: ["tex2jax.js"');
      for Ext in Exts do
        SB.Append(', "').Append(Ext).Append('.js"');
      SB.Append('],'#10'  jax: ["input/TeX","output/').Append(Format).Append('"],'#10);
      if Macros <> '' then
        SB.Append('   TeX: { Macros: {'#10).Append(Macros).Append('  } }'#10);
      SB.Append('});'#10).Append(Code).Append('</script>'#10);
      SB.Append('<script type="text/javascript" async="async" src="').Append(Path).Append('/MathJax.js"></script>'#10);
    end
    else
    begin
      if (Format = '') or SameText(Format, 'HTML-CSS') or SameText(Format, 'NativeMML') then
        Format := 'chtml';   // the formats of MathJax 2 do not exist in 3 and 4
      SB.Append('<script type="text/javascript">'#10'window.MathJax = {'#10'  options: {'#10 +
        '    ignoreHtmlClass: ''tex2jax_ignore'','#10'    processHtmlClass: ''tex2jax_process'''#10'  }');
      if (Length(Exts) > 0) or (Macros <> '') then
      begin
        SB.Append(','#10);
        if Length(Exts) > 0 then
        begin
          First := True;
          SB.Append('  loader: {'#10'    load: [');
          for Ext in Exts do
            if not Ext.StartsWith('-') then
            begin
              if not First then
                SB.Append(',');
              SB.Append('''[tex]/').Append(Ext).Append('''');
              First := False;
            end;
          SB.Append(']'#10'  },'#10);
        end;
        SB.Append('  tex: {'#10'    macros: {').Append(Macros).Append('},'#10);
        if SameText(Version, 'MathJax_3') then
        begin
          SB.Append('    packages: [''base'',''configmacros''');
          if Macros <> '' then
            SB.Append(',''newcommand''');
          for Ext in Exts do
            SB.Append(',''').Append(Ext).Append('''');
          SB.Append(']'#10);
        end
        else
        begin
          SB.Append('    packages: {');
          First := True;
          for Ext in Exts do
          begin
            if not First then
              SB.Append(',');
            if Ext.StartsWith('-') then
              Pkg := '''[-]'': [''' + Copy(Ext, 2, MaxInt) + ''']'
            else
              Pkg := '''[+]'': [''' + Ext + ''']';
            SB.Append(#10'        ').Append(Pkg);
            First := False;
          end;
          SB.Append(#10'    }'#10);
        end;
        SB.Append('  }');
      end;
      SB.Append(#10'};'#10).Append(Code).Append('</script>'#10);
      if SameText(Version, 'MathJax_3') then
        Path := Path + '/es5';
      SB.Append('<script type="text/javascript" id="MathJax-script" async="async" src="').Append(Path).Append('/tex-').
        Append(LowerCase(Format)).Append('.js"></script>'#10);
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

// Without MathJax the formulas are SVG images: one page of a LaTeX document per formula, then dvisvgm.
procedure THtmlGenerator.WriteFormulas;
var
  SB: TStringBuilder;
  Tex, Pre, Macro: string;
  I: Integer;
  Pkg: string;
begin
  if FDoc.FormulaTex.Count = 0 then
    Exit;
  SB := TStringBuilder.Create;
  try
    Pre := '10pt';
    if FConfig.GetInt('FORMULA_FONTSIZE') > 0 then
      Pre := FConfig.GetInt('FORMULA_FONTSIZE').ToString + 'pt';
    SB.Append('\documentclass[').Append(Pre).Append(']{article}'#10'\usepackage{amsmath,amssymb}'#10);
    for Pkg in FConfig.GetList('EXTRA_PACKAGES') do
      SB.Append('\usepackage{').Append(Pkg).Append('}'#10);
    Macro := FConfig.GetString('FORMULA_MACROFILE');
    if (Macro <> '') and TFile.Exists(Macro) then
      SB.Append(TFile.ReadAllText(Macro)).Append(#10);
    SB.Append('\pagestyle{empty}'#10'\begin{document}'#10);
    for I := 0 to FDoc.FormulaTex.Count - 1 do
    begin
      Tex := FDoc.FormulaTex[I];
      if I > 0 then
        SB.Append('\newpage'#10);
      if Tex[1] = 'i' then
        SB.Append('$').Append(Copy(Tex, 2, MaxInt)).Append('$'#10)
      else
        SB.Append('\[').Append(Copy(Tex, 2, MaxInt)).Append('\]'#10);
    end;
    SB.Append('\end{document}'#10);
    TFile.WriteAllText(TPath.Combine(FDir, 'formulas.tex'), SB.ToString, TUTF8Encoding.Create(False));
  finally
    SB.Free;
  end;
  // dvisvgm names the pages formula_1.svg ... (%p is the page number)
  if RunTool('latex -interaction=batchmode formulas.tex', FDir) and
    RunTool('dvisvgm --no-fonts -p1- -o formula_%p.svg formulas.dvi', FDir) then
    Inc(FFiles, FDoc.FormulaTex.Count)
  else
    Warn('', 0, 'formulas: latex or dvisvgm failed, see formulas.log in the HTML directory');
  if FConfig.GetBool('DOT_CLEANUP') then
    for Pkg in ['formulas.tex', 'formulas.dvi', 'formulas.aux', 'formulas.log'] do
      if TFile.Exists(TPath.Combine(FDir, Pkg)) then
        TFile.Delete(TPath.Combine(FDir, Pkg));
end;

// The HTML block that shows the SVG of a graph; dot runs later, over many files at once (FlushGraphs): starting it
// once per graph takes minutes on a big project.
function THtmlGenerator.RunGraph(const ABase, ATitle, ADot: string): string;
begin
  FRunner.Queue(ABase, ADot);
  Result := '<div class="dynheader">'#10 + ATitle + '</div>'#10'<div class="dyncontent">'#10;
  if FRunner.Extension = 'svg' then
    Result := Result + '<div class="center"><object type="image/svg+xml" data="' + ABase + '.svg" class="inherit_graph">' +
      ATitle + '</object></div>'#10'</div>'#10
  else
    Result := Result + '<div class="center"><img src="' + ABase + '.' + FRunner.Extension + '" alt="' + HtmlEscape(ATitle) +
      '" class="inherit_graph"/></div>'#10'</div>'#10;
end;

procedure THtmlGenerator.FlushGraphs;
begin
  Inc(FFiles, FRunner.Flush);
end;
// The graphs of a class: inheritance (CLASS_GRAPH) and collaboration (COLLABORATION_GRAPH).
function THtmlGenerator.ClassGraph(C: TClassDef): string;
var
  D: TClassDef;
  M: TMemberDef;
  Uses_: Boolean;
begin
  Result := '';
  if not FDotGraphs then
    Exit;
  Uses_ := C.Bases.Count > 0;
  for D in C.Derived do
    if FLinks.IsLinkable(D) then
      Uses_ := True;
  if Uses_ and SameText(FConfig.GetString('CLASS_GRAPH'), 'YES') and LayoutShows('class', 'inheritancegraph') then
    Result := RunGraph(C.DiskName + '_inherit_graph', Format(Tr('Inheritance diagram for %s:'), [HtmlEscape(C.Name)]),
      FDot.ClassDot(C, False));
  if FConfig.GetBool('COLLABORATION_GRAPH') and LayoutShows('class', 'collaborationgraph') then
    for M in C.Members do
      if (M.Kind in [memVariable, memProperty]) and (M.Entry.TypeText <> '') then
      begin
        Result := Result + RunGraph(C.DiskName + '_coll_graph',
          Format(Tr('Collaboration diagram for %s:'), [HtmlEscape(C.Name)]), FDot.ClassDot(C, True));
        Break;
      end;
end;

// "Here is the call graph for this function:" and the caller graph, when the routine has any.
function THtmlGenerator.MemberGraphs(M: TMemberDef): string;
begin
  Result := '';
  if not FDotGraphs or (FCalls = nil) or (M.Kind <> memFunction) then
    Exit;
  if FConfig.GetBool('CALL_GRAPH') and (FCalls.CallsOf(M) <> nil) then
    Result := RunGraph(M.DiskName + '_cgraph', Tr('Here is the call graph for this function:'), FDot.CallDot(M, False));
  if FConfig.GetBool('CALLER_GRAPH') and (FCalls.CallersOf(M) <> nil) then
    Result := Result + RunGraph(M.DiskName + '_icgraph', Tr('Here is the caller graph for this function:'),
      FDot.CallDot(M, True));
end;

// The dependency graphs of a unit: what it uses and what uses it.
function THtmlGenerator.UnitGraph(U: TUnitDef): string;
var
  T: TUnitDef;
  Used: Boolean;
begin
  Result := '';
  if not FDotGraphs then
    Exit;
  if FConfig.GetBool('INCLUDE_GRAPH') and LayoutShows('file', 'includegraph') and (U.UsesInterfaceNames.Count > 0) then
    Result := RunGraph(U.DiskName + '_uses_graph', Format(Tr('Dependency graph for %s:'), [HtmlEscape(U.Name)]),
      FDot.UnitDot(U, False));
  Used := False;
  for T in U.UsedBy do
    if FLinks.IsLinkable(T) then
      Used := True;
  if Used and FConfig.GetBool('INCLUDED_BY_GRAPH') and LayoutShows('file', 'includedbygraph') then
    Result := Result + RunGraph(U.DiskName + '_used_by_graph',
      Format(Tr('This graph shows which units directly or indirectly use this unit (%s):'), [HtmlEscape(U.Name)]),
      FDot.UnitDot(U, True));
end;

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
    Title := NavTitle('mainpage');
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
  Text, Brief, Detail, List, NestedTitle: string;
  HasDetail, ShowNested: Boolean;
  E: TLayoutEntry;
  T0: Int64;
begin
  ShowNested := True;
  NestedTitle := Tr('Classes');
  E := LayoutMembers(False, 'memberdecl');
  if E <> nil then
  begin
    E := E.Child('nestedclasses');
    ShowNested := (E <> nil) and FLayout.Visible(E);
    if ShowNested and (E.Attr('title') <> '') then
      NestedTitle := E.Attr('title');
  end;
  Vis := VisibleMembers(C.Members);
  Rows := TStringBuilder.Create;
  Summary := TStringBuilder.Create;
  try
    T0 := Tick;
    Detail := DetailedBlock(C, True);
    Add('class: DetailedBlock', T0);
    T0 := Tick;
    Brief := BriefOf(C);
    Add('class: BriefOf', T0);
    if not LayoutShows('class', 'briefdescription') then
      Brief := '';
    // nested classes
    List := '';
    if ShowNested then
    for N in C.NestedClasses do
      if FLinks.IsLinkable(N) then
        List := List + '<tr class="memitem:' + N.DiskName + '"><td class="memItemLeft" align="right" valign="top">' +
          LowerCase(Tr(ClassKindText(N))) + '&#160;</td><td class="memItemRight" valign="bottom">' + FDoc.Link(N, N.Name) +
          '</td></tr>'#10'<tr class="separator:' + N.DiskName +
          '"><td class="memSeparator" colspan="2">&#160;</td></tr>'#10;
    if List <> '' then
    begin
      Rows.Append('<tr class="heading"><td colspan="2"><h2 class="groupheader"><a id="nested-classes" name="nested-classes"></a>'#10 +
        HtmlEscape(NestedTitle) + '</h2></td></tr>'#10).Append(List);
      Summary.Append('<a href="#nested-classes">' + HtmlEscape(NestedTitle) + '</a>');
    end;
    T0 := Tick;
    DeclSections(Vis, False, Rows, Summary);
    Add('class: DeclSections', T0);
    T0 := Tick;
    InheritedSections(C, Rows);
    Add('class: InheritedSections', T0);
    if Detail <> '' then
    begin
      if Summary.Length > 0 then
        Summary.Append(' &#124;'#10);
      Summary.Append('<a href="#details">' + HtmlEscape(DetailTitle(C)) + '</a>');
    end;
    BeginPage(C.DiskName, ClassTitle(C), C.DiskName + '-members' + FExt);
    PageHeader(ClassTitle(C), Summary.ToString);
    HasDetail := Trim(C.Detailed) <> '';
    if Brief <> '' then
    begin
      W('<p>' + Brief);
      if HasDetail then
        W(' <a href="#details">' + HtmlEscape(Tr('More...')) + '</a>');
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
    if LayoutShows('class', 'allmemberslink') then
      W('<p><a href="' + C.DiskName + '-members' + FExt + '">' + HtmlEscape(Tr('List of all members')) + '</a></p>'#10);
    if Rows.Length > 0 then
      W('<table class="memberdecls">'#10 + Rows.ToString + '</table>'#10);
    W(Detail);
    T0 := Tick;
    W(DocSections(Vis, False));
    if FShowUsedFiles and LayoutShows('class', 'usedfiles') and (C.Entry <> nil) and (C.Entry.FileName <> '') then
      W('<hr/>The documentation for this class was generated from the following file:'#10'<ul>'#10'<li>' +
        HtmlEscape(FProject.OutputPath(C.Entry.FileName)) + '</li>'#10'</ul>'#10);
    Add('class: DocSections', T0);
    T0 := Tick;
    EndPage(NavPathOf(C));
    Add('class: EndPage', T0);
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
  Detail, Brief, Uses_, S, ClassesTitle: string;
  T: TUnitDef;
  HasClasses, ShowClasses, ShowIncludes: Boolean;
  E: TLayoutEntry;
begin
  ShowClasses := True;
  ClassesTitle := Tr('Classes');
  E := LayoutMembers(True, 'memberdecl');
  if E <> nil then
  begin
    E := E.Child('classes');
    ShowClasses := (E <> nil) and FLayout.Visible(E);
    if ShowClasses and (E.Attr('title') <> '') then
      ClassesTitle := E.Attr('title');
  end;
  Vis := VisibleMembers(U.Members);
  Rows := TStringBuilder.Create;
  Summary := TStringBuilder.Create;
  try
    HasClasses := False;
    for C in U.Classes do
      if ShowClasses and FLinks.IsLinkable(C) and (C.Scope = U) then
      begin
        if not HasClasses then
        begin
          Rows.Append('<tr class="heading"><td colspan="2"><h2 class="groupheader"><a id="nested-classes" name="nested-classes"></a>'#10 +
            HtmlEscape(ClassesTitle) + '</h2></td></tr>'#10);
          Summary.Append('<a href="#nested-classes">' + HtmlEscape(ClassesTitle) + '</a>');
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
      Summary.Append('<a href="#details">' + HtmlEscape(DetailTitle(U)) + '</a>');
    end;
    BeginPage(U.DiskName, UnitTitle(U));
    PageHeader(UnitTitle(U), Summary.ToString);
    Brief := BriefOf(U);
    if (Brief <> '') and LayoutShows('namespace', 'briefdescription') and LayoutShows('file', 'briefdescription') then
    begin
      W('<p>' + Brief);
      if Trim(U.Detailed) <> '' then
        W(' <a href="#details">More...</a>');
      W('</p>'#10);
    end;
    // the uses clauses are the includes of a unit: SHOW_INCLUDE_FILES when there is no layout of files
    ShowIncludes := LayoutShows('file', 'includes') and ((FLayout.Page('file') <> nil) or FConfig.GetBool('SHOW_INCLUDE_FILES'));
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
    if (Uses_ <> '') and ShowIncludes then
      W('<p>' + Tr('Uses') + ': ' + Uses_ + '</p>'#10);
    Uses_ := '';
    for T in U.UsedBy do
      if FLinks.IsLinkable(T) then
      begin
        if Uses_ <> '' then
          Uses_ := Uses_ + ', ';
        Uses_ := Uses_ + FDoc.Link(T, T.Name);
      end;
    if (Uses_ <> '') and ShowIncludes then
      W('<p>' + Tr('Used by') + ': ' + Uses_ + '</p>'#10);
    if HasSource(U) and LayoutShows('file', 'sourcelink') then
      W('<p><a href="' + SourceUrl(U) + '">' + Tr('Go to the source code of this file.') + '</a></p>'#10);
    W(UnitGraph(U));
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

function THtmlGenerator.HasSource(U: TUnitDef): Boolean;
begin
  Result := FSource and FLinks.IsLinkable(U) and (U.FileName <> '') and TFile.Exists(U.FileName);
end;

function THtmlGenerator.SourceUrl(U: TUnitDef): string;
begin
  Result := U.DiskName + '_source' + FExt;
end;

// The URL an identifier of AScope's code links to; the answers are cached.
function THtmlGenerator.WordLinker(AScope: TDefinition): TWordLinker;
begin
  Result :=
    function(const AWord: string): string
    var
      T: TLinkTarget;
      Key: string;
    begin
      Key := AWord + '|' + IntToStr(NativeInt(AScope));
      if not FWordCache.TryGetValue(Key, Result) then
      begin
        Result := '';
        T := FLinks.Resolve(AWord, AScope);
        if (T.Def <> nil) and (T.Def <> AScope) and FLinks.IsLinkable(T.Def) then
          Result := FDoc.DefUrl(T.Def);
        FWordCache.Add(Key, Result);
      end;
    end;
end;

// INLINE_SOURCES: the body of a routine, with the line numbers of its file, below its documentation.
function THtmlGenerator.InlineSource(M: TMemberDef): string;
var
  F: string;
  First, Last, K: Integer;
  All: TArray<string>;
  SB: TStringBuilder;
begin
  Result := '';
  if (FBodies = nil) or not FInline or (M.Kind <> memFunction) or not FBodies.Find(M, F, First, Last) then
    Exit;
  All := FBodies.Lines(F);
  SB := TStringBuilder.Create;
  try
    for K := First to Last do
      SB.Append(All[K - 1]).Append(#10);
    Result := '<div class="fragment">' + HighlightSource(SB.ToString, True, WordLinker(M), First,
      FConfig.GetBool('STRIP_CODE_COMMENTS')) + '</div>'#10;
  finally
    SB.Free;
  end;
end;

// A member in a References / Referenced by list: with REFERENCES_LINK_SOURCE (and SOURCE_BROWSER) the link goes to its
// line in the source page, otherwise to its documentation.
function THtmlGenerator.RelationLink(X: TMemberDef; const AText: string): string;
var
  U: TUnitDef;
  B: TEntry;
begin
  U := X.OwnerUnit;
  B := X.Impl;
  if B = nil then
    B := X.Entry;
  if FConfig.GetBool('REFERENCES_LINK_SOURCE') and (U <> nil) and HasSource(U) and (B <> nil) and
    SameText(B.FileName, U.FileName) then
    Result := '<a class="el" href="' + SourceUrl(U) + '#l' + Format('%.5d', [B.Line]) + '">' + HtmlEscape(AText) + '</a>'
  else
    Result := FDoc.Link(X, AText);
end;

// REFERENCES_RELATION / REFERENCED_BY_RELATION: "References a, b." and "Referenced by x, y." below a member.
function THtmlGenerator.Relations(M: TMemberDef): string;

  function Names(AList: TList<TMemberDef>): string;
  var
    Sorted: TList<TMemberDef>;
    X: TMemberDef;
    Text: string;
  begin
    Result := '';
    Sorted := TList<TMemberDef>.Create(AList);
    try
      Sorted.Sort(TComparer<TMemberDef>.Construct(
        function(const A, B: TMemberDef): Integer
        begin
          Result := CompareText(A.QualifiedName, B.QualifiedName);
        end));
      for X in Sorted do
      begin
        Text := X.Name;
        if X.Scope is TClassDef then
          Text := X.Scope.Name + '.' + Text;
        if Result <> '' then
          Result := Result + ', ';
        Result := Result + RelationLink(X, Text);
      end;
    finally
      Sorted.Free;
    end;
  end;

var
  L: TList<TMemberDef>;
begin
  Result := '';
  if FCalls = nil then
    Exit;
  if FConfig.GetBool('REFERENCES_RELATION') then
  begin
    L := FCalls.ReferencesOf(M);
    if L <> nil then
      Result := '<p>' + Tr('References') + ' ' + Names(L) + '.</p>'#10;
  end;
  if FConfig.GetBool('REFERENCED_BY_RELATION') then
  begin
    L := FCalls.ReferencedBy(M);
    if L <> nil then
      Result := Result + '<p>' + Tr('Referenced by') + ' ' + Names(L) + '.</p>'#10;
  end;
end;
// Doxygen's "source file" page: the unit's text with line numbers and links from identifiers to their pages.
procedure THtmlGenerator.WriteSource(U: TUnitDef);
var
  Name: string;
begin
  Name := ExtractFileName(FProject.OutputPath(U.FileName));
  BeginPage(U.DiskName + '_source', Name);
  PageHeader(Name);
  W('<div class="fragment">' + HighlightSource(ReadSourceText(U.FileName), True, WordLinker(U), 1,
    FConfig.GetBool('STRIP_CODE_COMMENTS')) + '</div>'#10);
  EndPage(NavPathOf(U));
end;
{ ------------------------------------------------------------------ directories }

const
  FolderIcon = '<span class="iconfolder"><div class="folder-icon"></div></span>';

function THtmlGenerator.DirNavPath(D: TDirDef): string;
begin
  Result := '';
  while D <> nil do
  begin
    Result := '<li class="navelem"><a class="el" href="' + D.DiskName + FExt + '">' + HtmlEscape(D.Name) + '</a></li>' +
      Result;
    D := D.Parent;
  end;
end;

// The directory dependency graph: the directory, the ones its units use and the ones that use it; the edges say how
// many units are involved.
function THtmlGenerator.DirDot(D: TDirDef): string;
var
  G: TDotBuilder;
  Root: Integer;
  Dep: TDirDependency;
begin
  G := TDotBuilder.Create(D.Path, FConfig.GetInt('DOT_GRAPH_MAX_NODES'), 'TB');
  try
    Root := G.Node(D.DiskName, D.Name, '', ', fillcolor="#bfbfbf"');
    for Dep in FDirs.Dependencies(D, False) do
      if not G.Full then
        G.Edge(Root, G.Node(Dep.Dir.DiskName, Dep.Dir.Name, Dep.Dir.DiskName + FExt, ''),
          'color="midnightblue", arrowhead="open", label=' + DotQuote(IntToStr(Dep.Count)));
    for Dep in FDirs.Dependencies(D, True) do
      if not G.Full then
        G.Edge(G.Node(Dep.Dir.DiskName, Dep.Dir.Name, Dep.Dir.DiskName + FExt, ''), Root,
          'color="midnightblue", arrowhead="open", label=' + DotQuote(IntToStr(Dep.Count)));
    Result := G.Finish;
  finally
    G.Free;
  end;
end;

// The rows of the subdirectories (ADirs) or of the files of a directory under one heading; nothing when there are none.
function THtmlGenerator.DirTable(D: TDirDef; const AHeading: string; ADirs: Boolean): string;
var
  Sub: TDirDef;
  U: TUnitDef;
begin
  Result := '';
  if ADirs and (D.Dirs.Count > 0) then
  begin
    Result := '<tr class="heading"><td colspan="2"><h2 class="groupheader"><a id="subdirs" name="subdirs"></a>'#10 +
      HtmlEscape(AHeading) + '</h2></td></tr>'#10;
    for Sub in D.Dirs do
      Result := Result + '<tr class="memitem:' + Sub.DiskName + '"><td class="memItemLeft" align="right" valign="top">' + FolderIcon +
        '&#160;</td><td class="memItemRight" valign="bottom"><a class="el" href="' + Sub.DiskName + FExt + '">' +
        HtmlEscape(Sub.Name) + '</a></td></tr>'#10'<tr class="separator:' + Sub.DiskName +
        '"><td class="memSeparator" colspan="2">&#160;</td></tr>'#10;
  end;
  if not ADirs and (D.Units.Count > 0) then
  begin
    Result := '<tr class="heading"><td colspan="2"><h2 class="groupheader"><a id="files" name="files"></a>'#10 +
      HtmlEscape(AHeading) + '</h2></td></tr>'#10;
    for U in D.Units do
      Result := Result + '<tr class="memitem:' + U.DiskName + '"><td class="memItemLeft" align="right" valign="top">' +
        '<span class="icondoc"><div class="doc-icon"></div></span>&#160;</td>' +
        '<td class="memItemRight" valign="bottom">' + FDoc.Link(U, ExtractFileName(U.FileName)) + '</td></tr>'#10 +
        '<tr class="separator:' + U.DiskName + '"><td class="memSeparator" colspan="2">&#160;</td></tr>'#10;
  end;
end;

procedure THtmlGenerator.WriteDirectory(D: TDirDef);
var
  Title, Graph, Tables: string;
  MD, E: TLayoutEntry;

  function Pick(const AText, ADefault: string): string;
  begin
    if AText <> '' then Result := AText else Result := ADefault;
  end;

begin
  Title := Format(Tr('%s Directory Reference'), [D.Path]);
  Graph := '';
  if FDotGraphs and FConfig.GetBool('DIRECTORY_GRAPH') and
    LayoutShows('directory', 'directorygraph') and
    ((Length(FDirs.Dependencies(D, False)) > 0) or (Length(FDirs.Dependencies(D, True)) > 0)) then
    Graph := RunGraph(D.DiskName + '_dep', Format(Tr('Directory dependency graph for %s:'), [HtmlEscape(D.Name)]),
      DirDot(D));
  BeginPage(D.DiskName, Title);
  PageHeader(Title);
  W(Graph);
  Tables := '';
  MD := LayoutElement('directory', 'memberdecl');
  if MD = nil then
  begin
    Tables := DirTable(D, Tr('Directories'), True) + DirTable(D, Tr('Files'), False);
  end
  else
    for E in MD.Children do
      if FLayout.Visible(E) then
      begin
        Title := E.Attr('title');
        if E.Name = 'dirs' then
          Tables := Tables + DirTable(D, Pick(Title, Tr('Directories')), True)
        else if E.Name = 'files' then
          Tables := Tables + DirTable(D, Pick(Title, Tr('Files')), False);
      end;
  if Tables <> '' then
    W('<table class="memberdecls">'#10 + Tables + '</table>'#10);  EndPage(DirNavPath(D));
end;

procedure THtmlGenerator.DirTreeRows(D: TDirDef; ALevel: Integer; var ARow: Integer);
var
  Sub: TDirDef;
  U: TUnitDef;
begin
  DirRow(ARow, ALevel, FolderIcon, '<a class="el" href="' + D.DiskName + FExt + '">' + HtmlEscape(D.Name) + '</a>', '');
  for Sub in D.Dirs do
    DirTreeRows(Sub, ALevel + 1, ARow);
  for U in D.Units do
    DirRow(ARow, ALevel + 1, '<span class="icondoc"><div class="doc-icon"></div></span>',
      FDoc.Link(U, ExtractFileName(U.FileName)), BriefOf(U));
end;

procedure THtmlGenerator.WriteDirsIndex;
var
  Row: Integer;
begin
  BeginPage('dirs', NavTitle('filelist'));
  PageHeader(NavTitle('filelist'));
  W('<div class="textblock">' + NavIntro('filelist', 'Here is the directory hierarchy of the source files:') + '</div>'#10 +
    '<div class="directory">'#10'<table class="directory">'#10);
  Row := 0;
  DirTreeRows(FDirs.Root, 0, Row);
  W('</table>'#10'</div><!-- directory -->'#10);
  EndPage;
end;
procedure THtmlGenerator.WriteGroup(G: TGroupDef);
var
  Rows, Summary: TStringBuilder;
  Mem: TList<TMemberDef>;
  D: TDefinition;
  Detail, Brief, Key, Title: string;
  MD, E: TLayoutEntry;

  function Pick(const AText, ADefault: string): string;
  begin
    if AText <> '' then Result := AText else Result := ADefault;
  end;

  procedure AddTopics(const AHeading: string);
  var
    S: TGroupDef;
  begin
    if G.Subgroups.Count = 0 then
      Exit;
    Rows.Append('<tr class="heading"><td colspan="2"><h2 class="groupheader">' + HtmlEscape(AHeading) + '</h2></td></tr>'#10);
    for S in G.Subgroups do
      Rows.Append('<tr class="memitem:' + S.DiskName + '"><td class="memItemLeft" align="right" valign="top">&#160;</td>' +
        '<td class="memItemRight" valign="bottom">' + FDoc.Link(S, S.Title) + '</td></tr>'#10);
  end;

  // The classes and/or the units of the group under one heading.
  procedure AddCompounds(const AHeading: string; AUnits, AClasses: Boolean);
  var
    Any: Boolean;
    D: TDefinition;
  begin
    Any := False;
    for D in G.Members do
      if ((D is TClassDef) and AClasses) or ((D is TUnitDef) and AUnits) then
        if FLinks.IsLinkable(D) then
        begin
          if not Any then
          begin
            Rows.Append('<tr class="heading"><td colspan="2"><h2 class="groupheader">' + HtmlEscape(AHeading) + '</h2></td></tr>'#10);
            Any := True;
          end;
          Rows.Append('<tr class="memitem:' + D.DiskName + '"><td class="memItemLeft" align="right" valign="top">&#160;</td>' +
            '<td class="memItemRight" valign="bottom">' + FDoc.Link(D, D.QualifiedName) + '</td></tr>'#10);
        end;
  end;

begin
  Rows := TStringBuilder.Create;
  Summary := TStringBuilder.Create;
  Mem := TList<TMemberDef>.Create;
  FPageLayout := 'group';             // the tables of members follow the layout of the groups
  try
    for D in G.Members do
      if (D is TMemberDef) and FProject.IsVisible(D) then
        Mem.Add(TMemberDef(D));
    MD := LayoutMembers(True, 'memberdecl');
    if MD = nil then
    begin
      AddTopics('Topics');
      AddCompounds('Classes and Units', True, True);
      DeclSections(Mem, True, Rows, Summary);
    end
    else
      for E in MD.Children do
        if FLayout.Visible(E) then
        begin
          Title := E.Attr('title');
          if E.Name = 'nestedgroups' then
            AddTopics(Pick(Title, 'Topics'))
          else if E.Name = 'namespaces' then
            AddCompounds(Pick(Title, 'Units'), True, False)
          else if E.Name = 'classes' then
            AddCompounds(Pick(Title, Tr('Classes')), False, True)
          else
          begin
            Key := DeclKeyOf(E.Name, True);
            if Key <> '' then
              DeclSection(Mem, True, Key, Rows, Summary);
          end;
        end;
    Detail := DetailedBlock(G, True);
    if Detail <> '' then
    begin
      if Summary.Length > 0 then
        Summary.Append(' &#124;'#10);
      Summary.Append('<a href="#details">' + HtmlEscape(DetailTitle(G)) + '</a>');
    end;
    BeginPage(G.DiskName, G.Title);
    PageHeader(G.Title, Summary.ToString);
    Brief := BriefOf(G);
    if (Brief <> '') and LayoutShows('group', 'briefdescription') then
    begin
      W('<p>' + Brief);
      if (Trim(G.Detailed) <> '') and (Detail <> '') then
        W(' <a href="#details">' + Tr('More...') + '</a>');
      W('</p>'#10);
    end;
    if Rows.Length > 0 then
      W('<table class="memberdecls">'#10 + Rows.ToString + '</table>'#10);
    W(Detail);
    W(DocSections(Mem, True));
    EndPage;
  finally
    FPageLayout := '';
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
    BeginPage('annotated', NavTitle('classlist'));
    PageHeader(NavTitle('classlist'));
    W('<div class="textblock">' + NavIntro('classlist', 'Here are the classes, records and interfaces with brief descriptions:') + '</div><div class="directory">'#10 +
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

// The name as the index sorts it and puts it under a letter: without the first of the prefixes of IGNORE_PREFIX that it has.
// A prefix of one letter (T, I, E: the ones of the types of Pascal) is taken out only before an upper case letter, so that
// TButton is under B but Table stays under T.
function THtmlGenerator.IndexName(const AName: string): string;
var
  P: string;
begin
  for P in FIgnorePrefix do
    if (P <> '') and (Length(AName) > Length(P)) and AName.StartsWith(P) then
      if (Length(P) > 1) or TCharacter.IsUpper(AName[Length(P) + 1]) then
        Exit(Copy(AName, Length(P) + 1, MaxInt));
  Result := AName;
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
        if FSortByScope then
          Result := CompareText(A.QualifiedName, B.QualifiedName)
        else
          Result := CompareText(IndexName(A.Name), IndexName(B.Name));
        if Result = 0 then
          Result := CompareText(A.Name, B.Name);
        if Result = 0 then
          Result := CompareText(A.QualifiedName, B.QualifiedName);
      end));
    BeginPage('classes', NavTitle('classindex'));
    PageHeader(NavTitle('classindex'));
    W('<div class="classindex">'#10);
    Cur := '';
    Row := 0;
    for C in Sorted do
    begin
      Letter := UpperCase(Copy(IndexName(C.Name), 1, 1));
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
    BeginPage('hierarchy', NavTitle('hierarchy'));
    PageHeader(NavTitle('hierarchy'));
    W('<div class="textblock">' + NavIntro('hierarchy', 'This inheritance list is sorted roughly, but not completely, alphabetically:') + '</div>'#10 +
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
  BeginPage('namespaces', NavTitle('namespacelist'));
  PageHeader(NavTitle('namespacelist'));
  W('<div class="textblock">' + NavIntro('namespacelist', 'Here is a list of all documented units with brief descriptions:') + '</div>'#10 +
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
    BeginPage('topics', NavTitle('topics'));
    PageHeader(NavTitle('topics'));
    W('<div class="textblock">' + NavIntro('topics', 'Here is a list of all topics with brief descriptions:') + '</div>'#10 +
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
  BeginPage('pages', NavTitle('pages'));
  PageHeader(NavTitle('pages'));
  W('<div class="textblock">' + NavIntro('pages', 'Here is a list of all related documentation pages:') + '</div>'#10 +
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
    BeginPage('functions', NavTitle('classmembers'));
    PageHeader(NavTitle('classmembers'));
    W('<div class="textblock">' + NavIntro('classmembers', 'Here is a list of all documented class members with links to the class documentation for each member:') + '</div>'#10);
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
  if FDynMenus then
    SaveText('tabs.css', ApplyColorStyle(HtmlResourceText('tabs.css'), FColors, FLight, FDark))
  else
    SaveText('tabs.css', ApplyColorStyle(HtmlResourceText('fixed_tabs.css'), FColors, FLight, FDark));
  SaveText('navtree.css', ApplyColorStyle(HtmlResourceText('navtree.css'), FColors, FLight, FDark));
  if FDynMenus and not FNoIndex then
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
    else if not FDynMenus then Css := HtmlResourceText('search_fixedtabs.css')
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

  procedure Items(AItems: TObjectList<TNavNode>);
  var
    I: Integer;
    N: TNavNode;
  begin
    for I := 0 to AItems.Count - 1 do
    begin
      N := AItems[I];
      if I > 0 then
        SB.Append(','#10);
      SB.Append('{text:"' + JsString(N.Name) + '",url:"' + JsString(TabHref(N.Url)) + '"');
      if N.Kids.Count > 0 then
      begin
        SB.Append(',children:['#10);
        Items(N.Kids);
        SB.Append(']');
      end;
      SB.Append('}');
    end;
  end;

begin
  if FNoIndex or not FDynMenus then
    Exit;
  if FMenu = nil then
    BuildMenu;
  SB := TStringBuilder.Create;
  try
    SB.Append(LicenseText).Append('var menudata={children:['#10);
    Items(FMenu.Kids);
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
  Topics, Units, Classes, List, Node, Dirs: TNavNode;

  procedure AddDir(AParent: TNavNode; ADir: TDirDef);
  var
    N: TNavNode;
    S: TDirDef;
    X: TUnitDef;
  begin
    N := AParent.Add(ADir.Name, Url(ADir.DiskName));
    for S in ADir.Dirs do
      AddDir(N, S);
    for X in ADir.Units do
      N.Add(ExtractFileName(X.FileName), Url(X.DiskName));
  end;

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

  // LAYOUT_FILE: the tree follows the navigation index: the order of the tabs, the ones that are not visible are left
  // out, the user tabs are added, and the entries of the Classes tab are in the order of its sub-tabs.
  procedure Reorder;
  var
    Old: TList<TNavNode>;
    Used: TList<TNavNode>;
    Tab, Sub, N: TNavNode;
    Kids: TList<TNavNode>;
    I: Integer;
    Base: string;

    procedure Take(ANode: TNavNode);
    begin
      if (ANode <> nil) and Old.Contains(ANode) and not Used.Contains(ANode) then
      begin
        Used.Add(ANode);
        FNav.Add(ANode);
      end;
    end;

  begin
    if FMenu = nil then
      BuildMenu;
    Old := TList<TNavNode>.Create;
    Used := TList<TNavNode>.Create;
    try
      for N in FNav do
        Old.Add(N);
      FNav.OwnsObjects := False;
      FNav.Clear;
      FNav.OwnsObjects := True;
      for Tab in FMenu.Kids do
      begin
        Base := Tab.Url;
        if Base = 'pages' then
        begin
          for N in Old do
            if (N <> Topics) and (N <> Units) and (N <> Dirs) and (N <> Classes) then
              Take(N);
        end
        else if Base = 'topics' then Take(Topics)
        else if Base = 'namespaces' then Take(Units)
        else if Base = 'dirs' then Take(Dirs)
        else if Base = 'annotated' then
        begin
          if Classes <> nil then
          begin
            Kids := TList<TNavNode>.Create;
            try
              for I := 0 to Classes.Kids.Count - 1 do
                Kids.Add(Classes.Kids[I]);
              Classes.Kids.OwnsObjects := False;
              Classes.Kids.Clear;
              Classes.Kids.OwnsObjects := True;
              for Sub in Tab.Kids do
                for N in Kids do
                  if N.Url = Url(Sub.Url) then
                    Classes.Kids.Add(N);
              for N in Kids do
                if not Classes.Kids.Contains(N) then
                  N.Free;
            finally
              Kids.Free;
            end;
            Take(Classes);
          end;
        end
        else if (Pos('.', Base) > 0) or (Pos(':', Base) > 0) then
        begin
          N := TNavNode.Create(Tab.Name, Base);
          for Sub in Tab.Kids do
            N.Add(Sub.Name, Sub.Url);
          FNav.Add(N);
        end;
      end;
      for N in Old do
        if not Used.Contains(N) then
          N.Free;
    finally
      Used.Free;
      Old.Free;
    end;
  end;

begin
  Topics := nil;
  Units := nil;
  Dirs := nil;
  Classes := nil;  for P in FProject.Pages do
    if not P.IsMainPage then
      FNav.Add(TNavNode.Create(P.Title, Url(P.DiskName)));
  if FHasGroups then
  begin
    Topics := TNavNode.Create(NavTitle('topics'), Url('topics'));
    FNav.Add(Topics);
    for G in FProject.Groups do
      if G.Parent = nil then
        AddGroup(Topics, G);
  end;
  if FHasUnits then
  begin
    Units := TNavNode.Create(NavTitle('namespaces'), Url('namespaces'));
    FNav.Add(Units);
    for U in FProject.Units do
      if FLinks.IsLinkable(U) then
        Units.Add(U.Name, Url(U.DiskName));
  end;
  if FDirs <> nil then
  begin
    Dirs := TNavNode.Create(NavTitle('filelist'), Url('dirs'));
    FNav.Add(Dirs);
    AddDir(Dirs, FDirs.Root);
  end;
  if FHasClasses then
  begin
    Classes := TNavNode.Create(NavTitle('classes'), Url('annotated'));
    FNav.Add(Classes);
    List := Classes.Add(NavTitle('classlist'), Url('annotated'));
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
    if FAlphabeticalIndex then
      Classes.Add(NavTitle('classindex'), Url('classes'));
    Classes.Add(NavTitle('hierarchy'), Url('hierarchy'));
    Classes.Add(NavTitle('classmembers'), Url('functions'));
  end;
  if FLayout.NavIndex <> nil then
    Reorder;
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
  D: TDirDef;
  T0: Int64;
begin
  TDirectory.CreateDirectory(FDir);
  if FDotGraphs and not FRunner.Available then
  begin
    FDotGraphs := False;
    Warn('', 0, 'HAVE_DOT = YES, but dot could not be run (set DOT_PATH or put Graphviz on the PATH): no graphs');
  end;
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
  if FHasUnits and FConfig.GetBool('SHOW_FILES') then
  begin
    FDirs := TDirTree.Create(FProject, FLinks);
    if FDirs.Root = nil then
      FreeAndNil(FDirs);
  end;
  // formulas: MathJax (USE_MATHJAX) or SVG images from latex + dvisvgm, MathJax when they are not available
  if FConfig.GetBool('USE_MATHJAX') then
    FMathJax := MathJaxScript
  else if RunTool('latex --version', FDir) and RunTool('dvisvgm --version', FDir) then
    FDoc.ImageFormulas := True
  else
  begin
    FMathJax := MathJaxScript;
    Warn('', 0, 'latex or dvisvgm not found: the formulas are shown with MathJax (set USE_MATHJAX = YES to silence this)');
  end;
  BuildPageMenu;
  WriteStatic;
  WriteMainPage;
  Lap('html: static + main page');
  for C in FProject.Classes do
    if FLinks.IsLinkable(C) then
    begin
      T0 := Tick;
      WriteClass(C);
      Add('WriteClass (all)', T0);
      T0 := Tick;
      WriteMembersPage(C);
      Add('WriteMembersPage', T0);
    end;
  Lap('html: class pages');
  for U in FProject.Units do
    if FLinks.IsLinkable(U) then
    begin
      WriteUnit(U);
      if HasSource(U) then
        WriteSource(U);
    end;
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
  if FDirs <> nil then
  begin
    WriteDirsIndex;
    for D in FDirs.All do
      WriteDirectory(D);
  end;
  if FHasClasses then
  begin
    WriteAnnotated;
    WriteClassIndex;
    WriteHierarchy;
    WriteFunctionsIndex;
  end;
  Lap('html: units, groups, pages, indices');
  WriteMenuData;
  WriteNavTree;
  Lap('html: menu + navigation tree');
  WriteSearchData;
  Lap('html: search data');
  FlushGraphs;
  if FDoc.ImageFormulas then
    WriteFormulas;
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
