unit DoxyPas.Doc.Nodes;

{ Documentation AST (Doxygen's docnode.h). One class with a Kind instead of ~50 node classes: the shape of a node
  is given by its Kind (see TDocNodeKind). }

interface

uses
  System.Generics.Collections;

type
  TDocNodeKind = (
    dnRoot,        // list of paragraphs / sections
    dnPara,        // paragraph: inline nodes and block nodes (lists, tables, simple sections, ...)
    dnText,        // Text = literal text (may contain spaces)
    dnStyle,       // Name = bold|italic|code|emphasis|underline|strike|sub|sup|small|center|kbd|var|samp|div|span|ins|del
    dnSymbol,      // Text = decoded character(s) of an entity such as &amp;
    dnUrl,         // Text = url, Name = 'email' for mail addresses
    dnLink,        // <a href> or \link: Text = target, children = visible text
    dnRef,         // \ref: Text = target, children = visible text ('' = use the target)
    dnAnchor,      // Text = anchor id
    dnLineBreak,
    dnHRuler,
    dnVerbatim,    // Name = code|verbatim|htmlonly|latexonly|xmlonly|manonly|rtfonly|docbookonly|dot|msc|uml|mermaid;
                   // Text = body; Extra = language / file extension
    dnFormula,     // Text = TeX; Name = inline|display
    dnList,        // Name = ul|ol
    dnListItem,
    dnSimpleSect,  // Name = see|return|author|version|since|date|note|warning|pre|post|copyright|invariant|remark|
                   // attention|important|todo|test|bug|deprecated|rcs|par; children[0] is the title for 'par'
    dnParamList,   // Name = param|retval|exception|templateparam
    dnParamItem,   // Text = parameter names joined by ','; Extra = in|out|inout|''; children = description
    dnSection,     // Name = section|subsection|subsubsection|paragraph|subparagraph|page|mainpage;
                   // Id = label; Text = title; children = content
    dnHeading,     // Level = 1..6 (HTML <h1>..<h6> / Markdown headers)
    dnTable,
    dnTableRow,
    dnTableCell,   // Name = td|th
    dnImage,       // Text = file or url, Name = html|latex|..., Extra = alt/caption
    dnCite,        // Text = citation id
    dnBlockQuote,
    dnCopyDoc,     // Name = copydoc|copybrief|copydetails|inheritdoc, Text = target
    dnInclude);    // Name = include|dontinclude|snippet|..., Text = file

  TDocNode = class
  strict private
    FParent: TDocNode;
    FChildren: TObjectList<TDocNode>;
  public
    Kind: TDocNodeKind;
    Name: string;
    Text: string;
    Id: string;
    Extra: string;
    Level: Integer;
    constructor Create(AKind: TDocNodeKind);
    destructor Destroy; override;
    function Add(AChild: TDocNode): TDocNode;
    /// <summary>Adds a text node (merged with a preceding text node).</summary>
    procedure AddText(const AText: string);
    property Parent: TDocNode read FParent;
    property Children: TObjectList<TDocNode> read FChildren;
    /// <summary>Plain text of this node and its children (no markup).</summary>
    function PlainText: string;
  end;

implementation

uses
  System.SysUtils;

constructor TDocNode.Create(AKind: TDocNodeKind);
begin
  inherited Create;
  Kind := AKind;
  FChildren := TObjectList<TDocNode>.Create(True);
end;

destructor TDocNode.Destroy;
begin
  FChildren.Free;
  inherited;
end;

function TDocNode.Add(AChild: TDocNode): TDocNode;
begin
  AChild.FParent := Self;
  FChildren.Add(AChild);
  Result := AChild;
end;

procedure TDocNode.AddText(const AText: string);
var
  Last: TDocNode;
begin
  if AText = '' then
    Exit;
  if (FChildren.Count > 0) and (FChildren.Last.Kind = dnText) then
  begin
    Last := FChildren.Last;
    Last.Text := Last.Text + AText;
  end
  else
  begin
    Last := Add(TDocNode.Create(dnText));
    Last.Text := AText;
  end;
end;

function TDocNode.PlainText: string;
var
  C: TDocNode;
begin
  case Kind of
    dnText, dnSymbol, dnUrl: Result := Text;
    dnLineBreak: Result := ' ';
  else
    Result := '';
  end;
  for C in FChildren do
    Result := Result + C.PlainText;
end;

end.
