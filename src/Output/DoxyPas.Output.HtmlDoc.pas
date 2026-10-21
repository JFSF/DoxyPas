unit DoxyPas.Output.HtmlDoc;

{ Documentation AST -> HTML (Doxygen's htmldocvisitor). All pages are written in one directory, so links are plain
  "file.html#anchor". }

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DoxyPas.Doc.Nodes,
  DoxyPas.Model.Defs,
  DoxyPas.Model.Links;

type
  THtmlDocWriter = class
  strict private
    FObfuscateEmails, FExternalInWindow: Boolean;
    FLinks: TLinkResolver;
    FExt: string;
    FScope: TDefinition;
    FFormulas: Integer;
    FFormulaTex: TList<string>;
    FImageFormulas: Boolean;
    function IsBlock(ANode: TDocNode): Boolean;
    function Inline_(ANode: TDocNode; AAutoLink: Boolean): string;
    function InlineChildren(ANode: TDocNode; AAutoLink: Boolean): string;
    function TextHtml(const AText: string; AAutoLink: Boolean): string;
    function Para(ANode: TDocNode; ABare: Boolean): string;
    function Paras(ANode: TDocNode; ABare: Boolean): string;
    function Block(ANode: TDocNode): string;
    function SimpleSect(ANode: TDocNode): string;
    function ParamList(ANode: TDocNode): string;
    function List(ANode: TDocNode): string;
    function Table(ANode: TDocNode): string;
    function Fragment(ANode: TDocNode): string;
    function Section(ANode: TDocNode; ALevel: Integer): string;
    function RefLink(const ADisplay: string; const ATarget: TLinkTarget): string;
    function Prepare(const AText: string; AScope: TDefinition): TDocNode;
  public
    constructor Create(ALinks: TLinkResolver; const AExt: string);
    destructor Destroy; override;
    /// <summary>OBFUSCATE_EMAILS: the @ of the e-mail addresses is written as a character reference.</summary>
    property ObfuscateEmails: Boolean read FObfuscateEmails write FObfuscateEmails;
    /// <summary>EXT_LINKS_IN_WINDOW: the links to other projects (tag files) open in another window.</summary>
    property ExternalLinksInWindow: Boolean read FExternalInWindow write FExternalInWindow;
    /// <summary>Formulas are images (formula_N.svg, made from FormulaTex) instead of MathJax markup.</summary>
    property ImageFormulas: Boolean read FImageFormulas write FImageFormulas;
    /// <summary>The TeX of the formulas written so far, in the order of their numbers: 'i' + TeX for an inline formula,
    /// 'd' + TeX for a display formula.</summary>
    property FormulaTex: TList<string> read FFormulaTex;
    /// <summary>"file.html#anchor" of a link target.</summary>
    function UrlOf(const ATarget: TLinkTarget): string;
    function DefUrl(ADef: TDefinition): string;
    function Anchor(const AAnchor: string): string;
    /// <summary>Paragraphs and sections (the content of a "textblock").</summary>
    function Render(const AText: string; AScope: TDefinition): string;
    /// <summary>The text of the first paragraph without the &lt;p&gt; element (brief descriptions).</summary>
    function RenderBrief(const AText: string; AScope: TDefinition): string;
    /// <summary>Plain text of a type, default value, ... with links to the definitions it names.</summary>
    function LinkedText(const AText: string; AScope: TDefinition): string;
    /// <summary>"&lt;a class="el" href="..."&gt;Text&lt;/a&gt;" (just the text when ADef has no page).</summary>
    function Link(ADef: TDefinition; const AText: string): string;
  end;

implementation

uses
  System.StrUtils,
  System.Classes,
  DoxyPas.Core.Timing,
  DoxyPas.Doc.Parser,
  DoxyPas.Output.HtmlCode,
  DoxyPas.Output.Translator,
  DoxyPas.Output.HtmlTemplate;

constructor THtmlDocWriter.Create(ALinks: TLinkResolver; const AExt: string);
begin
  inherited Create;
  FLinks := ALinks;
  FExt := AExt;
  FFormulaTex := TList<string>.Create;
end;

destructor THtmlDocWriter.Destroy;
begin
  FFormulaTex.Free;
  inherited;
end;

function THtmlDocWriter.Anchor(const AAnchor: string): string;
begin
  Result := '<a class="anchor" id="' + HtmlEscape(AAnchor) + '"></a>';
end;

function THtmlDocWriter.DefUrl(ADef: TDefinition): string;
begin
  if ADef is TMemberDef then
  begin
    if ADef.Scope <> nil then
      Result := ADef.Scope.DiskName + FExt + '#' + ADef.DiskName
    else
      Result := ADef.DiskName + FExt;
  end
  else
    Result := ADef.DiskName + FExt;
end;

function THtmlDocWriter.UrlOf(const ATarget: TLinkTarget): string;
var
  I: Integer;
begin
  if ATarget.External then
    Exit(ATarget.Url);
  if ATarget.Def <> nil then
    Exit(DefUrl(ATarget.Def));
  // \section / \anchor label: "<owner disk name>_1<label>"; underscores of the disk name are doubled
  I := 1;
  while I < Length(ATarget.RefId) do
  begin
    if (ATarget.RefId[I] = '_') and (ATarget.RefId[I + 1] = '1') and ((I = 1) or (ATarget.RefId[I - 1] <> '_')) then
      Exit(Copy(ATarget.RefId, 1, I - 1) + FExt + '#' + Copy(ATarget.RefId, I + 2, MaxInt));
    Inc(I);
  end;
  Result := ATarget.RefId + FExt;
end;

function THtmlDocWriter.RefLink(const ADisplay: string; const ATarget: TLinkTarget): string;
begin
  if ATarget.External then
    Result := '<a class="elRef" href="' + HtmlEscape(UrlOf(ATarget)) + '"' + IfThen(FExternalInWindow, ' target="_blank"', '') +
      '>' + HtmlEscape(ADisplay) + '</a>'
  else
    Result := '<a class="el" href="' + HtmlEscape(UrlOf(ATarget)) + '">' + HtmlEscape(ADisplay) + '</a>';
end;

function THtmlDocWriter.Link(ADef: TDefinition; const AText: string): string;
begin
  if (ADef <> nil) and FLinks.IsLinkable(ADef) then
    Result := '<a class="el" href="' + HtmlEscape(DefUrl(ADef)) + '">' + HtmlEscape(AText) + '</a>'
  else
    Result := HtmlEscape(AText);
end;

function THtmlDocWriter.TextHtml(const AText: string; AAutoLink: Boolean): string;
var
  SB: TStringBuilder;
begin
  if not AAutoLink then
    Exit(HtmlEscape(AText));
  SB := TStringBuilder.Create;
  try
    FLinks.LinkWords(AText, FScope,
      procedure(const T: string)
      begin
        SB.Append(HtmlEscape(T));
      end,
      procedure(const T: string; const Target: TLinkTarget)
      begin
        SB.Append(RefLink(T, Target));
      end);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function THtmlDocWriter.LinkedText(const AText: string; AScope: TDefinition): string;
var
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    FLinks.LinkWords(AText, AScope,
      procedure(const T: string)
      begin
        SB.Append(HtmlEscape(T));
      end,
      procedure(const T: string; const Target: TLinkTarget)
      begin
        SB.Append(RefLink(T, Target));
      end, True);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function THtmlDocWriter.IsBlock(ANode: TDocNode): Boolean;
begin
  Result := ANode.Kind in [dnList, dnTable, dnSimpleSect, dnParamList, dnBlockQuote, dnHeading, dnHRuler];
  if ANode.Kind = dnVerbatim then
    Result := ANode.Name <> 'htmlonly';
end;

function THtmlDocWriter.InlineChildren(ANode: TDocNode; AAutoLink: Boolean): string;
var
  C: TDocNode;
begin
  Result := '';
  for C in ANode.Children do
    Result := Result + Inline_(C, AAutoLink);
end;

function THtmlDocWriter.Inline_(ANode: TDocNode; AAutoLink: Boolean): string;
var
  Tag, Display: string;
  T: TLinkTarget;
begin
  Result := '';
  case ANode.Kind of
    dnText: Result := TextHtml(ANode.Text, AAutoLink);
    dnSymbol: Result := HtmlEscape(ANode.Text);
    dnStyle:
      begin
        if ANode.Name = 'b' then Tag := 'b'
        else if (ANode.Name = 'i') or (ANode.Name = 'em') or (ANode.Name = 'var') then Tag := 'em'
        else if ANode.Name = 'code' then Tag := 'code'
        else if (ANode.Name = 'u') or (ANode.Name = 's') or (ANode.Name = 'sub') or (ANode.Name = 'sup') or
          (ANode.Name = 'small') or (ANode.Name = 'center') or (ANode.Name = 'kbd') or (ANode.Name = 'samp') or
          (ANode.Name = 'ins') or (ANode.Name = 'del') or (ANode.Name = 'cite') or (ANode.Name = 'div') or
          (ANode.Name = 'span') then Tag := ANode.Name
        else if ANode.Name = 'strike' then Tag := 's'
        else Tag := '';
        if Tag = '' then
          Result := InlineChildren(ANode, AAutoLink and (ANode.Name <> 'code'))
        else
          Result := '<' + Tag + '>' + InlineChildren(ANode, AAutoLink and (Tag <> 'code')) + '</' + Tag + '>';
      end;
    dnUrl:
      if ANode.Name = 'email' then
        if FObfuscateEmails then
          Result := '<a href="mailto:' + HtmlEscape(ANode.Text).Replace('@', '&#64;') + '">' +
            HtmlEscape(ANode.Text).Replace('@', '&#64;') + '</a>'
        else
          Result := '<a href="mailto:' + HtmlEscape(ANode.Text) + '">' + HtmlEscape(ANode.Text) + '</a>'
      else
        Result := '<a href="' + HtmlEscape(ANode.Text) + '">' + HtmlEscape(ANode.Text) + '</a>';
    dnLink:
      if ANode.Name = 'href' then
        Result := '<a href="' + HtmlEscape(ANode.Text) + '">' + InlineChildren(ANode, False) + '</a>'
      else
      begin
        T := FLinks.Resolve(ANode.Text, FScope);
        if T.Resolved then
        begin
          if T.External then
            Result := '<a class="elRef" href="' + HtmlEscape(UrlOf(T)) + '">'
          else
            Result := '<a class="el" href="' + HtmlEscape(UrlOf(T)) + '">';
          Result := Result + InlineChildren(ANode, False) + '</a>';
        end
        else
          Result := InlineChildren(ANode, False);
      end;
    dnRef:
      begin
        Display := ANode.PlainText;
        if Display = '' then
          Display := ANode.Text;
        T := FLinks.Resolve(ANode.Text, FScope);
        if T.Resolved then
          Result := RefLink(Display, T)
        else
          Result := HtmlEscape(Display);
      end;
    dnAnchor: Result := Anchor(ANode.Text);
    dnLineBreak: Result := '<br />'#10;
    dnHRuler: Result := '<hr/>'#10;
    dnFormula:
      begin
        Inc(FFormulas);
        if FImageFormulas then
        begin
          if ANode.Name = 'inline' then
            FFormulaTex.Add('i' + ANode.Text)
          else
            FFormulaTex.Add('d' + ANode.Text);
          Result := '<img class="formulaInl" alt="' + HtmlEscape(ANode.Text) + '" src="formula_' + FFormulas.ToString +
            '.svg" style="vertical-align:middle"/>';
          if ANode.Name <> 'inline' then
            Result := '<p class="formulaDsp">' + Result + '</p>';
        end
        else if ANode.Name = 'inline' then
          Result := '<span class="tex2jax_process">\(' + HtmlEscape(ANode.Text) + '\)</span>'
        else
          Result := '<p class="formulaDsp"><span class="tex2jax_process">\[' + HtmlEscape(ANode.Text) +
            '\]</span></p>';
      end;
    dnVerbatim:
      if ANode.Name = 'htmlonly' then
        Result := ANode.Text;
    dnImage:
      if (ANode.Name = 'html') or (ANode.Name = '') then
        Result := '<div class="image">'#10'<img src="' + HtmlEscape(ANode.Text) + '" alt="' + HtmlEscape(ANode.Extra) +
          '"/>'#10'</div>'#10;
    dnCite: Result := '[' + HtmlEscape(ANode.Text) + ']';
    dnCopyDoc, dnInclude: ; // resolved earlier / not supported
  end;
end;

function THtmlDocWriter.Fragment(ANode: TDocNode): string;
begin
  if ANode.Name = 'code' then
    Result := '<div class="fragment">' + HighlightPascal(ANode.Text) + '</div><!-- fragment -->'#10
  else if (ANode.Name = 'verbatim') or (ANode.Name = 'pre') then
    Result := '<pre class="fragment">' + HtmlEscape(ANode.Text) + '</pre>'#10
  else
    Result := '';
end;

const
  SectionTitles: array[0..17, 0..1] of string = (('see', 'See also'), ('return', 'Returns'), ('author', 'Author'),
    ('version', 'Version'), ('since', 'Since'), ('date', 'Date'), ('note', 'Note'), ('warning', 'Warning'),
    ('pre', 'Precondition'), ('post', 'Postcondition'), ('copyright', 'Copyright'), ('invariant', 'Invariant'),
    ('remark', 'Remarks'), ('attention', 'Attention'), ('important', 'Important'), ('todo', 'Todo'),
    ('test', 'Test'), ('bug', 'Bug'));

function THtmlDocWriter.SimpleSect(ANode: TDocNode): string;
var
  Title: string;
  I: Integer;
begin
  Title := '';
  for I := 0 to High(SectionTitles) do
    if SectionTitles[I, 0] = ANode.Name then
      Title := Tr(SectionTitles[I, 1]);
  if ANode.Name = 'deprecated' then
    Title := Tr('Deprecated');
  if ANode.Name = 'par' then
    Result := '<dl class="section user"><dt>' + HtmlEscape(ANode.Text) + '</dt><dd>' + Paras(ANode, True) +
      '</dd></dl>'#10
  else
    Result := '<dl class="section ' + ANode.Name + '"><dt>' + Title + '</dt><dd>' + Paras(ANode, True) +
      '</dd></dl>'#10;
end;

function THtmlDocWriter.ParamList(ANode: TDocNode): string;
var
  SB: TStringBuilder;
  Item: TDocNode;
  Cls, Title, N, Dir: string;
  AnyDir: Boolean;
begin
  if ANode.Name = 'retval' then begin Cls := 'retval'; Title := Tr('Return Values'); end
  else if ANode.Name = 'exception' then begin Cls := 'exception'; Title := Tr('Exceptions'); end
  else if ANode.Name = 'templateparam' then begin Cls := 'tparams'; Title := Tr('Template Parameters'); end
  else begin Cls := 'params'; Title := Tr('Parameters'); end;
  AnyDir := False;
  for Item in ANode.Children do
    if Item.Extra <> '' then
      AnyDir := True;
  SB := TStringBuilder.Create;
  try
    SB.Append('<dl class="').Append(Cls).Append('"><dt>').Append(Title).Append('</dt><dd>'#10);
    SB.Append('  <table class="').Append(Cls).Append('">'#10);
    for Item in ANode.Children do
    begin
      SB.Append('    <tr>');
      if AnyDir then
      begin
        Dir := '';
        if Item.Extra.Contains('in') and Item.Extra.Contains('out') then Dir := '[in,out]'
        else if Item.Extra.Contains('out') then Dir := '[out]'
        else if Item.Extra.Contains('in') then Dir := '[in]';
        SB.Append('<td class="paramdir">').Append(Dir).Append('</td>');
      end;
      N := Item.Text.Replace(',', ', ');
      SB.Append('<td class="paramname">').Append(HtmlEscape(N)).Append('</td><td>').Append(Paras(Item, True))
        .Append('</td></tr>'#10);
    end;
    SB.Append('  </table>'#10'  </dd>'#10'</dl>'#10);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function THtmlDocWriter.List(ANode: TDocNode): string;
var
  SB: TStringBuilder;
  Item: TDocNode;
  Tag: string;
begin
  SB := TStringBuilder.Create;
  try
    if ANode.Name = 'dl' then
    begin
      SB.Append('<dl>'#10);
      for Item in ANode.Children do
        if Item.Name = 'dt' then
          SB.Append('<dt>').Append(InlineChildren(Item, True).Trim).Append('</dt>'#10)
        else
          SB.Append('<dd>').Append(Paras(Item, True)).Append('</dd>'#10);
      SB.Append('</dl>'#10);
    end
    else
    begin
      if ANode.Name = 'ol' then Tag := 'ol' else Tag := 'ul';
      SB.Append('<').Append(Tag).Append('>'#10);
      for Item in ANode.Children do
        SB.Append('<li>').Append(Paras(Item, True)).Append('</li>'#10);
      SB.Append('</').Append(Tag).Append('>'#10);
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function THtmlDocWriter.Table(ANode: TDocNode): string;
var
  SB: TStringBuilder;
  Row, Cell: TDocNode;
  Cls, Align: string;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('<table class="doxtable">'#10);
    for Row in ANode.Children do
    begin
      SB.Append('<tr>'#10);
      for Cell in Row.Children do
      begin
        Align := '';
        if Cell.Extra.Contains('align="left"') then Align := 'Left'
        else if Cell.Extra.Contains('align="right"') then Align := 'Right'
        else if Cell.Extra.Contains('align="center"') then Align := 'Center';
        Cls := '';
        if Align <> '' then
        begin
          if Cell.Name = 'th' then
            Cls := ' class="markdownTableHead' + Align + '"'
          else
            Cls := ' class="markdownTableBody' + Align + '"';
        end;
        SB.Append('<').Append(Cell.Name).Append(Cls).Append('>').Append(Paras(Cell, True)).Append('</')
          .Append(Cell.Name).Append('>'#10);
      end;
      SB.Append('</tr>'#10);
    end;
    SB.Append('</table>'#10);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function THtmlDocWriter.Block(ANode: TDocNode): string;
begin
  Result := '';
  case ANode.Kind of
    dnList: Result := List(ANode);
    dnTable: Result := Table(ANode);
    dnSimpleSect: Result := SimpleSect(ANode);
    dnParamList: Result := ParamList(ANode);
    dnBlockQuote: Result := '<blockquote class="doxtable">'#10 + Paras(ANode, False) + '</blockquote>'#10;
    dnHeading: Result := Format('<h%d>%s</h%d>'#10, [ANode.Level, InlineChildren(ANode, True).Trim, ANode.Level]);
    dnHRuler: Result := '<hr/>'#10;
    dnVerbatim: Result := Fragment(ANode);
  end;
end;

function THtmlDocWriter.Para(ANode: TDocNode; ABare: Boolean): string;
var
  SB: TStringBuilder;
  Buf: string;
  C: TDocNode;

  procedure Flush;
  begin
    Buf := Trim(Buf);
    if Buf <> '' then
    begin
      if ABare and (SB.Length = 0) then
        SB.Append(Buf).Append(#10)
      else
        SB.Append('<p>').Append(Buf).Append('</p>'#10);
    end;
    Buf := '';
  end;

begin
  SB := TStringBuilder.Create;
  try
    Buf := '';
    for C in ANode.Children do
      if IsBlock(C) then
      begin
        Flush;
        SB.Append(Block(C));
      end
      else
        Buf := Buf + Inline_(C, True);
    Flush;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function THtmlDocWriter.Paras(ANode: TDocNode; ABare: Boolean): string;
var
  C: TDocNode;
  Count: Integer;
begin
  Count := 0;
  for C in ANode.Children do
    if C.Kind = dnPara then
      Inc(Count);
  Result := '';
  for C in ANode.Children do
    if C.Kind = dnPara then
      Result := Result + Para(C, ABare and (Count = 1));
  if ABare and (Count = 1) then
    Result := Result.TrimRight;
end;

function THtmlDocWriter.Section(ANode: TDocNode; ALevel: Integer): string;
var
  C: TDocNode;
  H: Integer;
begin
  H := ALevel;
  if H > 6 then
    H := 6;
  if (ANode.Name = 'page') or (ANode.Name = 'mainpage') then
  begin
    // the title is shown by the page itself; the sub-sections start at level 1
    Result := Anchor(ANode.Id) + Paras(ANode, False);
    for C in ANode.Children do
      if C.Kind = dnSection then
        Result := Result + Section(C, ALevel);
    Exit;
  end;
  Result := Format(#10#10'<h%d class="doxsection">%s%s</h%d>'#10, [H, Anchor(ANode.Id), HtmlEscape(ANode.Text), H]);
  Result := Result + Paras(ANode, False);
  for C in ANode.Children do
    if C.Kind = dnSection then
      Result := Result + Section(C, ALevel + 1);
end;

function THtmlDocWriter.Prepare(const AText: string; AScope: TDefinition): TDocNode;
var
  T0: Int64;
begin
  FScope := AScope;
  T0 := Tick;
  Result := ParseDoc(AText);
  Add('doc: ParseDoc', T0);
end;

function THtmlDocWriter.Render(const AText: string; AScope: TDefinition): string;
var
  Root, C: TDocNode;
begin
  Result := '';
  if Trim(AText) = '' then
    Exit;
  Root := Prepare(AText, AScope);
  try
    Result := Paras(Root, False);
    for C in Root.Children do
      if C.Kind = dnSection then
        Result := Result + Section(C, 1);
  finally
    Root.Free;
  end;
end;

function THtmlDocWriter.RenderBrief(const AText: string; AScope: TDefinition): string;
var
  Root, C: TDocNode;
  T0: Int64;
begin
  Result := '';
  if Trim(AText) = '' then
    Exit;
  Root := Prepare(AText, AScope);
  try
    T0 := Tick;
    for C in Root.Children do
      if C.Kind = dnPara then
      begin
        Result := Trim(InlineChildren(C, True));
        Break;
      end;
    Add('doc: brief inline html', T0);
  finally
    Root.Free;
  end;
end;

end.
