unit DoxyPas.Output.LatexGen;

{ LaTeX output (a reduced form of Doxygen's latexgen): refman.tex with one chapter per unit, class, group and page;
  members are subsections. Build it with pdflatex (twice for the table of contents). Not covered: graphs, the
  Doxygen LaTeX style package, source listings, formulas. }

interface

uses
  DoxyPas.Config,
  DoxyPas.Model.Project;

/// <summary>Writes refman.tex and the chapter files into AOutDir. Returns the number of files written.</summary>
function GenerateLatex(AProject: TProject; AConfig: TConfig; const AOutDir: string): Integer;

function LatexEscape(const S: string): string;

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
  DoxyPas.Model.Links;

function LatexEscape(const S: string): string;
var
  C: Char;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    for C in S do
      case C of
        '\': SB.Append('\textbackslash{}');
        '{', '}', '$', '&', '#', '_', '%': SB.Append('\').Append(C);
        '~': SB.Append('\textasciitilde{}');
        '^': SB.Append('\textasciicircum{}');
        '<': SB.Append('\textless{}');
        '>': SB.Append('\textgreater{}');
        '|': SB.Append('\textbar{}');
        #$D800..#$DBFF: SB.Append('?');   // emoji and the like: not available in pdflatex's T1 fonts
        #$DC00..#$DFFF: ;
        #$0180..#$200F, #$2023..#$2025, #$2027..#$20AB, #$20AD..#$D7FF, #$E000..#$FFFF: SB.Append('?');
      else
        SB.Append(C);
      end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

type
  TLatexGenerator = class
  strict private
    FProject: TProject;
    FConfig: TConfig;
    FLinks: TLinkResolver;
    FDir: string;
    FFiles: Integer;
    function Inline_(ANode: TDocNode): string;
    function Children_(ANode: TDocNode): string;
    function Block(ANode: TDocNode): string;
    function Paras(ANode: TDocNode): string;
    function Section(ANode: TDocNode; ALevel: Integer): string;
    function Render(const AText: string): string;
    function LabelOf(ADef: TDefinition): string;
    function MemberText(M: TMemberDef): string;
    function Visible(AList: TList<TMemberDef>): TList<TMemberDef>;
    function Summary(AList: TList<TMemberDef>; AInClass: Boolean): string;
    function Members(AList: TList<TMemberDef>; const AParent: string): string;
    function Chapter(ADef: TDefinition; const ATitle: string): string;
    function ClassKind(C: TClassDef): string;
    function ClassChapter(C: TClassDef): string;
    function UnitChapter(U: TUnitDef): string;
    procedure Save(const AName, AText: string);
  public
    constructor Create(AProject: TProject; AConfig: TConfig; const ADir: string);
    destructor Destroy; override;
    function Run: Integer;
  end;

constructor TLatexGenerator.Create(AProject: TProject; AConfig: TConfig; const ADir: string);
begin
  inherited Create;
  FProject := AProject;
  FConfig := AConfig;
  FDir := ADir;
  FLinks := TLinkResolver.Create(AProject);
end;

destructor TLatexGenerator.Destroy;
begin
  FLinks.Free;
  inherited;
end;

procedure TLatexGenerator.Save(const AName, AText: string);
begin
  TFile.WriteAllText(TPath.Combine(FDir, AName), AText, TUTF8Encoding.Create(False));
  Inc(FFiles);
end;

function TLatexGenerator.LabelOf(ADef: TDefinition): string;
begin
  Result := 'dp:' + FLinks.RefIdOf(ADef).Replace('_', '-');
end;

function TLatexGenerator.Children_(ANode: TDocNode): string;
var
  C: TDocNode;
begin
  Result := '';
  for C in ANode.Children do
    Result := Result + Inline_(C);
end;

function TLatexGenerator.Inline_(ANode: TDocNode): string;
var
  T: TLinkTarget;
  Display: string;
begin
  Result := '';
  case ANode.Kind of
    dnText, dnSymbol: Result := LatexEscape(ANode.Text);
    dnStyle:
      if ANode.Name = 'b' then Result := '\textbf{' + Children_(ANode) + '}'
      else if (ANode.Name = 'i') or (ANode.Name = 'em') or (ANode.Name = 'var') then
        Result := '\emph{' + Children_(ANode) + '}'
      else if (ANode.Name = 'code') or (ANode.Name = 'kbd') or (ANode.Name = 'samp') then
        Result := '\texttt{' + Children_(ANode) + '}'
      else if ANode.Name = 'u' then Result := '\underline{' + Children_(ANode) + '}'
      else Result := Children_(ANode);
    dnUrl: Result := '\texttt{' + LatexEscape(ANode.Text) + '}';
    dnLink:
      if ANode.Name = 'href' then
        Result := Children_(ANode) + ' (\texttt{' + LatexEscape(ANode.Text) + '})'
      else
        Result := Children_(ANode);
    dnRef:
      begin
        Display := ANode.PlainText;
        if Display = '' then
          Display := ANode.Text;
        T := FLinks.Resolve(ANode.Text, nil);
        if T.Resolved and (T.Def <> nil) and not (T.Def is TMemberDef) then
          Result := '\hyperref[' + LabelOf(T.Def) + ']{' + LatexEscape(Display) + '}'
        else
          Result := LatexEscape(Display);
      end;
    dnLineBreak: Result := '\\'#10;
    dnFormula:
      if ANode.Name = 'inline' then Result := '$' + ANode.Text + '$'
      else Result := '\[' + ANode.Text + '\]';
    dnCite: Result := '[' + LatexEscape(ANode.Text) + ']';
  end;
end;

function TLatexGenerator.Block(ANode: TDocNode): string;
var
  Item, Row, Cell: TDocNode;
  Env, Title: string;
  Cols, I: Integer;
begin
  Result := '';
  case ANode.Kind of
    dnList:
      begin
        if ANode.Name = 'ol' then Env := 'enumerate' else Env := 'itemize';
        Result := '\begin{' + Env + '}'#10;
        for Item in ANode.Children do
          Result := Result + '\item ' + Paras(Item).Trim + #10;
        Result := Result + '\end{' + Env + '}'#10;
      end;
    dnTable:
      begin
        Cols := 1;
        for Row in ANode.Children do
          if Row.Children.Count > Cols then
            Cols := Row.Children.Count;
        Result := '\begin{longtable}{' + StringOfChar('l', Cols) + '}'#10'\hline'#10;
        for Row in ANode.Children do
        begin
          I := 0;
          for Cell in Row.Children do
          begin
            if I > 0 then
              Result := Result + ' & ';
            Result := Result + Paras(Cell).Trim.Replace(#10, ' ');
            Inc(I);
          end;
          Result := Result + ' \\'#10'\hline'#10;
        end;
        Result := Result + '\end{longtable}'#10;
      end;
    dnSimpleSect:
      begin
        if ANode.Name = 'par' then Title := ANode.Text
        else Title := UpCase(ANode.Name[1]) + Copy(ANode.Name, 2, MaxInt);
        Result := '\paragraph*{' + LatexEscape(Title) + '}'#10 + Paras(ANode);
      end;
    dnParamList:
      begin
        Result := '\begin{description}'#10;
        for Item in ANode.Children do
          Result := Result + '\item[' + LatexEscape(Item.Text.Replace(',', ', ')) + '] ' + Paras(Item).Trim + #10;
        Result := Result + '\end{description}'#10;
      end;
    dnBlockQuote: Result := '\begin{quote}'#10 + Paras(ANode) + '\end{quote}'#10;
    dnHeading: Result := '\paragraph*{' + Children_(ANode) + '}'#10;
    dnHRuler: Result := '\par\noindent\hrulefill\par'#10;
    dnVerbatim:
      if (ANode.Name = 'code') or (ANode.Name = 'verbatim') or (ANode.Name = 'pre') then
        Result := '\begin{Verbatim}[breaklines=true,breakanywhere=true]'#10 + ANode.Text.Replace('\end{Verbatim}', '') +
          #10'\end{Verbatim}'#10
      else if ANode.Name = 'latexonly' then
        Result := ANode.Text + #10;
  end;
end;

function TLatexGenerator.Paras(ANode: TDocNode): string;
var
  C, D: TDocNode;
  Buf: string;

  procedure Flush;
  begin
    if Trim(Buf) <> '' then
      Result := Result + Trim(Buf) + #10#10;
    Buf := '';
  end;

begin
  Result := '';
  for C in ANode.Children do
    if C.Kind = dnPara then
    begin
      Buf := '';
      for D in C.Children do
        if D.Kind in [dnList, dnTable, dnSimpleSect, dnParamList, dnBlockQuote, dnHeading, dnHRuler, dnVerbatim] then
        begin
          Flush;
          Result := Result + Block(D);
        end
        else
          Buf := Buf + Inline_(D);
      Flush;
    end;
end;

function TLatexGenerator.Section(ANode: TDocNode; ALevel: Integer): string;
var
  C: TDocNode;
  Cmd: string;
begin
  if ALevel <= 1 then Cmd := '\subsection*'
  else if ALevel = 2 then Cmd := '\subsubsection*'
  else Cmd := '\paragraph*';
  Result := Cmd + '{' + LatexEscape(ANode.Text) + '}'#10 + Paras(ANode);
  for C in ANode.Children do
    if C.Kind = dnSection then
      Result := Result + Section(C, ALevel + 1);
end;

function TLatexGenerator.Render(const AText: string): string;
var
  Root, C: TDocNode;
begin
  Result := '';
  if Trim(AText) = '' then
    Exit;
  Root := ParseDoc(AText);
  try
    Result := Paras(Root);
    for C in Root.Children do
      if C.Kind = dnSection then
        Result := Result + Section(C, 1);
  finally
    Root.Free;
  end;
end;

function TLatexGenerator.MemberText(M: TMemberDef): string;
var
  E: TEntry;
  A: TArgument;
  Args: string;
begin
  E := M.Entry;
  Result := M.Name;
  if E = nil then
    Exit;
  Args := '';
  for A in E.Args do
  begin
    if Args <> '' then
      Args := Args + '; ';
    Args := Args + Trim(A.Modifier + ' ' + A.Name + ': ' + A.TypeText);
  end;
  case M.Kind of
    memFunction:
      begin
        Result := M.Name;
        if Args <> '' then
          Result := Result + '(' + Args + ')';
        if E.TypeText <> '' then
          Result := Result + ': ' + E.TypeText;
      end;
    memProperty, memVariable, memConstant:
      begin
        if E.TypeText <> '' then
          Result := Result + ': ' + E.TypeText;
        if E.InitText <> '' then
          Result := Result + ' = ' + E.InitText;
      end;
    memTypedef:
      if E.TypeText <> '' then
        Result := Result + ' = ' + E.TypeText;
  end;
end;

function IndexEntry(const AName: string; const AParent: string = ''): string;
begin
  Result := '\index{';
  if AParent <> '' then
    Result := Result + LatexEscape(AParent) + '@\texttt{' + LatexEscape(AParent) + '}!';
  Result := Result + LatexEscape(AName) + '@\texttt{' + LatexEscape(AName) + '}}';
end;

// Doxygen's order of the sections of a class: by visibility, then types, constants, routines, fields, properties.
function GroupOrder(M: TMemberDef; AInClass: Boolean): Integer;
begin
  Result := 0;
  if AInClass then
    case M.Protection of
      prPublished: Result := 0;
      prPublic: Result := 10;
      prProtected: Result := 20;
      prStrictProtected: Result := 30;
      prPrivate: Result := 40;
      prStrictPrivate: Result := 50;
    end;
  case M.Kind of
    memTypedef, memEnumeration: Inc(Result, 0);
    memConstant: Inc(Result, 1);
    memFunction: Inc(Result, 2);
    memVariable: Inc(Result, 3);
    memProperty: Inc(Result, 4);
  end;
end;

function GroupTitle(AOrder: Integer; AInClass: Boolean): string;
const
  Prot: array[0..5] of string = ('Published', 'Public', 'Protected', 'Strict Protected', 'Private', 'Strict Private');
  KindsClass: array[0..4] of string = ('Types', 'Constants', 'Member Functions', 'Attributes', 'Properties');
  KindsUnit: array[0..4] of string = ('Types', 'Constants', 'Functions', 'Variables', 'Properties');
begin
  if AInClass then
    Result := Prot[AOrder div 10] + ' ' + KindsClass[AOrder mod 10]
  else
    Result := KindsUnit[AOrder mod 10];
end;

function TLatexGenerator.Visible(AList: TList<TMemberDef>): TList<TMemberDef>;
var
  M: TMemberDef;
begin
  Result := TList<TMemberDef>.Create;
  for M in AList do
    if (M.Kind <> memEnumValue) and FProject.IsVisible(M) and FLinks.IsLinkable(M) then
      Result.Add(M);
end;

// The overview tables: one list per group of members, each member with its signature and brief description.
function TLatexGenerator.Summary(AList: TList<TMemberDef>; AInClass: Boolean): string;
var
  Vis: TList<TMemberDef>;
  Orders: TList<Integer>;
  O: Integer;
  M: TMemberDef;
  Brief: string;
begin
  Result := '';
  Vis := Visible(AList);
  Orders := TList<Integer>.Create;
  try
    for M in Vis do
      if not Orders.Contains(GroupOrder(M, AInClass)) then
        Orders.Add(GroupOrder(M, AInClass));
    Orders.Sort;
    for O in Orders do
    begin
      Result := Result + '\subsection*{' + GroupTitle(O, AInClass) + '}'#10'\begin{DoxyCompactItemize}'#10;
      for M in Vis do
        if GroupOrder(M, AInClass) = O then
        begin
          Brief := Trim(Render(M.Brief).Replace(#10#10, ' ').Replace(#10, ' '));
          Result := Result + '\item \hyperref[' + LabelOf(M) + ']{\texttt{' + LatexEscape(MemberText(M)) + '}}';
          if Brief <> '' then
            Result := Result + '\\'#10'\hspace*{1em}' + Brief;
          Result := Result + #10;
        end;
      Result := Result + '\end{DoxyCompactItemize}'#10;
    end;
  finally
    Orders.Free;
    Vis.Free;
  end;
end;

function TLatexGenerator.Members(AList: TList<TMemberDef>; const AParent: string): string;
var
  Vis: TList<TMemberDef>;
  M: TMemberDef;
  Body: string;
begin
  Result := '';
  Vis := Visible(AList);
  try
    for M in Vis do
    begin
      Body := Render(M.Brief + #10#10 + M.Detailed);
      Result := Result + '\subsection*{' + LatexEscape(M.Name) + '}'#10'\label{' + LabelOf(M) + '}'#10 +
        IndexEntry(M.Name, AParent) + #10'\DoxyProto{' + LatexEscape(MemberText(M)) + '}'#10 + Body + #10;
    end;
  finally
    Vis.Free;
  end;
end;

function TLatexGenerator.Chapter(ADef: TDefinition; const ATitle: string): string;
begin
  Result := '\chapter{' + LatexEscape(ATitle) + '}'#10'\label{' + LabelOf(ADef) + '}'#10 +
    Render(ADef.Brief + #10#10 + ADef.Detailed);
end;

function TLatexGenerator.ClassChapter(C: TClassDef): string;
var
  B: TBaseRef;
  D: TClassDef;
  Text, Detail: string;
  Vis: TList<TMemberDef>;
begin
  Result := '\chapter{' + LatexEscape(C.QualifiedName) + ' ' + ClassKind(C) + ' Reference}'#10'\label{' + LabelOf(C) + '}'#10 +
    IndexEntry(C.Name) + #10;
  if Trim(C.Brief) <> '' then
    Result := Result + Render(C.Brief);
  Text := '';
  for B in C.Bases do
  begin
    if Text <> '' then
      Text := Text + ', ';
    if (B.ClassDef <> nil) and FLinks.IsLinkable(B.ClassDef) then
      Text := Text + '\hyperref[' + LabelOf(B.ClassDef) + ']{' + LatexEscape(B.Text) + '}'
    else
      Text := Text + LatexEscape(B.Text);
  end;
  if Text <> '' then
    Result := Result + '\noindent Inherits ' + Text + '.\par'#10;
  Text := '';
  for D in C.Derived do
    if FLinks.IsLinkable(D) then
    begin
      if Text <> '' then
        Text := Text + ', ';
      Text := Text + '\hyperref[' + LabelOf(D) + ']{' + LatexEscape(D.Name) + '}';
    end;
  if Text <> '' then
    Result := Result + '\noindent Inherited by ' + Text + '.\par'#10;
  Vis := Visible(C.Members);
  try
    if Vis.Count > 0 then
      Result := Result + '\section*{Member Overview}'#10 + Summary(C.Members, True);
  finally
    Vis.Free;
  end;
  Detail := Render(C.Detailed);
  if Detail <> '' then
    Result := Result + '\section*{Detailed Description}'#10 + Detail;
  Text := Members(C.Members, C.Name);
  if Text <> '' then
    Result := Result + '\section*{Member Documentation}'#10 + Text;
end;

function TLatexGenerator.UnitChapter(U: TUnitDef): string;
var
  Text, S, Detail: string;
  T: TUnitDef;
  C: TClassDef;
  Vis: TList<TMemberDef>;
begin
  Result := '\chapter{Unit ' + LatexEscape(U.Name) + ' Reference}'#10'\label{' + LabelOf(U) + '}'#10 +
    IndexEntry(U.Name) + #10;
  if Trim(U.Brief) <> '' then
    Result := Result + Render(U.Brief);
  Text := '';
  for S in U.UsesInterfaceNames do
  begin
    T := FProject.FindUnit(S);
    if Text <> '' then
      Text := Text + ', ';
    if (T <> nil) and FLinks.IsLinkable(T) then
      Text := Text + '\hyperref[' + LabelOf(T) + ']{' + LatexEscape(S) + '}'
    else
      Text := Text + LatexEscape(S);
  end;
  if Text <> '' then
    Result := Result + '\noindent Uses ' + Text + '.\par'#10;
  Text := '';
  for C in U.Classes do
    if FLinks.IsLinkable(C) and (C.Scope = U) then
      Text := Text + '\item \hyperref[' + LabelOf(C) + ']{\texttt{' + LatexEscape(C.Name) + '}}'#10;
  if Text <> '' then
    Result := Result + '\subsection*{Classes}'#10'\begin{DoxyCompactItemize}'#10 + Text + '\end{DoxyCompactItemize}'#10;
  Vis := Visible(U.Members);
  try
    if Vis.Count > 0 then
      Result := Result + Summary(U.Members, False);
  finally
    Vis.Free;
  end;
  Detail := Render(U.Detailed);
  if Detail <> '' then
    Result := Result + '\section*{Detailed Description}'#10 + Detail;
  Text := Members(U.Members, U.Name);
  if Text <> '' then
    Result := Result + '\section*{Member Documentation}'#10 + Text;
end;

function TLatexGenerator.ClassKind(C: TClassDef): string;
begin
  case C.ClassKind of
    ckRecord, ckRecordHelper: Result := 'Record';
    ckInterface, ckDispInterface: Result := 'Interface';
    ckObject: Result := 'Object';
    ckClassHelper, ckTypeHelper: Result := 'Helper';
  else
    Result := 'Class';
  end;
end;

const
  StyleText =
    '\NeedsTeXFormat{LaTeX2e}'#10 +
    '\ProvidesPackage{doxypas}[2026/10/21 Style of the LaTeX output of DoxyPas]'#10 +
    '\RequirePackage[a4paper,margin=2.5cm]{geometry}'#10 +
    '\RequirePackage{xcolor}'#10 +
    '\RequirePackage{fancyhdr}'#10 +
    '\RequirePackage{titlesec}'#10 +
    '\RequirePackage{longtable}'#10 +
    '\RequirePackage{fvextra}'#10 +
    '\RequirePackage{makeidx}'#10 +
    '\RequirePackage{multicol}'#10 +
    '\definecolor{doxyblue}{HTML}{354C7B}'#10 +
    '\definecolor{doxyframe}{HTML}{C4CFE5}'#10 +
    '\definecolor{doxyback}{HTML}{F9FAFC}'#10 +
    '\setcounter{secnumdepth}{-1}'#10 +
    '\setcounter{tocdepth}{1}'#10 +
    '\emergencystretch=3em'#10 +
    '\setlength{\parindent}{0pt}'#10 +
    '\setlength{\parskip}{0.6ex plus 0.2ex}'#10 +
    '\titleformat{\part}[display]{\normalfont\Huge\bfseries\color{doxyblue}}{}{0pt}{}'#10 +
    '\titleformat{\chapter}[hang]{\normalfont\huge\bfseries\color{doxyblue}}{}{0pt}{}[\vspace{2pt}\color{doxyframe}\titlerule]'#10 +
    '\titleformat{\section}{\normalfont\Large\bfseries\color{doxyblue}}{}{0pt}{}'#10 +
    '\titleformat{\subsection}{\normalfont\large\bfseries\color{doxyblue}}{}{0pt}{}'#10 +
    '\titlespacing*{\chapter}{0pt}{0pt}{20pt}'#10 +
    '\pagestyle{fancy}'#10 +
    '\fancyhf{}'#10 +
    '\fancyhead[LE,RO]{\bfseries\thepage}'#10 +
    '\fancyhead[LO]{\bfseries\nouppercase{\rightmark}}'#10 +
    '\fancyhead[RE]{\bfseries\nouppercase{\leftmark}}'#10 +
    '\fancyfoot[C]{\scriptsize\textcolor{gray}{Generated by DoxyPas}}'#10 +
    '\renewcommand{\headrulewidth}{0.4pt}'#10 +
    '\renewcommand{\footrulewidth}{0pt}'#10 +
    '\fancypagestyle{plain}{\fancyhf{}\fancyfoot[C]{\scriptsize\textcolor{gray}{Generated by DoxyPas}}\renewcommand{\headrulewidth}{0pt}}'#10 +
    '\newenvironment{DoxyCompactItemize}'#10 +
    '  {\begin{itemize}\setlength{\itemsep}{2pt}\setlength{\parskip}{0pt}\setlength{\topsep}{2pt}}'#10 +
    '  {\end{itemize}}'#10 +
    '\newcommand{\DoxyProto}[1]{\par\noindent\colorbox{doxyback}{\parbox{\dimexpr\linewidth-2\fboxsep\relax}'#10 +
    '  {\raggedright\ttfamily\small #1}}\par\smallskip}'#10 +
    '\makeindex'#10 +
    '\endinput'#10;

  MakeBat =
    '@echo off'#13#10'pdflatex refman'#13#10'makeindex refman.idx'#13#10'pdflatex refman'#13#10'pdflatex refman'#13#10;
  MakeFile =
    'all: refman.pdf'#10#10'refman.pdf: refman.tex'#10#9'pdflatex refman'#10#9'makeindex refman.idx'#10 +
    #9'pdflatex refman'#10#9'pdflatex refman'#10#10'clean:'#10#9'rm -f *.aux *.toc *.idx *.ind *.ilg *.log *.out refman.pdf'#10;

function TLatexGenerator.Run: Integer;
var
  U: TUnitDef;
  C: TClassDef;
  G: TGroupDef;
  P: TPageDef;
  Main, Name, Title, Brief: string;
  Pages, Topics, Units, Classes: TStringList;

  procedure Part(const ATitle: string; AList: TStringList);
  var
    N: string;
  begin
    if AList.Count = 0 then
      Exit;
    Main := Main + '\part{' + ATitle + '}'#10;
    for N in AList do
      Main := Main + '\input{' + N + '}'#10;
  end;

begin
  TDirectory.CreateDirectory(FDir);
  Pages := TStringList.Create;
  Topics := TStringList.Create;
  Units := TStringList.Create;
  Classes := TStringList.Create;
  try
    for P in FProject.Pages do
    begin
      if P.IsMainPage then Title := 'Introduction' else Title := P.Title;
      if Title = '' then Title := P.Name;
      Name := 'page_' + P.DiskName;
      Save(Name + '.tex', Chapter(P, Title));
      Pages.Add(Name);
    end;
    for G in FProject.Groups do
    begin
      Save(G.DiskName + '.tex', Chapter(G, G.Title));
      Topics.Add(G.DiskName);
    end;
    for U in FProject.Units do
      if FLinks.IsLinkable(U) then
      begin
        Save(U.DiskName + '.tex', UnitChapter(U));
        Units.Add(U.DiskName);
      end;
    for C in FProject.Classes do
      if FLinks.IsLinkable(C) then
      begin
        Save(C.DiskName + '.tex', ClassChapter(C));
        Classes.Add(C.DiskName);
      end;
    Brief := FConfig.GetString('PROJECT_BRIEF');
    Main := '\documentclass[a4paper,11pt]{report}'#10'\usepackage[utf8]{inputenc}'#10'\usepackage[T1]{fontenc}'#10 +
      '\usepackage{lmodern}'#10'\usepackage{doxypas}'#10'\usepackage[colorlinks=true,linkcolor=doxyblue,urlcolor=doxyblue]{hyperref}'#10 +
      '\begin{document}'#10'\begin{titlepage}'#10'\vspace*{3cm}'#10'\begin{center}'#10 +
      '{\Huge\bfseries\color{doxyblue} ' + LatexEscape(FConfig.GetString('PROJECT_NAME')) + '}\par\vspace{1ex}'#10;
    if FConfig.GetString('PROJECT_NUMBER') <> '' then
      Main := Main + '{\Large ' + LatexEscape(FConfig.GetString('PROJECT_NUMBER')) + '}\par\vspace{3ex}'#10;
    if Brief <> '' then
      Main := Main + '{\large\itshape ' + LatexEscape(Brief) + '}\par\vspace{3ex}'#10;
    Main := Main + '\rule{0.6\linewidth}{0.6pt}\par\vspace{3ex}'#10'\today\par\vspace{1ex}'#10'{\small Generated by DoxyPas ' +
      LatexEscape(DoxyPasVersion) + '}'#10'\end{center}'#10'\end{titlepage}'#10'\pagenumbering{roman}'#10 +
      '\tableofcontents'#10'\clearpage'#10'\pagenumbering{arabic}'#10;
    Part('Introduction', Pages);
    Part('Topic Documentation', Topics);
    Part('Unit Documentation', Units);
    Part('Class Documentation', Classes);
    Main := Main + '\cleardoublepage'#10'\phantomsection'#10'\addcontentsline{toc}{chapter}{Index}'#10 +
      '\printindex'#10'\end{document}'#10;
    Save('refman.tex', Main);
    Save('doxypas.sty', StyleText);
    TFile.WriteAllText(TPath.Combine(FDir, 'make.bat'), MakeBat, TEncoding.ASCII);
    TFile.WriteAllText(TPath.Combine(FDir, 'Makefile'), MakeFile, TEncoding.ASCII);
    Inc(FFiles, 2);
  finally
    Classes.Free;
    Units.Free;
    Topics.Free;
    Pages.Free;
  end;
  Result := FFiles;
end;

function GenerateLatex(AProject: TProject; AConfig: TConfig; const AOutDir: string): Integer;
var
  G: TLatexGenerator;
begin
  G := TLatexGenerator.Create(AProject, AConfig, AOutDir);
  try
    Result := G.Run;
  finally
    G.Free;
  end;
end;

end.