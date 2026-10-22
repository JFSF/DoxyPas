unit DoxyPas.Doc.Dump;

{ Compact XML-like rendering of a documentation AST: used by "doxypas --parse --docs" and the tests. }

interface

uses
  DoxyPas.Doc.Nodes;

function DumpDoc(ANode: TDocNode): string;

implementation

uses
  System.SysUtils,
  System.Classes;

const
  ElementNames: array[TDocNodeKind] of string = ('doc', 'p', 'text', 'style', 'sym', 'url', 'link', 'ref', 'anchor',
    'br', 'hr', 'verbatim', 'formula', 'list', 'li', 'sect', 'params', 'param', 'section', 'h', 'table', 'tr', 'td',
    'image', 'cite', 'quote', 'copydoc', 'include', 'toc');

function Esc(const S: string): string;
begin
  Result := S.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;');
end;

function Attr(const AName, AValue: string): string;
begin
  if AValue = '' then
    Result := ''
  else
    Result := ' ' + AName + '="' + Esc(AValue).Replace('"', '&quot;').Replace(#10, '\n') + '"';
end;

procedure DumpTo(SB: TStringBuilder; ANode: TDocNode; AIndent: Integer);
var
  Pad, Tag, Attrs: string;
  C: TDocNode;
  Block: Boolean;
begin
  Pad := StringOfChar(' ', AIndent * 2);
  Tag := ElementNames[ANode.Kind];
  case ANode.Kind of
    dnText:
      begin
        SB.Append(Esc(ANode.Text).Replace(#10, '\n'));
        Exit;
      end;
    dnSymbol:
      begin
        SB.Append('<sym>').Append(Esc(ANode.Text)).Append('</sym>');
        Exit;
      end;
    dnLineBreak, dnHRuler:
      begin
        SB.Append('<').Append(Tag).Append('/>');
        Exit;
      end;
    dnVerbatim:
      begin
        SB.Append('<verbatim').Append(Attr('kind', ANode.Name)).Append(Attr('lang', ANode.Extra)).Append('>')
          .Append(Esc(ANode.Text).Replace(#10, '\n')).Append('</verbatim>');
        Exit;
      end;
    dnFormula:
      begin
        SB.Append('<formula').Append(Attr('kind', ANode.Name)).Append('>').Append(Esc(ANode.Text)).Append('</formula>');
        Exit;
      end;
  end;
  Attrs := Attr('name', ANode.Name) + Attr('text', ANode.Text) + Attr('id', ANode.Id) + Attr('extra', ANode.Extra);
  if ANode.Level > 0 then
    Attrs := Attrs + ' level="' + ANode.Level.ToString + '"';
  case ANode.Kind of
    dnStyle:
      begin
        Tag := ANode.Name;
        Attrs := '';
      end;
    dnUrl, dnAnchor, dnCite, dnCopyDoc, dnInclude, dnImage:
      if ANode.Children.Count = 0 then
      begin
        SB.Append('<').Append(Tag).Append(Attrs).Append('/>');
        Exit;
      end;
  end;
  Block := ANode.Kind in [dnRoot, dnList, dnParamList, dnTable, dnTableRow, dnSection, dnBlockQuote];
  SB.Append('<').Append(Tag).Append(Attrs).Append('>');
  for C in ANode.Children do
  begin
    if Block then
      SB.Append(#10).Append(Pad).Append('  ');
    DumpTo(SB, C, AIndent + 1);
  end;
  if Block and (ANode.Children.Count > 0) then
    SB.Append(#10).Append(Pad);
  SB.Append('</').Append(Tag).Append('>');
end;

function DumpDoc(ANode: TDocNode): string;
var
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    DumpTo(SB, ANode, 0);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

end.
