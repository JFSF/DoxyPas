unit DoxyPas.Comments.XmlDoc;

{ Delphi / .NET style XML documentation (<summary>, <param name="x">, <returns> ...) converted to Doxygen
  commands and HTML, so the normal documentation pipeline can process it. }

interface

/// <summary>True if the text contains XML documentation tags (and not just HTML such as &lt;b&gt;).</summary>
function HasXmlDoc(const AText: string): Boolean;

/// <summary>Converts XML documentation tags to Doxygen commands; text without such tags is returned unchanged.</summary>
function ConvertXmlDoc(const AText: string): string;

implementation

uses
  System.SysUtils,
  System.Character,
  System.Generics.Collections,
  System.RegularExpressions;

function HasXmlDoc(const AText: string): Boolean;
begin
  Result := TRegEx.IsMatch(AText, '<\s*/?\s*(summary|param|returns?|remarks|exception|typeparam|inheritdoc|paramref|' +
    'seealso|value|example)\b', [roIgnoreCase]) or TRegEx.IsMatch(AText, '<\s*see\s+(cref|href|langword)\s*=',
    [roIgnoreCase]);
end;

function Attr(const ATag, AName: string): string;
var
  M: TMatch;
begin
  M := TRegEx.Match(ATag, '\b' + AName + '\s*=\s*(?:"([^"]*)"|''([^'']*)'')', [roIgnoreCase]);
  Result := '';
  if M.Success then
  begin
    // a group that did not take part in the match is missing from Groups
    if M.Groups.Count > 1 then
      Result := M.Groups[1].Value;
    if (Result = '') and (M.Groups.Count > 2) then
      Result := M.Groups[2].Value;
  end;
end;

{ "T:Unit.TFoo", "M:Unit.TFoo.Bar(System.Int32)" -> "Unit.TFoo", "Unit.TFoo.Bar" }
function CleanCref(const ACref: string): string;
var
  P: Integer;
begin
  Result := ACref;
  if (Length(Result) > 2) and (Result[2] = ':') and CharInSet(Result[1], ['T', 'M', 'P', 'F', 'E', 'N']) then
    Result := Copy(Result, 3, MaxInt);
  Result := Result.Replace('{', '<').Replace('}', '>');
  P := Pos('(', Result);
  if P > 0 then
    Result := Copy(Result, 1, P - 1);
end;

function ConvertXmlDoc(const AText: string): string;
var
  SB: TStringBuilder;
  ListKinds: TStack<string>;
  P, E, S: Integer;
  Raw, Name, Tag, Cref, Href, Lang, Kind: string;
  Closing, SelfClosed, InSee: Boolean;
  SeeCref: string;
begin
  if not HasXmlDoc(AText) then
    Exit(AText);
  SB := TStringBuilder.Create;
  ListKinds := TStack<string>.Create;
  InSee := False;
  SeeCref := '';
  try
    P := 1;
    while P <= Length(AText) do
    begin
      if AText[P] <> '<' then
      begin
        SB.Append(AText[P]);
        Inc(P);
        Continue;
      end;
      E := Pos('>', AText, P);
      if E = 0 then
      begin
        SB.Append(Copy(AText, P, MaxInt));
        Break;
      end;
      Tag := Copy(AText, P, E - P + 1);
      Raw := Copy(Tag, 2, Length(Tag) - 2);
      Closing := Raw.StartsWith('/');
      if Closing then
        Raw := Copy(Raw, 2, MaxInt);
      SelfClosed := Raw.EndsWith('/');
      S := 1;
      while (S <= Length(Raw)) and (Raw[S].IsLetterOrDigit) do
        Inc(S);
      Name := LowerCase(Copy(Raw, 1, S - 1));
      Raw := Copy(Raw, S, MaxInt);
      P := E + 1;

      if Name = 'summary' then
        if Closing then SB.Append(#10#10) else SB.Append(#10'\brief ')
      else if Name = 'remarks' then
        if Closing then SB.Append(#10#10) else SB.Append(#10'\remark ')
      else if (Name = 'returns') or (Name = 'return') then
        if Closing then SB.Append(#10) else SB.Append(#10'\return ')
      else if Name = 'value' then
        if Closing then SB.Append(#10#10) else SB.Append(#10'\par Value:'#10)
      else if Name = 'example' then
        if Closing then SB.Append(#10#10) else SB.Append(#10'\par Example:'#10)
      else if Name = 'param' then
        if Closing then SB.Append(#10) else SB.Append(#10'\param ').Append(Attr(Raw, 'name')).Append(' ')
      else if Name = 'typeparam' then
        if Closing then SB.Append(#10) else SB.Append(#10'\tparam ').Append(Attr(Raw, 'name')).Append(' ')
      else if Name = 'exception' then
        if Closing then SB.Append(#10) else SB.Append(#10'\exception ').Append(CleanCref(Attr(Raw, 'cref'))).Append(' ')
      else if Name = 'para' then
        SB.Append(#10#10)
      else if Name = 'c' then
        if Closing then SB.Append('</code>') else SB.Append('<code>')
      else if Name = 'code' then
        if Closing then SB.Append(#10'\endcode'#10) else SB.Append(#10'\code'#10)
      else if Name = 'list' then
      begin
        if Closing then
        begin
          if ListKinds.Count > 0 then
            Kind := ListKinds.Pop
          else
            Kind := 'bullet';
          if Kind = 'number' then SB.Append('</ol>'#10)
          else if Kind = 'table' then SB.Append('</table>'#10)
          else SB.Append('</ul>'#10);
        end
        else
        begin
          Kind := LowerCase(Attr(Raw, 'type'));
          if Kind = '' then
            Kind := 'bullet';
          ListKinds.Push(Kind);
          if Kind = 'number' then SB.Append(#10'<ol>'#10)
          else if Kind = 'table' then SB.Append(#10'<table>'#10)
          else SB.Append(#10'<ul>'#10);
        end;
      end
      else if (Name = 'item') or (Name = 'listheader') then
      begin
        if (ListKinds.Count > 0) and (ListKinds.Peek = 'table') then
        begin
          if Closing then SB.Append('</tr>'#10)
          else SB.Append('<tr>')
        end
        else if Name = 'item' then
          if Closing then SB.Append('</li>'#10) else SB.Append('<li>');
      end
      else if Name = 'term' then
      begin
        if (ListKinds.Count > 0) and (ListKinds.Peek = 'table') then
          if Closing then SB.Append('</td>') else SB.Append('<td>')
        else if Closing then SB.Append('</b>: ') else SB.Append('<b>');
      end
      else if Name = 'description' then
      begin
        if (ListKinds.Count > 0) and (ListKinds.Peek = 'table') then
          if Closing then SB.Append('</td>') else SB.Append('<td>');
      end
      else if Name = 'see' then
      begin
        Cref := CleanCref(Attr(Raw, 'cref'));
        Href := Attr(Raw, 'href');
        Lang := Attr(Raw, 'langword');
        if Closing then
        begin
          if InSee then
            SB.Append('"');
          if Href <> '' then
            SB.Append('</a>');
          InSee := False;
        end
        else if Lang <> '' then
          SB.Append(Lang)
        else if Href <> '' then
        begin
          SB.Append('<a href="').Append(Href).Append('">');
          if SelfClosed then
            SB.Append(Href).Append('</a>');
        end
        else if SelfClosed then
          SB.Append('\ref ').Append(Cref).Append(' ')
        else
        begin
          SB.Append('\ref ').Append(Cref).Append(' "');
          InSee := True;
        end;
      end
      else if Name = 'seealso' then
      begin
        if not Closing then
          SB.Append(#10'\sa ').Append(CleanCref(Attr(Raw, 'cref'))).Append(#10);
      end
      else if (Name = 'paramref') or (Name = 'typeparamref') then
        SB.Append('\p ').Append(Attr(Raw, 'name')).Append(' ')
      else if Name = 'inheritdoc' then
      begin
        if not Closing then
          if Attr(Raw, 'cref') <> '' then
            SB.Append(#10'\copydoc ').Append(CleanCref(Attr(Raw, 'cref'))).Append(#10)
          else
            SB.Append(#10'\inheritdoc'#10);
      end
      else
        SB.Append(Tag); // HTML or unknown tag: unchanged
    end;
    Result := SB.ToString.Trim([#10, ' ']);
  finally
    ListKinds.Free;
    SB.Free;
  end;
end;

end.
