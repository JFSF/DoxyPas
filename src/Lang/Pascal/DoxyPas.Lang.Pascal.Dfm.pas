unit DoxyPas.Lang.Pascal.Dfm;

{ Delphi form files in text format (.dfm, .fmx): the component tree becomes a documentation page listing every
  component with its class, caption, event handlers and (PASCAL_DFM_PROPERTIES) the values of its properties; the items of
  collections (columns, list items...) are components of their own. Binary forms (signature TPF0) are read too. }

interface

uses
  DoxyPas.Model.Entry;

/// <summary>Builds a page entry (ekPage) for a form file (text or binary); nil with AError set if it is not a form.
/// AProperties: the page also lists the property values of every component.</summary>
function ParseDfmFile(const AFileName: string; AProperties: Boolean; out AError: string): TEntry; overload;
function ParseDfmFile(const AFileName: string; out AError: string): TEntry; overload;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Math,
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
      if SameText(Line, 'item') and (Stack.Count > 0) and (Stack.Last.Kind = 'collection') then
      begin
        Node := TDfmNode.Create;
        Node.Kind := 'item';
        Node.Name := Stack.Last.Name + '[' + Stack.Last.Children.Count.ToString + ']';
        Node.ClassName := 'item';
        Stack.Last.Children.Add(Node);
        Stack.Add(Node);
        Continue;
      end;
      if (Line = 'end>') or (Line = '>') then
      begin
        if (Line = 'end>') and (Stack.Count > 0) and (Stack.Last.Kind = 'item') then
          Stack.Delete(Stack.Count - 1);
        if (Stack.Count > 0) and (Stack.Last.Kind = 'collection') then
          Stack.Delete(Stack.Count - 1);
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
      if Value = '<' then                 // a collection: its items are the lines up to "end>"
      begin
        Node := TDfmNode.Create;
        Node.Kind := 'collection';
        Node.Name := Name;
        Node.ClassName := 'collection';
        Stack.Last.Children.Add(Node);
        Stack.Add(Node);
        Continue;
      end;
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

type
  EDfmFormat = class(Exception);

  // Delphi's binary form streams (signature TPF0, the TReader format): the same tree as the text parser makes.
  TBinReader = class
  strict private
    FData: TBytes;
    FPos: Integer;
    function Next: Byte;
    function ReadByte: Byte;
    function ReadInt(ASize: Integer; ASigned: Boolean): Int64;
    function ReadShortStr: string;
    function ReadText(ALen: Integer; AEncoding: TEncoding): string;
    function ReadAnsiText(ALen: Integer): string;
    function ReadValue(out AIsString, AIsIdent: Boolean): string;
    procedure ReadProps(ANode: TDfmNode);
    procedure ReadCollection(ANode: TDfmNode; const AName: string);
    function ReadObject: TDfmNode;
  public
    constructor Create(const AData: TBytes);
    function ReadForm: TDfmNode;
  end;

const
  vaNull = 0; vaList = 1; vaInt8 = 2; vaInt16 = 3; vaInt32 = 4; vaExtended = 5; vaString = 6; vaIdent = 7;
  vaFalse = 8; vaTrue = 9; vaBinary = 10; vaSet = 11; vaLString = 12; vaNil = 13; vaCollection = 14; vaSingle = 15;
  vaCurrency = 16; vaDate = 17; vaWString = 18; vaInt64 = 19; vaUTF8String = 20; vaDouble = 21;

constructor TBinReader.Create(const AData: TBytes);
begin
  inherited Create;
  FData := AData;
end;

function TBinReader.Next: Byte;
begin
  if FPos >= Length(FData) then
    raise EDfmFormat.Create('the form ends too soon');
  Result := FData[FPos];
end;

function TBinReader.ReadByte: Byte;
begin
  Result := Next;
  Inc(FPos);
end;

function TBinReader.ReadInt(ASize: Integer; ASigned: Boolean): Int64;
var
  I: Integer;
  U: UInt64;
begin
  if FPos + ASize > Length(FData) then
    raise EDfmFormat.Create('the form ends too soon');
  U := 0;
  for I := ASize - 1 downto 0 do
    U := (U shl 8) or FData[FPos + I];
  Inc(FPos, ASize);
  Result := Int64(U);
  if ASigned and (ASize < 8) and (U >= UInt64(1) shl (ASize * 8 - 1)) then
    Result := Int64(U) - (Int64(1) shl (ASize * 8));
end;

function TBinReader.ReadText(ALen: Integer; AEncoding: TEncoding): string;
begin
  if (ALen < 0) or (FPos + ALen > Length(FData)) then
    raise EDfmFormat.Create('a string goes past the end of the form');
  Result := AEncoding.GetString(FData, FPos, ALen);
  Inc(FPos, ALen);
end;

// A one-byte-per-character string of a form: UTF-8 when it is valid UTF-8 (what the IDE writes today), else the ANSI code
// page (forms of older versions).
function TBinReader.ReadAnsiText(ALen: Integer): string;
begin
  try
    Result := ReadText(ALen, TEncoding.UTF8);
  except
    on EEncodingError do
    begin
      Dec(FPos, ALen);
      Result := ReadText(ALen, TEncoding.ANSI);
    end;
  end;
end;

function TBinReader.ReadShortStr: string;
begin
  Result := ReadAnsiText(ReadByte);
end;

function QuotedText(const S: string): string;
var
  C: Char;
begin
  Result := '';
  for C in S do
    if C = '''' then
      Result := Result + ''''''
    else if C < ' ' then
      Result := Result + ' '
    else
      Result := Result + C;
  Result := '''' + Result + '''';
end;

function UnquotedText(const S: string): string;
begin
  Result := S;
  if (Length(S) >= 2) and (S[1] = '''') and (S[Length(S)] = '''') then
    Result := Copy(S, 2, Length(S) - 2).Replace('''''', '''');
end;

// The value in the form of a text form: strings quoted, identifiers bare, sets and lists in brackets.
function TBinReader.ReadValue(out AIsString, AIsIdent: Boolean): string;
var
  VT: Byte;
  Items: TStringList;
  AllStrings, S, I: Boolean;
  Mant: UInt64;
  SE, Exp: Integer;
  V: Double;
  Name: string;
begin
  AIsString := False;
  AIsIdent := False;
  VT := ReadByte;
  case VT of
    vaNull: Result := '';
    vaList:
      begin
        Items := TStringList.Create;
        try
          AllStrings := True;
          while Next <> vaNull do
          begin
            Name := ReadValue(S, I);
            if S then
              Items.Add(UnquotedText(Name))
            else
            begin
              AllStrings := False;
              Items.Add(Name);
            end;
          end;
          ReadByte;
          if AllStrings and (Items.Count > 0) then
            Result := '''[' + string.Join(' / ', Items.ToStringArray) + ']'''
          else
            Result := '(' + string.Join('; ', Items.ToStringArray) + ')';
        finally
          Items.Free;
        end;
      end;
    vaInt8: Result := ReadInt(1, True).ToString;
    vaInt16: Result := ReadInt(2, True).ToString;
    vaInt32: Result := ReadInt(4, True).ToString;
    vaInt64: Result := ReadInt(8, True).ToString;
    vaExtended:
      begin
        Mant := UInt64(ReadInt(8, False));
        SE := Integer(ReadInt(2, False));
        Exp := SE and $7FFF;
        if (Exp = 0) and (Mant = 0) then
          V := 0
        else if Exp = $7FFF then
          V := 0
        else
          V := Mant * Power(2, Exp - 16383 - 63);
        if SE and $8000 <> 0 then
          V := -V;
        Result := FloatToStr(V, TFormatSettings.Invariant);
      end;
    vaSingle: Result := FloatToStr(PSingle(@FData[FPos + 0])^, TFormatSettings.Invariant);
    vaDouble, vaDate:
      begin
        if FPos + 8 > Length(FData) then
          raise EDfmFormat.Create('the form ends too soon');
        Result := FloatToStr(PDouble(@FData[FPos])^, TFormatSettings.Invariant);
        Inc(FPos, 8);
      end;
    vaCurrency:
      Result := FloatToStr(ReadInt(8, True) / 10000, TFormatSettings.Invariant);
    vaString:
      begin
        Result := QuotedText(ReadAnsiText(ReadByte));
        AIsString := True;
      end;
    vaLString:
      begin
        Result := QuotedText(ReadAnsiText(Integer(ReadInt(4, False))));
        AIsString := True;
      end;
    vaWString:
      begin
        Result := QuotedText(ReadText(Integer(ReadInt(4, False)) * 2, TEncoding.Unicode));
        AIsString := True;
      end;
    vaUTF8String:
      begin
        Result := QuotedText(ReadText(Integer(ReadInt(4, False)), TEncoding.UTF8));
        AIsString := True;
      end;
    vaIdent:
      begin
        Result := ReadShortStr;
        AIsIdent := True;
      end;
    vaFalse: Result := 'False';
    vaTrue: Result := 'True';
    vaNil: Result := 'nil';
    vaBinary:
      begin
        Inc(FPos, Integer(ReadInt(4, False)));
        if FPos > Length(FData) then
          raise EDfmFormat.Create('binary data go past the end of the form');
        Result := '(binary data)';
      end;
    vaSet:
      begin
        Items := TStringList.Create;
        try
          Name := ReadShortStr;
          while Name <> '' do
          begin
            Items.Add(Name);
            Name := ReadShortStr;
          end;
          Result := '[' + string.Join(', ', Items.ToStringArray) + ']';
        finally
          Items.Free;
        end;
      end;
  else
    raise EDfmFormat.CreateFmt('unknown value type %d', [VT]);
  end;
end;

procedure TBinReader.ReadCollection(ANode: TDfmNode; const AName: string);
var
  Coll, Item: TDfmNode;
begin
  Coll := TDfmNode.Create;
  Coll.Kind := 'collection';
  Coll.Name := AName;
  Coll.ClassName := 'collection';
  ANode.Children.Add(Coll);
  ReadByte;                                  // vaCollection
  while Next <> vaNull do
  begin
    if Next in [vaInt8, vaInt16, vaInt32] then
    begin
      case ReadByte of
        vaInt8: ReadInt(1, True);
        vaInt16: ReadInt(2, True);
      else
        ReadInt(4, True);
      end;
    end;
    if ReadByte <> vaList then
      raise EDfmFormat.Create('a collection item does not start with a list');
    Item := TDfmNode.Create;
    Item.Kind := 'item';
    Item.Name := AName + '[' + Coll.Children.Count.ToString + ']';
    Item.ClassName := 'item';
    Coll.Children.Add(Item);
    ReadProps(Item);
  end;
  ReadByte;
end;

// The properties of an object or an item, up to the byte 0 that ends them.
procedure TBinReader.ReadProps(ANode: TDfmNode);
var
  PName, Disp: string;
  IsStr, IsIdent: Boolean;
begin
  while Next <> vaNull do
  begin
    PName := ReadShortStr;
    if Next = vaCollection then
      ReadCollection(ANode, PName)
    else
    begin
      Disp := ReadValue(IsStr, IsIdent);
      if IsStr and (SameText(PName, 'Caption') or (SameText(PName, 'Text') and (ANode.Caption = ''))) then
        ANode.Caption := UnquotedText(Disp)
      else if IsIdent and (Length(PName) > 2) and (Copy(PName, 1, 2) = 'On') and (Pos('.', PName) = 0) then
        ANode.Events.Add(PName + ' = ' + Disp)
      else
      begin
        if Length(Disp) > 80 then
          Disp := Copy(Disp, 1, 77) + '...';
        ANode.Props.Add(PName + ' = ' + Disp);
      end;
    end;
  end;
  ReadByte;
end;

function TBinReader.ReadObject: TDfmNode;
var
  Flags: Integer;
begin
  Result := TDfmNode.Create;
  try
    Result.Kind := 'object';
    if (Next and $F0) = $F0 then
    begin
      Flags := ReadByte and $0F;
      if Flags and 2 <> 0 then                       // ffChildPos: the position among the siblings
        case ReadByte of
          vaInt8: ReadInt(1, True);
          vaInt16: ReadInt(2, True);
        else
          ReadInt(4, True);
        end;
      if Flags and 1 <> 0 then
        Result.Kind := 'inherited'
      else if Flags and 4 <> 0 then
        Result.Kind := 'inline';
    end;
    Result.ClassName := ReadShortStr;
    Result.Name := ReadShortStr;
    if Result.ClassName = '' then
      raise EDfmFormat.Create('an object without a class');
    ReadProps(Result);
    while Next <> vaNull do
      Result.Children.Add(ReadObject);
    ReadByte;
  except
    Result.Free;
    raise;
  end;
end;

function TBinReader.ReadForm: TDfmNode;
begin
  if (Length(FData) < 5) or (FData[0] <> Ord('T')) or (FData[1] <> Ord('P')) or (FData[2] <> Ord('F')) or
    (FData[3] <> Ord('0')) then
    raise EDfmFormat.Create('not a binary form');
  FPos := 4;
  Result := ReadObject;
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
  if (ANode.Kind <> 'object') and (ANode.Kind <> 'collection') and (ANode.Kind <> 'item') then
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

// The text of a text form: UTF-8 (BOM or not), else the ANSI code page.
function TextOf(const ABytes: TBytes): string;
var
  Enc: TEncoding;
  Skip: Integer;
begin
  Enc := nil;
  Skip := TEncoding.GetBufferEncoding(ABytes, Enc, TEncoding.UTF8);
  try
    Result := Enc.GetString(ABytes, Skip, Length(ABytes) - Skip);   // UTF-8 raises on an invalid sequence
  except
    on EEncodingError do
      Result := TEncoding.ANSI.GetString(ABytes, Skip, Length(ABytes) - Skip);
  end;
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
  Bytes: TBytes;
  Reader: TBinReader;
begin
  Result := nil;
  AError := '';
  Form := nil;
  try
    Bytes := TFile.ReadAllBytes(AFileName);
  except
    on E: Exception do
    begin
      AError := E.Message;
      Exit;
    end;
  end;
  if (Length(Bytes) >= 4) and (Bytes[0] = Ord('T')) and (Bytes[1] = Ord('P')) and (Bytes[2] = Ord('F')) and
    (Bytes[3] = Ord('0')) then
  begin
    Reader := TBinReader.Create(Bytes);
    try
      try
        Form := Reader.ReadForm;
      except
        on E: Exception do
        begin
          AError := 'damaged binary form: ' + E.Message;
          Exit;
        end;
      end;
    finally
      Reader.Free;
    end;
  end
  else
  begin
    Text := TextOf(Bytes);
    if (Length(Text) < 6) or not (Text.TrimLeft.StartsWith('object', True) or Text.TrimLeft.StartsWith('inherited', True)
      or Text.TrimLeft.StartsWith('inline', True)) then
    begin
      AError := 'not a form file';
      Exit;
    end;
    Form := ParseForm(Text.Replace(#13#10, #10).Split([#10]));
  end;
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
