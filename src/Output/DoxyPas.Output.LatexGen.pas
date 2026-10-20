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
    function Members(AList: TList<TMemberDef>): string;
    function Chapter(ADef: TDefinition; const ATitle: string): string;
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
        Result := '\begin{verbatim}'#10 + ANode.Text.Replace('\end{verbatim}', '') + #10'\end{verbatim}'#10
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

function TLatexGenerator.Members(AList: TList<TMemberDef>): string;
var
  M: TMemberDef;
  Body: string;
begin
  Result := '';
  for M in AList do
    if FProject.IsVisible(M) and FLinks.IsLinkable(M) then
    begin
      Body := Render(M.Brief + #10#10 + M.Detailed);
      Result := Result + '\subsection*{' + LatexEscape(M.Name) + '}'#10'\label{' + LabelOf(M) + '}'#10 +
        '\texttt{' + LatexEscape(MemberText(M)) + '}\par'#10 + Body + #10;
    end;
end;

function TLatexGenerator.Chapter(ADef: TDefinition; const ATitle: string): string;
begin
  Result := '\chapter{' + LatexEscape(ATitle) + '}'#10'\label{' + LabelOf(ADef) + '}'#10 +
    Render(ADef.Brief + #10#10 + ADef.Detailed);
end;

function TLatexGenerator.Run: Integer;
var
  U: TUnitDef;
  C: TClassDef;
  G: TGroupDef;
  P: TPageDef;
  Main, Name, Title: string;
  Names: TStringList;
  Text: string;
begin
  TDirectory.CreateDirectory(FDir);
  Names := TStringList.Create;
  try
    for P in FProject.Pages do
    begin
      if P.IsMainPage then Title := 'Introduction' else Title := P.Title;
      if Title = '' then Title := P.Name;
      Name := 'page_' + P.DiskName;
      Save(Name + '.tex', Chapter(P, Title));
      Names.Add(Name);
    end;
    for U in FProject.Units do
      if FLinks.IsLinkable(U) then
      begin
        Text := Chapter(U, 'Unit ' + U.Name) + Members(U.Members);
        Save(U.DiskName + '.tex', Text);
        Names.Add(U.DiskName);
      end;
    for C in FProject.Classes do
      if FLinks.IsLinkable(C) then
      begin
        Text := Chapter(C, C.QualifiedName);
        Text := Text + Members(C.Members);
        Save(C.DiskName + '.tex', Text);
        Names.Add(C.DiskName);
      end;
    for G in FProject.Groups do
    begin
      Save(G.DiskName + '.tex', Chapter(G, G.Title));
      Names.Add(G.DiskName);
    end;
    Main := '\documentclass[a4paper,11pt]{report}'#10'\usepackage[utf8]{inputenc}'#10'\usepackage[T1]{fontenc}'#10 +
      '\usepackage{longtable}'#10'\usepackage[colorlinks=true,linkcolor=blue]{hyperref}'#10 +
      '\title{' + LatexEscape(FConfig.GetString('PROJECT_NAME')) + '\\ \large ' +
      LatexEscape(FConfig.GetString('PROJECT_NUMBER')) + '}'#10'\author{Generated by DoxyPas ' +
      LatexEscape(DoxyPasVersion) + '}'#10'\begin{document}'#10'\maketitle'#10'\tableofcontents'#10;
    for Name in Names do
      Main := Main + '\input{' + Name + '}'#10;
    Main := Main + '\end{document}'#10;
    Save('refman.tex', Main);
  finally
    Names.Free;
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
