unit DoxyPas.Lang.Pascal.Dfm;

{ Delphi form files in text format (.dfm, .fmx): the component tree becomes a documentation page listing every
  component with its class, caption and event handlers. Binary forms are not read. }

interface

uses
  DoxyPas.Model.Entry;

/// <summary>Builds a page entry (ekPage) for a form file; nil with AError set if the file is not a text form.</summary>
function ParseDfmFile(const AFileName: string; out AError: string): TEntry;

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
    Children: TObjectList<TDfmNode>;
    constructor Create;
    destructor Destroy; override;
  end;

constructor TDfmNode.Create;
begin
  inherited;
  Events := TList<string>.Create;
  Children := TObjectList<TDfmNode>.Create(True);
end;

destructor TDfmNode.Destroy;
begin
  Children.Free;
  Events.Free;
  inherited;
end;

function ParseForm(const ALines: TArray<string>): TDfmNode;
var
  Stack: TList<TDfmNode>;
  I: Integer;
  Line, Name, Value, Closer: string;
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
          while (I < Length(ALines)) and not ((Value <> '') and (Value[Length(Value)] = Closer[1]) and
            ((Length(Value) > 1) or (Value[1] <> Closer[1]))) do
          begin
            Value := Trim(ALines[I]);
            Inc(I);
          end
        else
          while (Value <> '') and (Value[Length(Value)] = '+') and (I < Length(ALines)) do
          begin
            Value := Trim(ALines[I]);
            Inc(I);
          end;
      end;
      if SameText(Name, 'Caption') or (SameText(Name, 'Text') and (Stack.Last.Caption = '')) then
        Stack.Last.Caption := Unquote(Value)
      else if (Length(Name) > 2) and (Copy(Name, 1, 2) = 'On') and (Pos('.', Name) = 0) and
        TRegEx.IsMatch(Value, '^[A-Za-z_]\w*$') then
        Stack.Last.Events.Add(Name + ' = ' + Value);
    end;
  finally
    Stack.Free;
  end;
end;

procedure WriteNode(ASB: TStringBuilder; ANode: TDfmNode);
var
  E, Prefix: string;
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
  if ANode.Children.Count > 0 then
  begin
    ASB.Append('<ul>');
    for C in ANode.Children do
      WriteNode(ASB, C);
    ASB.Append('</ul>');
  end;
  ASB.Append('</li>'#10);
end;

function ParseDfmFile(const AFileName: string; out AError: string): TEntry;
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
      WriteNode(SB, Form);
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
