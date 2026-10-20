unit DoxyPas.Output.XmlWriter;

{ Minimal streaming XML writer: escaping, attributes, optional indentation. Elements with mixed content (text
  between tags) must not be indented, so indentation is explicit (Indent / NewLine). }

interface

uses
  System.SysUtils;

type
  TXmlWriter = class
  strict private
    FSB: TStringBuilder;
    FDepth: Integer;
    procedure Attrs(const AAttrs: array of string);
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>The XML declaration.</summary>
    procedure Declaration;
    /// <summary>Line break followed by indentation for the current depth.</summary>
    procedure NewLine;
    /// <summary>Opens AName; AAttrs holds name/value pairs. Depth increases (used by NewLine).</summary>
    procedure Open(const AName: string; const AAttrs: array of string);
    procedure Close(const AName: string);
    /// <summary>Empty element: &lt;name a="b"/&gt;.</summary>
    procedure Empty(const AName: string; const AAttrs: array of string);
    /// <summary>Escaped character data.</summary>
    procedure Text(const AText: string);
    /// <summary>&lt;name a="b"&gt;text&lt;/name&gt; on the current line.</summary>
    procedure Leaf(const AName, AText: string; const AAttrs: array of string);
    /// <summary>Block element on its own line(s): NewLine + Open ... (caller writes content) ... Close + NewLine.</summary>
    procedure Raw(const AText: string);
    function ToString: string; override;
    property Depth: Integer read FDepth;
  end;

function XmlEscape(const AText: string): string;
function XmlEscapeAttr(const AText: string): string;
/// <summary>"yes" or "no" (DoxBool).</summary>
function YesNo(AValue: Boolean): string;

implementation

function YesNo(AValue: Boolean): string;
begin
  if AValue then Result := 'yes' else Result := 'no';
end;

function XmlEscape(const AText: string): string;
var
  C: Char;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    for C in AText do
      case C of
        '&': SB.Append('&amp;');
        '<': SB.Append('&lt;');
        '>': SB.Append('&gt;');
        #0..#8, #11, #12, #14..#31: ; // not allowed in XML 1.0
      else
        SB.Append(C);
      end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function XmlEscapeAttr(const AText: string): string;
begin
  Result := XmlEscape(AText).Replace('"', '&quot;').Replace(#10, '&#10;').Replace(#13, '&#13;').Replace(#9, '&#9;');
end;

constructor TXmlWriter.Create;
begin
  inherited Create;
  FSB := TStringBuilder.Create;
end;

destructor TXmlWriter.Destroy;
begin
  FSB.Free;
  inherited;
end;

procedure TXmlWriter.Declaration;
begin
  FSB.Append('<?xml version=''1.0'' encoding=''UTF-8'' standalone=''no''?>').Append(#10);
end;

procedure TXmlWriter.NewLine;
begin
  FSB.Append(#10).Append(StringOfChar(' ', FDepth * 2));
end;

procedure TXmlWriter.Attrs(const AAttrs: array of string);
var
  I: Integer;
begin
  I := 0;
  while I < High(AAttrs) do
  begin
    FSB.Append(' ').Append(AAttrs[I]).Append('="').Append(XmlEscapeAttr(AAttrs[I + 1])).Append('"');
    Inc(I, 2);
  end;
end;

procedure TXmlWriter.Open(const AName: string; const AAttrs: array of string);
begin
  FSB.Append('<').Append(AName);
  Attrs(AAttrs);
  FSB.Append('>');
  Inc(FDepth);
end;

procedure TXmlWriter.Close(const AName: string);
begin
  Dec(FDepth);
  FSB.Append('</').Append(AName).Append('>');
end;

procedure TXmlWriter.Empty(const AName: string; const AAttrs: array of string);
begin
  FSB.Append('<').Append(AName);
  Attrs(AAttrs);
  FSB.Append('/>');
end;

procedure TXmlWriter.Text(const AText: string);
begin
  FSB.Append(XmlEscape(AText));
end;

procedure TXmlWriter.Leaf(const AName, AText: string; const AAttrs: array of string);
begin
  FSB.Append('<').Append(AName);
  Attrs(AAttrs);
  FSB.Append('>').Append(XmlEscape(AText)).Append('</').Append(AName).Append('>');
end;

procedure TXmlWriter.Raw(const AText: string);
begin
  FSB.Append(AText);
end;

function TXmlWriter.ToString: string;
begin
  Result := FSB.ToString;
end;

end.
