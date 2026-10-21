unit DoxyPas.Config.Layout;

{ The layout file (LAYOUT_FILE, Doxygen's DoxygenLayout.xml): the tabs of the menu and, for the pages of classes,
  units (namespaces) and groups, which sections are shown, in which order and under which title. Only the elements
  DoxyPas has an equivalent for are used, the rest is ignored. "visible" is yes/no or $OPTION (a boolean option of
  the configuration). }

interface

uses
  System.Generics.Collections,
  DoxyPas.Config;

type
  TLayoutEntry = class
  strict private
    FAttrs: TDictionary<string, string>;
    FChildren: TObjectList<TLayoutEntry>;
  public
    Name: string;
    constructor Create(const AName: string);
    destructor Destroy; override;
    property Children: TObjectList<TLayoutEntry> read FChildren;
    function Attr(const AName: string; const ADefault: string = ''): string;
    procedure SetAttr(const AName, AValue: string);
    /// <summary>The first child element called AName, nil when there is none.</summary>
    function Child(const AName: string): TLayoutEntry;
  end;

  TLayout = class
  strict private
    FRoot: TLayoutEntry;
    FConfig: TConfig;
    FLoadedFlag: Boolean;
  public
    /// <summary>Reads the file of LAYOUT_FILE; without one (or when it is missing) nothing is overridden.</summary>
    constructor Create(AConfig: TConfig);
    destructor Destroy; override;
    property Loaded: Boolean read FLoadedFlag;
    /// <summary>The navigation index (the tabs), nil when the layout has none.</summary>
    function NavIndex: TLayoutEntry;
    /// <summary>The layout of a kind of page ("class", "namespace", "group"), nil when there is none.</summary>
    function Page(const AKind: string): TLayoutEntry;
    /// <summary>visible="..." of an element; true when it does not say.</summary>
    function Visible(AEntry: TLayoutEntry): Boolean;
  end;

/// <summary>Parses the text of a layout file; nil when it is not XML with a root element.</summary>
function ParseLayoutText(const AText: string): TLayoutEntry;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  DoxyPas.Core.Log;

{ TLayoutEntry }

constructor TLayoutEntry.Create(const AName: string);
begin
  inherited Create;
  Name := AName;
  FAttrs := TDictionary<string, string>.Create;
  FChildren := TObjectList<TLayoutEntry>.Create(True);
end;

destructor TLayoutEntry.Destroy;
begin
  FChildren.Free;
  FAttrs.Free;
  inherited;
end;

function TLayoutEntry.Attr(const AName, ADefault: string): string;
begin
  if not FAttrs.TryGetValue(AName, Result) then
    Result := ADefault;
end;

procedure TLayoutEntry.SetAttr(const AName, AValue: string);
begin
  FAttrs.AddOrSetValue(AName, AValue);
end;

function TLayoutEntry.Child(const AName: string): TLayoutEntry;
var
  C: TLayoutEntry;
begin
  for C in FChildren do
    if SameText(C.Name, AName) then
      Exit(C);
  Result := nil;
end;

{ parser }

// The predefined entities and numeric character references (&#231; and &#xE7;).
function Unescape(const S: string): string;
var
  I, J, Code: Integer;
  Ref: string;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    J := 0;
    if S[I] = '&' then
      J := Pos(';', S, I);
    if (J > I) and (J - I <= 8) then
    begin
      Ref := Copy(S, I + 1, J - I - 1);
      Code := -1;
      if Ref = 'lt' then Code := Ord('<')
      else if Ref = 'gt' then Code := Ord('>')
      else if Ref = 'quot' then Code := Ord('"')
      else if Ref = 'apos' then Code := Ord('''')
      else if Ref = 'amp' then Code := Ord('&')
      else if (Length(Ref) > 2) and (Ref[1] = '#') and (UpCase(Ref[2]) = 'X') then
        Code := StrToIntDef('$' + Copy(Ref, 3, MaxInt), -1)
      else if (Length(Ref) > 1) and (Ref[1] = '#') then
        Code := StrToIntDef(Copy(Ref, 2, MaxInt), -1);
      if Code >= 0 then
      begin
        Result := Result + Char(Code);
        I := J + 1;
        Continue;
      end;
    end;
    Result := Result + S[I];
    Inc(I);
  end;
end;

function ParseLayoutText(const AText: string): TLayoutEntry;
var
  I, N: Integer;
  Stack: TList<TLayoutEntry>;
  Cur, E: TLayoutEntry;
  Tag, Key, Value: string;
  Closing, SelfClose: Boolean;
  Q: Char;

  procedure SkipSpaces;
  begin
    while (I <= N) and (AText[I] <= ' ') do
      Inc(I);
  end;

begin
  Result := nil;
  Stack := TList<TLayoutEntry>.Create;
  try
    I := 1;
    N := Length(AText);
    while I <= N do
    begin
      if AText[I] <> '<' then
      begin
        Inc(I);
        Continue;
      end;
      if Copy(AText, I, 4) = '<!--' then
      begin
        I := Pos('-->', AText, I + 4);
        if I = 0 then
          Break;
        Inc(I, 3);
        Continue;
      end;
      if (Copy(AText, I, 2) = '<?') or (Copy(AText, I, 2) = '<!') then
      begin
        I := Pos('>', AText, I);
        if I = 0 then
          Break;
        Inc(I);
        Continue;
      end;
      Inc(I);
      Closing := (I <= N) and (AText[I] = '/');
      if Closing then
        Inc(I);
      Tag := '';
      while (I <= N) and not CharInSet(AText[I], [' ', #9, #10, #13, '/', '>']) do
      begin
        Tag := Tag + AText[I];
        Inc(I);
      end;
      if Closing then
      begin
        if Stack.Count > 0 then
          Stack.Delete(Stack.Count - 1);
        I := Pos('>', AText, I);
        if I = 0 then
          Break;
        Inc(I);
        Continue;
      end;
      E := TLayoutEntry.Create(Tag);
      SelfClose := False;
      while I <= N do
      begin
        SkipSpaces;
        if I > N then
          Break;
        if AText[I] = '>' then
        begin
          Inc(I);
          Break;
        end;
        if (AText[I] = '/') then
        begin
          SelfClose := True;
          Inc(I);
          Continue;
        end;
        Key := '';
        while (I <= N) and not CharInSet(AText[I], ['=', ' ', '>', '/']) do
        begin
          Key := Key + AText[I];
          Inc(I);
        end;
        SkipSpaces;
        Value := '';
        if (I <= N) and (AText[I] = '=') then
        begin
          Inc(I);
          SkipSpaces;
          if (I <= N) and CharInSet(AText[I], ['"', '''']) then
          begin
            Q := AText[I];
            Inc(I);
            while (I <= N) and (AText[I] <> Q) do
            begin
              Value := Value + AText[I];
              Inc(I);
            end;
            Inc(I);
          end;
        end;
        if Key <> '' then
          E.SetAttr(Key, Unescape(Value));
      end;
      if Stack.Count > 0 then
        Cur := Stack[Stack.Count - 1]
      else
        Cur := nil;
      if Cur <> nil then
        Cur.Children.Add(E)
      else if Result = nil then
        Result := E
      else
      begin
        E.Free;           // a second root element: not a layout file
        Continue;
      end;
      if not SelfClose then
        Stack.Add(E);
    end;
  finally
    Stack.Free;
  end;
end;

{ TLayout }

constructor TLayout.Create(AConfig: TConfig);
var
  Name: string;
begin
  inherited Create;
  FConfig := AConfig;
  Name := AConfig.GetString('LAYOUT_FILE');
  if (Name <> '') and TFile.Exists(Name) then
  begin
    FRoot := ParseLayoutText(TFile.ReadAllText(Name, TEncoding.UTF8));
    FLoadedFlag := (FRoot <> nil) and SameText(FRoot.Name, 'doxygenlayout');
    if not FLoadedFlag then
    begin
      FreeAndNil(FRoot);
      if AConfig.GetBool('WARN_LAYOUT_FILE') then
        Warn(Name, 1, 'the layout file is not a valid layout (the root element must be doxygenlayout): ignored');
    end;
  end
  else if (Name <> '') and AConfig.GetBool('WARN_LAYOUT_FILE') then
    Warn('', 0, Format('layout file ''%s'' not found: ignored', [Name]));
end;

destructor TLayout.Destroy;
begin
  FRoot.Free;
  inherited;
end;

function TLayout.NavIndex: TLayoutEntry;
begin
  if FRoot = nil then
    Result := nil
  else
    Result := FRoot.Child('navindex');
end;

function TLayout.Page(const AKind: string): TLayoutEntry;
begin
  if FRoot = nil then
    Result := nil
  else
    Result := FRoot.Child(AKind);
end;

function TLayout.Visible(AEntry: TLayoutEntry): Boolean;
var
  V: string;
begin
  V := Trim(AEntry.Attr('visible', 'yes'));
  if V.StartsWith('$') then
  begin
    try
      Result := FConfig.GetBool(Copy(V, 2, MaxInt));
    except
      Result := True;     // not an option of this configuration
    end;
  end
  else
    Result := not (SameText(V, 'no') or SameText(V, 'false') or (V = '0'));
end;

end.
