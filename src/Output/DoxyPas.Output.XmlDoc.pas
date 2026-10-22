unit DoxyPas.Output.XmlDoc;

{ Documentation AST -> Doxygen XML (docparaType, docSect1Type, ...): Doxygen's xmldocvisitor. }

interface

uses
  DoxyPas.Doc.Nodes,
  DoxyPas.Model.Defs,
  DoxyPas.Model.Links,
  DoxyPas.Output.XmlWriter;

type
  TXmlDocWriter = class
  strict private
    FW: TXmlWriter;
    FLinks: TLinkResolver;
    FScope: TDefinition;
    FFormulas: Integer;
    FXrefs: Integer;
    procedure WriteRef(const ADisplay: string; const ATarget: TLinkTarget);
    procedure WriteText(const AText: string; AAutoLink: Boolean);
    procedure WriteInline(ANode: TDocNode; AAutoLink: Boolean);
    procedure WriteChildren(ANode: TDocNode; AAutoLink: Boolean);
    procedure WriteBlock(ANode: TDocNode);
    procedure WritePara(ANode: TDocNode);
    procedure WriteListing(ANode: TDocNode);
    procedure WriteSimpleSect(ANode: TDocNode);
    procedure WriteParamList(ANode: TDocNode);
    procedure WriteList(ANode: TDocNode);
    procedure WriteTable(ANode: TDocNode);
    procedure WriteSection(ANode: TDocNode; ALevel: Integer);
    procedure WriteParasOf(ANode: TDocNode);
    function OwnerRef: string;
  public
    constructor Create(AWriter: TXmlWriter; ALinks: TLinkResolver);
    /// <summary>Writes &lt;AElement&gt;...&lt;/AElement&gt; with the paragraphs and sections of the documentation text
    /// (Doxygen markup after the Markdown pass). Empty text gives an empty element.</summary>
    procedure Description(const AElement, AText: string; AScope: TDefinition);
    /// <summary>Writes a text with links to types (the content of &lt;type&gt;, &lt;defval&gt;, ...).</summary>
    procedure LinkedText(const AElement, AText: string; AScope: TDefinition; const AAttrs: array of string);
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DoxyPas.Doc.Parser;

constructor TXmlDocWriter.Create(AWriter: TXmlWriter; ALinks: TLinkResolver);
begin
  inherited Create;
  FW := AWriter;
  FLinks := ALinks;
end;

function TXmlDocWriter.OwnerRef: string;
begin
  if FScope = nil then
    Result := ''
  else
    Result := FLinks.RefIdOf(FScope);
end;

procedure TXmlDocWriter.WriteRef(const ADisplay: string; const ATarget: TLinkTarget);
var
  Kind: string;
begin
  if ATarget.IsMember then Kind := 'member' else Kind := 'compound';
  if ATarget.External then
    FW.Open('ref', ['refid', FlatName(ATarget.RefId), 'kindref', Kind, 'external', ATarget.TagName])
  else
    FW.Open('ref', ['refid', FlatName(ATarget.RefId), 'kindref', Kind]);
  FW.Text(ADisplay);
  FW.Close('ref');
end;

procedure TXmlDocWriter.WriteText(const AText: string; AAutoLink: Boolean);
begin
  if not AAutoLink then
  begin
    FW.Text(AText);
    Exit;
  end;
  FLinks.LinkWords(AText, FScope,
    procedure(const T: string)
    begin
      FW.Text(T);
    end,
    procedure(const T: string; const Target: TLinkTarget)
    begin
      WriteRef(T, Target);
    end);
end;

procedure TXmlDocWriter.WriteChildren(ANode: TDocNode; AAutoLink: Boolean);
var
  C: TDocNode;
begin
  for C in ANode.Children do
    WriteInline(C, AAutoLink);
end;

function ParamDirection(const AExtra: string): string;
begin
  if (Pos('in', AExtra) > 0) and (Pos('out', AExtra) > 0) then Result := 'inout'
  else if Pos('out', AExtra) > 0 then Result := 'out'
  else if Pos('in', AExtra) > 0 then Result := 'in'
  else Result := '';
end;

procedure TXmlDocWriter.WriteListing(ANode: TDocNode);
var
  Lines: TArray<string>;
  L: string;
  C: Char;
  Pending: string;
begin
  if ANode.Extra <> '' then
    FW.Open('programlisting', ['filename', ANode.Extra])
  else
    FW.Open('programlisting', []);
  Lines := ANode.Text.Replace(#13#10, #10).Split([#10]);
  for L in Lines do
  begin
    FW.Open('codeline', []);
    FW.Open('highlight', ['class', 'normal']);
    Pending := '';
    for C in L do
      if C = ' ' then
      begin
        if Pending <> '' then
          FW.Text(Pending);
        Pending := '';
        FW.Empty('sp', []);
      end
      else
        Pending := Pending + C;
    if Pending <> '' then
      FW.Text(Pending);
    FW.Close('highlight');
    FW.Close('codeline');
  end;
  FW.Close('programlisting');
end;

procedure TXmlDocWriter.WriteSimpleSect(ANode: TDocNode);
var
  C: TDocNode;
  Title: string;
begin
  if (ANode.Name = 'todo') or (ANode.Name = 'test') or (ANode.Name = 'bug') or (ANode.Name = 'deprecated') then
  begin
    Inc(FXrefs);
    Title := UpCase(ANode.Name[1]) + Copy(ANode.Name, 2, MaxInt);
    FW.Open('xrefsect', ['id', Format('%s_1%s%.6d', [ANode.Name, ANode.Name, FXrefs])]);
    FW.Leaf('xreftitle', Title, []);
    FW.Open('xrefdescription', []);
    for C in ANode.Children do
      if C.Kind = dnPara then
        WritePara(C);
    FW.Close('xrefdescription');
    FW.Close('xrefsect');
    Exit;
  end;
  FW.Open('simplesect', ['kind', ANode.Name]);
  if (ANode.Name = 'par') and (ANode.Text <> '') then
    FW.Leaf('title', ANode.Text, []);
  for C in ANode.Children do
    if C.Kind = dnPara then
      WritePara(C);
  FW.Close('simplesect');
end;

procedure TXmlDocWriter.WriteParamList(ANode: TDocNode);
var
  Item, C: TDocNode;
  N, Dir: string;
begin
  FW.Open('parameterlist', ['kind', ANode.Name]);
  for Item in ANode.Children do
  begin
    FW.Open('parameteritem', []);
    FW.Open('parameternamelist', []);
    Dir := ParamDirection(Item.Extra);
    for N in Item.Text.Split([','], TStringSplitOptions.ExcludeEmpty) do
      if Dir <> '' then
        FW.Leaf('parametername', N, ['direction', Dir])
      else
        FW.Leaf('parametername', N, []);
    FW.Close('parameternamelist');
    FW.Open('parameterdescription', []);
    for C in Item.Children do
      if C.Kind = dnPara then
        WritePara(C);
    FW.Close('parameterdescription');
    FW.Close('parameteritem');
  end;
  FW.Close('parameterlist');
end;

procedure TXmlDocWriter.WriteList(ANode: TDocNode);
var
  Item, C: TDocNode;
begin
  if ANode.Name = 'dl' then
  begin
    FW.Open('variablelist', []);
    for Item in ANode.Children do
      if Item.Name = 'dt' then
      begin
        FW.Open('varlistentry', []);
        FW.Open('term', []);
        for C in Item.Children do
          WriteChildren(C, False);
        FW.Close('term');
        FW.Close('varlistentry');
      end
      else
      begin
        FW.Open('listitem', []);
        for C in Item.Children do
          if C.Kind = dnPara then
            WritePara(C);
        FW.Close('listitem');
      end;
    FW.Close('variablelist');
    Exit;
  end;
  if ANode.Name = 'ol' then
    FW.Open('orderedlist', ['type', '1'])
  else
    FW.Open('itemizedlist', []);
  for Item in ANode.Children do
  begin
    FW.Open('listitem', []);
    for C in Item.Children do
      if C.Kind = dnPara then
        WritePara(C);
    FW.Close('listitem');
  end;
  if ANode.Name = 'ol' then
    FW.Close('orderedlist')
  else
    FW.Close('itemizedlist');
end;

procedure TXmlDocWriter.WriteTable(ANode: TDocNode);
var
  Row, Cell, P: TDocNode;
  Cols, Rows: Integer;
  Align: string;
begin
  Rows := ANode.Children.Count;
  Cols := 0;
  for Row in ANode.Children do
    if Row.Children.Count > Cols then
      Cols := Row.Children.Count;
  FW.Open('table', ['rows', Rows.ToString, 'cols', Cols.ToString]);
  for Row in ANode.Children do
  begin
    FW.Open('row', []);
    for Cell in Row.Children do
    begin
      Align := '';
      if Cell.Extra.Contains('align="left"') then Align := 'left'
      else if Cell.Extra.Contains('align="right"') then Align := 'right'
      else if Cell.Extra.Contains('align="center"') then Align := 'center';
      if Align <> '' then
        FW.Open('entry', ['thead', YesNo(Cell.Name = 'th'), 'align', Align])
      else
        FW.Open('entry', ['thead', YesNo(Cell.Name = 'th')]);
      for P in Cell.Children do
        if P.Kind = dnPara then
          WritePara(P);
      FW.Close('entry');
    end;
    FW.Close('row');
  end;
  FW.Close('table');
end;

procedure TXmlDocWriter.WriteBlock(ANode: TDocNode);
begin
  case ANode.Kind of
    dnList: WriteList(ANode);
    dnTable: WriteTable(ANode);
    dnSimpleSect: WriteSimpleSect(ANode);
    dnParamList: WriteParamList(ANode);
    dnBlockQuote:
      begin
        FW.Open('blockquote', []);
        WriteParasOf(ANode);
        FW.Close('blockquote');
      end;
  end;
end;

procedure TXmlDocWriter.WriteParasOf(ANode: TDocNode);
var
  C: TDocNode;
begin
  for C in ANode.Children do
    if C.Kind = dnPara then
      WritePara(C);
end;

procedure TXmlDocWriter.WriteInline(ANode: TDocNode; AAutoLink: Boolean);
var
  Tag, Display: string;
  T: TLinkTarget;
begin
  case ANode.Kind of
    dnText: WriteText(ANode.Text, AAutoLink);
    dnSymbol: FW.Text(ANode.Text);
    dnStyle:
      begin
        if ANode.Name = 'b' then Tag := 'bold'
        else if (ANode.Name = 'i') or (ANode.Name = 'em') or (ANode.Name = 'var') then Tag := 'emphasis'
        else if (ANode.Name = 'code') or (ANode.Name = 'kbd') or (ANode.Name = 'samp') then Tag := 'computeroutput'
        else if ANode.Name = 'u' then Tag := 'underline'
        else if ANode.Name = 's' then Tag := 'strike'
        else if ANode.Name = 'sub' then Tag := 'subscript'
        else if ANode.Name = 'sup' then Tag := 'superscript'
        else if (ANode.Name = 'small') or (ANode.Name = 'center') or (ANode.Name = 'cite') or (ANode.Name = 'ins') or
          (ANode.Name = 'del') then Tag := ANode.Name
        else Tag := '';
        if Tag = '' then
          WriteChildren(ANode, AAutoLink)
        else
        begin
          FW.Open(Tag, []);
          WriteChildren(ANode, AAutoLink);
          FW.Close(Tag);
        end;
      end;
    dnUrl:
      begin
        if ANode.Name = 'email' then
          FW.Open('ulink', ['url', 'mailto:' + ANode.Text])
        else
          FW.Open('ulink', ['url', ANode.Text]);
        FW.Text(ANode.Text);
        FW.Close('ulink');
      end;
    dnLink:
      if ANode.Name = 'href' then
      begin
        FW.Open('ulink', ['url', ANode.Text]);
        WriteChildren(ANode, False);
        FW.Close('ulink');
      end
      else
      begin
        T := FLinks.Resolve(ANode.Text, FScope);
        if T.Resolved then
        begin
          if T.External then
            FW.Open('ref', ['refid', FlatName(T.RefId), 'kindref', 'compound', 'external', T.TagName])
          else if T.IsMember then
            FW.Open('ref', ['refid', FlatName(T.RefId), 'kindref', 'member'])
          else
            FW.Open('ref', ['refid', FlatName(T.RefId), 'kindref', 'compound']);
          WriteChildren(ANode, False);
          FW.Close('ref');
        end
        else
          WriteChildren(ANode, False);
      end;
    dnRef:
      begin
        Display := ANode.PlainText;
        if Display = '' then
          Display := ANode.Text;
        T := FLinks.Resolve(ANode.Text, FScope);
        if T.Resolved then
          WriteRef(Display, T)
        else
          FW.Text(Display);
      end;
    dnAnchor:
      FW.Empty('anchor', ['id', OwnerRef + '_1' + ANode.Text]);
    dnLineBreak: FW.Empty('linebreak', []);
    dnHRuler: FW.Empty('hruler', []);
    dnFormula:
      begin
        Inc(FFormulas);
        FW.Open('formula', ['id', 'form_' + FFormulas.ToString]);
        if ANode.Name = 'inline' then
          FW.Text('$' + ANode.Text + '$')
        else
          FW.Text('\[' + ANode.Text + '\]');
        FW.Close('formula');
      end;
    dnVerbatim:
      begin
        if ANode.Name = 'code' then
          WriteListing(ANode)
        else if (ANode.Name = 'verbatim') or (ANode.Name = 'pre') then
          FW.Leaf('verbatim', ANode.Text, [])
        else if ANode.Name = 'htmlonly' then FW.Leaf('htmlonly', ANode.Text, [])
        else if ANode.Name = 'latexonly' then FW.Leaf('latexonly', ANode.Text, [])
        else if ANode.Name = 'xmlonly' then FW.Leaf('xmlonly', ANode.Text, [])
        else if ANode.Name = 'rtfonly' then FW.Leaf('rtfonly', ANode.Text, [])
        else if ANode.Name = 'manonly' then FW.Leaf('manonly', ANode.Text, [])
        else if ANode.Name = 'docbookonly' then FW.Leaf('docbookonly', ANode.Text, [])
        else if ANode.Name = 'dot' then FW.Leaf('dot', ANode.Text, [])
        else if ANode.Name = 'msc' then FW.Leaf('msc', ANode.Text, [])
        else if ANode.Name = 'uml' then FW.Leaf('plantuml', ANode.Text, [])
        else
          FW.Leaf('verbatim', ANode.Text, []);
      end;
    dnImage:
      begin
        if ANode.Name = 'latex' then Tag := 'latex'
        else if ANode.Name = 'rtf' then Tag := 'rtf'
        else Tag := 'html';
        FW.Open('image', ['type', Tag, 'name', ANode.Text]);
        FW.Text(ANode.Extra);
        FW.Close('image');
      end;
    dnCite:
      begin
        FW.Open('cite', []);
        FW.Text(ANode.Text);
        FW.Close('cite');
      end;
    dnHeading:
      begin
        FW.Open('heading', ['level', ANode.Level.ToString]);
        WriteChildren(ANode, AAutoLink);
        FW.Close('heading');
      end;
    dnList, dnTable, dnSimpleSect, dnParamList, dnBlockQuote:
      begin
        FW.NewLine;
        WriteBlock(ANode);
      end;
    dnCopyDoc, dnInclude: ; // resolved earlier / not supported
  end;
end;

procedure TXmlDocWriter.WritePara(ANode: TDocNode);
begin
  FW.NewLine;
  FW.Open('para', []);
  WriteChildren(ANode, True);
  FW.Close('para');
end;

procedure TXmlDocWriter.WriteSection(ANode: TDocNode; ALevel: Integer);
var
  C: TDocNode;
  Tag: string;
begin
  if ALevel > 6 then
    ALevel := 6;
  Tag := 'sect' + ALevel.ToString;
  FW.NewLine;
  FW.Open(Tag, ['id', OwnerRef + '_1' + ANode.Id]);
  FW.NewLine;
  FW.Leaf('title', ANode.Text, []);
  for C in ANode.Children do
    if C.Kind = dnPara then
      WritePara(C);
  for C in ANode.Children do
    if C.Kind = dnSection then
      WriteSection(C, ALevel + 1);
  FW.NewLine;
  FW.Close(Tag);
end;

procedure TXmlDocWriter.Description(const AElement, AText: string; AScope: TDefinition);
var
  Root, C: TDocNode;
begin
  FScope := AScope;
  FW.Open(AElement, []);
  if Trim(AText) <> '' then
  begin
    Root := ParseDoc(AText);
    try
      for C in Root.Children do
        if C.Kind = dnPara then
          WritePara(C);
      for C in Root.Children do
        if C.Kind = dnSection then
          WriteSection(C, 1);
    finally
      Root.Free;
    end;
  end;
  FW.NewLine;
  FW.Close(AElement);
end;

procedure TXmlDocWriter.LinkedText(const AElement, AText: string; AScope: TDefinition;
  const AAttrs: array of string);
begin
  FScope := AScope;
  FW.Open(AElement, AAttrs);
  FLinks.LinkWords(AText, AScope,
    procedure(const T: string)
    begin
      FW.Text(T);
    end,
    procedure(const T: string; const Target: TLinkTarget)
    begin
      WriteRef(T, Target);
    end, True);
  FW.Close(AElement);
end;

end.
