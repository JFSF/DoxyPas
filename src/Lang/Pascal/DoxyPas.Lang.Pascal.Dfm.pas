unit DoxyPas.Lang.Pascal.Dfm;

{ Delphi form files in text format (.dfm, .fmx): the component tree becomes a documentation page listing every
  component with its class, caption, event handlers and (PASCAL_DFM_PROPERTIES) the values of its properties. Binary forms
  are not read. }

interface

uses
  DoxyPas.Model.Entry;

/// <summary>Builds a page entry (ekPage) for a form file; nil with AError set if the file is not a text form.
/// AProperties: the page also lists the property values of every component.</summary>
function ParseDfmFile(const AFileName: string; AProperties: Boolean; out AError: string): TEntry; overload;
function ParseDfmFile(const AFileName: string; out AError: string): TEntry; overload;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.RegularExpressions,
  System.Generics.Collections;

type
  TDfmNode = class
  public
    Name, ClassName, Kind: string;     // Kind: object | inherited | inline
    Caption: string;
    Events: TList<string>;             // "OnClick = ButtonClick"
    Props: TList<string>;              // "Left = 8", "Font.Name = 'Segoe UI'"
    Children: TObjectList<TDfmNode>;
    constructor Create;
    destructor Destroy; override;
  end;

constructor TDfmNode.Create;
begin
  inherited;
  Events := TList<string>.Create;
  Props := TList<string>.Create;
  Children := TObjectList<TDfmNode>.Create(True);
end;

destructor TDfmNode.Destroy;
begin
  Children.Free;
  Props.Free;
  Events.Free;
  inherited;
end;

function ParseForm(const ALines: TArray<string>): TDfmNode;
// What a property value looks like in the page: strings unquoted (and joined), lists with  / , binary data and collections
// summarised, everything else as written; long values are cut.
// 'abc'#13#10'def' -> the text (control characters become spaces)
function DecodeLiteral(const ALiteral: string): string;
var
  M: TMatch;
  Code: Integer;
  S: string;
begin
  Result := '';
  for M in TRegEx.Matches(ALiteral, '''((?:[^'']|'''')*)''|#(\d+)|#\$([0-9A-Fa-f]+)') do
  begin
    if M.Value[1] = '''' then
      Result := Result + M.Groups[1].Value.Replace('''''', '''')
    else
    begin
      if M.Value[2] = '$' then S := M.Groups[3].Value else S := M.Groups[2].Value;
      if M.Value[2] = '$' then Code := StrToIntDef('$' + S, 32) else Code := StrToIntDef(S, 32);
      if Code < 32 then
        Result := Result + ' '
      else
        Result := Result + Char(Code);
    end;
  end;
end;

function DisplayValue(AValue: TStrings): string;
var
  Text, Piece: string;
  M: TMatch;
  Items, N: Integer;
  Parts: TStringList;
begin
  Text := Trim(AValue.Text.Replace(#13#10, ' ').Replace(#10, ' '));
  if Text = '' then
    Exit('');
  case Text[1] of
    '{': Result := '(binary data)';
    '<':
      begin
        Items := 0;
        for N := 0 to AValue.Count - 1 do
          if SameText(Trim(AValue[N]), 'item') or SameText(Trim(AValue[N]), '<item') then
            Inc(Items);
        Result := '(' + Items.ToString + ' items)';
      end;
  else
    Parts := TStringList.Create;
    try
      // string literals: 'text', #13 and #$0D, one after the other
      for M in TRegEx.Matches(Text, '(?:''(?:[^'']|'''')*''|#\d+|#\$[0-9A-Fa-f]+)+') do
        Parts.Add(DecodeLiteral(M.Value));
      if (Parts.Count > 0) and CharInSet(Text[1], ['''', '(', '#']) then
      begin
        if Text[1] = '(' then
          Result := '[' + string.Join(' / ', Parts.ToStringArray) + ']'
        else
          Result := string.Join('', Parts.ToStringArray);
        Result := '''' + Result + '''';
      end
      else
        Result := Text;
    finally
      Parts.Free;
    end;
  end;
  if Length(Result) > 80 then
    Result := Copy(Result, 1, 77) + '...';
end;

var
  Stack: TList<TDfmNode>;
  I: Integer;
  Line, Name, Value, Closer: string;
  Gathered: TStringList;
  M: TMatch;
  Node: TDfmNode;
  P: Integer;

  function Unquote(const S: string): string;
  begin
    Result := S;
    if (Length(S) >= 2) and (S[1] = '''') and (S[Length(S)] = '''') then
      Result := Copy(S, 2, Length(S) - 2).Replace('''''', '''');
  end;

begin
  Result := nil;
  Stack := TList<TDfmNode>.Create;
  Gathered := TStringList.Create;
  try
    I := 0;
    while I < Length(ALines) do
    begin
      Line := Trim(ALines[I]);
      Inc(I);
      M := TRegEx.Match(Line, '^(object|inherited|inline)\s+(?:(\w+)\s*)?:\s*([\w\.<>]+)', [roIgnoreCase]);
      if M.Success then
      begin
        Node := TDfmNode.Create;
        Node.Kind := LowerCase(M.Groups[1].Value);
        Node.Name := M.Groups[2].Value;
        Node.ClassName := M.Groups[3].Value;
        if Stack.Count > 0 then
          Stack.Last.Children.Add(Node)
        else
          Result := Node;
        Stack.Add(Node);
        Continue;
      end;
      if SameText(Line, 'end') then
      begin
        if Stack.Count > 0 then
          Stack.Delete(Stack.Count - 1);
        Continue;
      end;
      P := Pos(' = ', Line);
      if (P = 0) or (Stack.Count = 0) then
        Continue;
      Name := Copy(Line, 1, P - 1);
      Value := Trim(Copy(Line, P + 3, MaxInt));
      // values that continue on the next lines: ( ... ), < ... >, { ... }, 'a' + 'b'
      Gathered.Clear;
      Gathered.Add(Value);
      if Value <> '' then
      begin
        case Value[1] of
          '(': Closer := ')';
          '<': Closer := '>';
          '{': Closer := '}';
        else
          Closer := '';
        end;
        if Closer <> '' then
        begin
          while (I < Length(ALines)) and not ((Value <> '') and (Value[Length(Value)] = Closer[1]) and
            ((Length(Value) > 1) or (Value[1] <> Closer[1]))) do
          begin
            Value := Trim(ALines[I]);
            Gathered.Add(Value);
            Inc(I);
          end;
        end
        else
          while (Value <> '') and (Value[Length(Value)] = '+') and (I < Length(ALines)) do
          begin
            Value := Trim(ALines[I]);
            Gathered.Add(Value);
            Inc(I);
          end;
      end;
      Value := Trim(Gathered[Gathered.Count - 1]);
      if SameText(Name, 'Caption') or (SameText(Name, 'Text') and (Stack.Last.Caption = '')) then
        Stack.Last.Caption := Unquote(DisplayValue(Gathered))
      else if (Length(Name) > 2) and (Copy(Name, 1, 2) = 'On') and (Pos('.', Name) = 0) and
        TRegEx.IsMatch(Value, '^[A-Za-z_]\w*$') then
        Stack.Last.Events.Add(Name + ' = ' + Value)
      else
        Stack.Last.Props.Add(Name + ' = ' + DisplayValue(Gathered));
    end;
  finally
    Gathered.Free;
    Stack.Free;
  end;
end;

function Escaped(const S: string): string;
begin
  Result := S.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;');
end;

procedure WriteNode(ASB: TStringBuilder; ANode: TDfmNode; AProperties: Boolean);
var
  E, Prefix, Props: string;
  C: TDfmNode;
begin
  ASB.Append('<li>');
  Prefix := '';
  if ANode.Kind <> 'object' then
    Prefix := ANode.Kind + ' ';
  ASB.Append('<b>').Append(ANode.Name).Append('</b>: ').Append(Prefix).Append(ANode.ClassName);
  if ANode.Caption <> '' then
    ASB.Append(' "').Append(ANode.Caption.Replace('<', '&lt;').Replace('>', '&gt;')).Append('"');
  for E in ANode.Events do
    ASB.Append('<br/>').Append(E);
  if AProperties and (ANode.Props.Count > 0) then
  begin
    Props := '';
    for E in ANode.Props do
    begin
      if Props <> '' then
        Props := Props + '; ';
      Props := Props + Escaped(E);
    end;
    ASB.Append('<br/><small>').Append(Props).Append('</small>');
  end;
  if ANode.Children.Count > 0 then
  begin
    ASB.Append('<ul>');
    for C in ANode.Children do
      WriteNode(ASB, C, AProperties);
    ASB.Append('</ul>');
  end;
  ASB.Append('</li>'#10);
end;

function ParseDfmFile(const AFileName: string; out AError: string): TEntry;
begin
  Result := ParseDfmFile(AFileName, True, AError);
end;

function ParseDfmFile(const AFileName: string; AProperties: Boolean; out AError: string): TEntry;
var
  Text, Base: string;
  Form: TDfmNode;
  SB: TStringBuilder;
begin
  Result := nil;
  AError := '';
  try
    Text := TFile.ReadAllText(AFileName);
  except
    on E: Exception do
    begin
      AError := E.Message;
      Exit;
    end;
  end;
  if (Length(Text) < 6) or not (Text.TrimLeft.StartsWith('object', True) or Text.TrimLeft.StartsWith('inherited', True)
    or Text.TrimLeft.StartsWith('inline', True)) then
  begin
    AError := 'not a text form (binary .dfm files are not supported)';
    Exit;
  end;
  Form := ParseForm(Text.Replace(#13#10, #10).Split([#10]));
  if Form = nil then
  begin
    AError := 'no form found';
    Exit;
  end;
  try
    Base := TPath.GetFileNameWithoutExtension(AFileName);
    Result := TEntry.Create(ekPage, 'form_' + Base);
    Result.TypeText := 'Form ' + Form.Name + ' (' + ExtractFileName(AFileName) + ')';
    Result.FileName := AFileName;
    Result.Line := 1;
    Result.DocLine := 1;
    SB := TStringBuilder.Create;
    try
      SB.Append('Component tree of ').Append(ExtractFileName(AFileName)).Append('.'#10#10);
      SB.Append('<ul>'#10);
      WriteNode(SB, Form, AProperties);
      SB.Append('</ul>'#10);
      Result.Doc := SB.ToString;
    finally
      SB.Free;
    end;
  finally
    Form.Free;
  end;
end;

end.
