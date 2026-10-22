unit DoxyPas.Doc.Parser;

{ Documentation text -> AST (Doxygen's docparser + doctokenizer, merged into one character-level parser).
  Input is the text of a documentation block after the Markdown pass: Doxygen commands (\param, @return, \ref ...)
  plus HTML tags and entities. Unknown HTML-looking text such as "TList<T>" stays literal. }

interface

uses
  System.Classes,
  DoxyPas.Doc.Nodes;

/// <summary>Parses AText. The caller owns the returned root; diagnostics are added to AWarnings (may be nil).</summary>
function ParseDoc(const AText: string; AWarnings: TStrings = nil): TDocNode;

implementation

uses
  System.SysUtils,
  System.Character,
  System.RegularExpressions,
  System.Generics.Collections;

const
  // entity name, code point
  EntityNames: array[0..96] of string = ('amp', 'lt', 'gt', 'quot', 'apos', 'nbsp', 'copy', 'reg', 'trade', 'deg',
    'plusmn', 'times', 'divide', 'hellip', 'mdash', 'ndash', 'lsquo', 'rsquo', 'ldquo', 'rdquo', 'euro', 'pound',
    'yen', 'cent', 'sect', 'para', 'micro', 'middot', 'laquo', 'raquo', 'bull', 'larr', 'rarr', 'uarr', 'darr',
    'harr', 'lArr', 'rArr', 'hArr', 'infin', 'ne', 'le', 'ge', 'equiv', 'sum', 'prod', 'radic', 'asymp', 'ordf',
    'ordm', 'iexcl', 'iquest', 'szlig', 'agrave', 'aacute', 'acirc', 'atilde', 'auml', 'aring', 'aelig', 'ccedil',
    'egrave', 'eacute', 'ecirc', 'euml', 'igrave', 'iacute', 'icirc', 'iuml', 'ntilde', 'ograve', 'oacute', 'ocirc',
    'otilde', 'ouml', 'oslash', 'ugrave', 'uacute', 'ucirc', 'uuml', 'Auml', 'Ouml', 'Uuml', 'Eacute', 'Ccedil',
    'alpha', 'beta', 'gamma', 'delta', 'pi', 'lambda', 'mu', 'sigma', 'omega', 'Omega', 'Delta', 'Sigma');
  EntityCodes: array[0..96] of Integer = (38, 60, 62, 34, 39, 160, 169, 174, 8482, 176, 177, 215, 247, 8230, 8212,
    8211, 8216, 8217, 8220, 8221, 8364, 163, 165, 162, 167, 182, 181, 183, 171, 187, 8226, 8592, 8594, 8593, 8595,
    8596, 8656, 8658, 8660, 8734, 8800, 8804, 8805, 8801, 8721, 8719, 8730, 8776, 170, 186, 161, 191, 223, 224, 225,
    226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 241, 242, 243, 244, 245, 246, 248, 249,
    250, 251, 252, 196, 214, 220, 201, 199, 945, 946, 947, 948, 960, 955, 956, 963, 969, 937, 916, 931);

type
  TStopReason = (srEof, srBlank, srClose, srBreak);

  TDocParser = class
  strict private
    FText: string;
    FPos: Integer;
    FWarnings: TStrings;
    FOpenTags: TList<string>;
    FEndPara: Boolean;
    procedure PushTag(const ATag: string);
    procedure PopTag;
    procedure Warn(const AMsg: string);
    function AtEnd: Boolean; inline;
    function Cur: Char; inline;
    function At(AOffset: Integer): Char; inline;
    function StartsAt(const S: string): Boolean;
    procedure SkipSpaces;
    procedure SkipBlanks;
    function ReadWord: string;
    function ReadLine: string;
    function ReadQuoted: string;
    function ReadLinkWord: string;
    function ReadOptions(AOpen, AClose: Char): string;
    function ReadCommandName: string;
    function ReadUntilCommand(const AEnd1, AEnd2: string): string;
    function IsSectionStarter(const AName: string): Boolean;
    procedure ParseBlocks(AParent: TDocNode; const AStopTag: string);
    function ParseInline(AParent: TDocNode; const AStopTag, AEndCmd: string; AParaEnd, ASection: Boolean): TStopReason;
    function HandleCommand(AParent: TDocNode; const AName: string; AEndCmd: string; ASection: Boolean): Boolean;
    procedure HandleStyleCommand(AParent: TDocNode; const AStyle: string);
    procedure HandleVerbatim(AParent: TDocNode; const AName: string);
    procedure HandleSimpleSection(AParent: TDocNode; const AName: string);
    procedure HandleParam(AParent: TDocNode; const AName, ADir: string);
    function HandleEntity(AParent: TDocNode): Boolean;
    function HandleHtml(AParent: TDocNode; const AStopTag: string; out AReason: TStopReason): Boolean;
    procedure ParseStyleTag(AParent: TDocNode; const ATag, AStyle: string);
    procedure ParseList(AParent: TDocNode; const ATag: string);
    procedure ParseTable(AParent: TDocNode);
    procedure ParseSection(AParent: TDocNode; const AName: string; ALevel: Integer);
    function TryUrl(AParent: TDocNode): Boolean;
    function TryEmail(AParent: TDocNode): Boolean;
    function LineNumber: Integer;
  public
    constructor Create(const AText: string; AWarnings: TStrings);
    destructor Destroy; override;
    function Parse: TDocNode;
  end;

function IsSectionName(const S: string): Boolean;
begin
  Result := (S = 'section') or (S = 'subsection') or (S = 'subsubsection') or (S = 'paragraph') or
    (S = 'subparagraph') or (S = 'page') or (S = 'mainpage');
end;

function SectionLevel(const S: string): Integer;
begin
  if (S = 'page') or (S = 'mainpage') then Result := 0
  else if S = 'section' then Result := 1
  else if S = 'subsection' then Result := 2
  else if S = 'subsubsection' then Result := 3
  else if S = 'paragraph' then Result := 4
  else Result := 5;
end;

function SimpleSectionName(const S: string): string;
begin
  if (S = 'sa') or (S = 'see') then Result := 'see'
  else if (S = 'return') or (S = 'returns') or (S = 'result') then Result := 'return'
  else if (S = 'remark') or (S = 'remarks') then Result := 'remark'
  else if (S = 'author') or (S = 'authors') then Result := 'author'
  else if (S = 'version') or (S = 'since') or (S = 'date') or (S = 'note') or (S = 'warning') or (S = 'pre') or
    (S = 'post') or (S = 'copyright') or (S = 'invariant') or (S = 'attention') or (S = 'important') or
    (S = 'todo') or (S = 'test') or (S = 'bug') or (S = 'deprecated') or (S = 'par') then Result := S
  else Result := '';
end;

function ParamSectionName(const S: string): string;
begin
  if S = 'param' then Result := 'param'
  else if S = 'tparam' then Result := 'templateparam'
  else if S = 'retval' then Result := 'retval'
  else if (S = 'exception') or (S = 'throws') or (S = 'throw') then Result := 'exception'
  else Result := '';
end;

{ TDocParser }

constructor TDocParser.Create(const AText: string; AWarnings: TStrings);
begin
  inherited Create;
  FText := AText.Replace(#13#10, #10).Replace(#13, #10);
  FPos := 1;
  FWarnings := AWarnings;
  FOpenTags := TList<string>.Create;
end;

destructor TDocParser.Destroy;
begin
  FOpenTags.Free;
  inherited;
end;

procedure TDocParser.PushTag(const ATag: string);
begin
  FOpenTags.Add(ATag);
end;

procedure TDocParser.PopTag;
begin
  FOpenTags.Delete(FOpenTags.Count - 1);
end;

function TDocParser.LineNumber: Integer;
var
  I: Integer;
begin
  Result := 1;
  for I := 1 to FPos - 1 do
    if FText[I] = #10 then
      Inc(Result);
end;

procedure TDocParser.Warn(const AMsg: string);
begin
  if FWarnings <> nil then
    FWarnings.Add(Format('line %d: %s', [LineNumber, AMsg]));
end;

function TDocParser.AtEnd: Boolean;
begin
  Result := FPos > Length(FText);
end;

function TDocParser.Cur: Char;
begin
  if FPos <= Length(FText) then Result := FText[FPos] else Result := #0;
end;

function TDocParser.At(AOffset: Integer): Char;
begin
  if FPos + AOffset <= Length(FText) then Result := FText[FPos + AOffset] else Result := #0;
end;

function TDocParser.StartsAt(const S: string): Boolean;
begin
  Result := Copy(FText, FPos, Length(S)) = S;
end;

procedure TDocParser.SkipSpaces;
begin
  while (Cur = ' ') or (Cur = #9) do
    Inc(FPos);
end;

procedure TDocParser.SkipBlanks;
begin
  while (not AtEnd) and (Cur <= ' ') do
    Inc(FPos);
end;

function TDocParser.ReadWord: string;
var
  S: Integer;
begin
  SkipBlanks;
  S := FPos;
  while (not AtEnd) and (Cur > ' ') do
    Inc(FPos);
  Result := Copy(FText, S, FPos - S);
end;

function TDocParser.ReadLine: string;
var
  S: Integer;
begin
  SkipSpaces;
  S := FPos;
  while (not AtEnd) and (Cur <> #10) do
    Inc(FPos);
  Result := Trim(Copy(FText, S, FPos - S));
end;

function TDocParser.ReadQuoted: string;
var
  S: Integer;
begin
  Result := '';
  S := FPos;
  SkipSpaces;
  if Cur = '"' then
  begin
    Inc(FPos);
    S := FPos;
    while (not AtEnd) and (Cur <> '"') and (Cur <> #10) do
      Inc(FPos);
    Result := Copy(FText, S, FPos - S);
    if Cur = '"' then
      Inc(FPos);
  end
  else
    FPos := S; // no quoted text: keep the whitespace
end;

{ Target of \ref / \link / \copydoc: up to whitespace; trailing sentence punctuation is not part of it. }
function TDocParser.ReadLinkWord: string;
var
  S: Integer;
begin
  SkipBlanks;
  S := FPos;
  while (not AtEnd) and (Cur > ' ') and (Cur <> '"') do
    Inc(FPos);
  Result := Copy(FText, S, FPos - S);
  while (Result <> '') and CharInSet(Result[Length(Result)], ['.', ',', ';', ':', '!', '?']) do
  begin
    Delete(Result, Length(Result), 1);
    Dec(FPos);
  end;
end;

function TDocParser.ReadOptions(AOpen, AClose: Char): string;
var
  S: Integer;
begin
  Result := '';
  if Cur = AOpen then
  begin
    Inc(FPos);
    S := FPos;
    while (not AtEnd) and (Cur <> AClose) and (Cur <> #10) do
      Inc(FPos);
    Result := Copy(FText, S, FPos - S);
    if Cur = AClose then
      Inc(FPos);
  end;
end;

{ After the backslash/at sign: the command name (letters, digits, "_"), or a single non-letter character. }
function TDocParser.ReadCommandName: string;
var
  S: Integer;
begin
  S := FPos;
  if Cur.IsLetter then
  begin
    while Cur.IsLetterOrDigit or (Cur = '_') do
      Inc(FPos);
    Result := Copy(FText, S, FPos - S);
  end
  else if not AtEnd then
  begin
    Result := Cur;
    Inc(FPos);
    // "\::" and "\f$" style two-character commands
    if (Result = ':') and (Cur = ':') then
    begin
      Result := '::';
      Inc(FPos);
    end;
  end
  else
    Result := '';
end;

{ Raw text up to (and consuming) the end command AEnd1 or AEnd2 (with \ or @). }
function TDocParser.ReadUntilCommand(const AEnd1, AEnd2: string): string;
var
  S, E: Integer;
  Cand: string;
begin
  S := FPos;
  E := 0;
  Cand := '';
  while FPos <= Length(FText) do
  begin
    if (FText[FPos] = '\') or (FText[FPos] = '@') then
    begin
      if (Copy(FText, FPos + 1, Length(AEnd1)) = AEnd1) and
        ((AEnd1 = 'f$') or (AEnd1 = 'f]') or (AEnd1 = 'f}') or not At(1 + Length(AEnd1)).IsLetter) then
      begin
        E := FPos;
        Cand := AEnd1;
        Break;
      end;
      if (AEnd2 <> '') and (Copy(FText, FPos + 1, Length(AEnd2)) = AEnd2) then
      begin
        E := FPos;
        Cand := AEnd2;
        Break;
      end;
    end;
    Inc(FPos);
  end;
  if E = 0 then
  begin
    Warn('missing \' + AEnd1);
    Result := Copy(FText, S, MaxInt);
    FPos := Length(FText) + 1;
  end
  else
  begin
    Result := Copy(FText, S, E - S);
    FPos := E + 1 + Length(Cand);
  end;
end;

function TDocParser.IsSectionStarter(const AName: string): Boolean;
begin
  Result := (ParamSectionName(AName) <> '') or (SimpleSectionName(AName) <> '') or IsSectionName(AName) or
    (AName = 'brief') or (AName = 'short') or (AName = 'details') or (AName = 'xrefitem');
end;

{ ---------------------------------------------------------------- blocks }

procedure TDocParser.ParseBlocks(AParent: TDocNode; const AStopTag: string);
var
  P: TDocNode;
  R: TStopReason;
  Save: Integer;
  Name: string;
begin
  while not AtEnd do
  begin
    SkipBlanks;
    if AtEnd then
      Break;
    // sections are siblings of the paragraphs that follow them
    if ((Cur = '\') or (Cur = '@')) and Cur.IsPunctuation or ((Cur = '\') or (Cur = '@')) then
    begin
      Save := FPos;
      Inc(FPos);
      Name := ReadCommandName;
      if IsSectionName(Name) then
      begin
        ParseSection(AParent, Name, SectionLevel(Name));
        Continue;
      end;
      FPos := Save;
    end;
    P := TDocNode.Create(dnPara);
    R := ParseInline(P, AStopTag, '', True, False);
    if (P.Children.Count = 0) then
      P.Free
    else
    begin
      // drop trailing blanks
      if (P.Children.Last.Kind = dnText) then
        P.Children.Last.Text := P.Children.Last.Text.TrimRight;
      AParent.Add(P);
    end;
    if (R = srClose) or (R = srEof) then
      Break;
  end;
end;

procedure TDocParser.ParseSection(AParent: TDocNode; const AName: string; ALevel: Integer);
var
  S: TDocNode;
  Title, Id: string;
begin
  S := TDocNode.Create(dnSection);
  S.Name := AName;
  S.Level := ALevel;
  if AName = 'mainpage' then
  begin
    Id := 'mainpage';
    Title := ReadLine;
  end
  else
  begin
    Id := ReadWord;
    Title := ReadLine;
  end;
  S.Id := Id;
  S.Text := Title;
  AParent.Add(S);
  // content: everything up to the next section of the same or a higher level
  while not AtEnd do
  begin
    SkipBlanks;
    if AtEnd then
      Break;
    if ((Cur = '\') or (Cur = '@')) then
    begin
      var Save := FPos;
      Inc(FPos);
      var N := ReadCommandName;
      FPos := Save;
      if IsSectionName(N) and (SectionLevel(N) <= ALevel) then
        Break;
      if IsSectionName(N) then
      begin
        Inc(FPos);
        N := ReadCommandName;
        ParseSection(S, N, SectionLevel(N));
        Continue;
      end;
    end;
    var P := TDocNode.Create(dnPara);
    var R := ParseInline(P, '', '', True, False);
    if P.Children.Count = 0 then
      P.Free
    else
      S.Add(P);
    if R = srEof then
      Break;
  end;
end;

{ ---------------------------------------------------------------- inline }

function IsWordStart(const S: string; APos: Integer): Boolean;
begin
  Result := (APos <= 1) or not (S[APos - 1].IsLetterOrDigit or (S[APos - 1] = '_'));
end;

function TDocParser.TryEmail(AParent: TDocNode): Boolean;
var
  E: Integer;
  Tok: string;
  M: TMatch;
  N: TDocNode;
begin
  Result := False;
  if not IsWordStart(FText, FPos) then
    Exit;
  E := FPos;
  while (E <= Length(FText)) and (FText[E] > ' ') and not CharInSet(FText[E], ['<', '>', '"']) do
    Inc(E);
  Tok := Copy(FText, FPos, E - FPos);
  if Pos('@', Tok) < 2 then
    Exit;
  M := TRegEx.Match(Tok, '^[\w.+-]+@[\w-]+(\.[\w-]+)+');
  if not M.Success then
    Exit;
  N := AParent.Add(TDocNode.Create(dnUrl));
  N.Name := 'email';
  N.Text := M.Value;
  Inc(FPos, M.Length);
  Result := True;
end;

function TDocParser.TryUrl(AParent: TDocNode): Boolean;
var
  E: Integer;
  U: string;
  N: TDocNode;
begin
  Result := False;
  if not (StartsAt('http://') or StartsAt('https://') or StartsAt('ftp://') or StartsAt('file://') or
    StartsAt('mailto:')) then
    Exit;
  if not IsWordStart(FText, FPos) then
    Exit;
  E := FPos;
  while (E <= Length(FText)) and (FText[E] > ' ') and not CharInSet(FText[E], ['<', '>', '"']) do
    Inc(E);
  U := Copy(FText, FPos, E - FPos);
  while (U <> '') and CharInSet(U[Length(U)], ['.', ',', ';', ':', ')', '!', '?', '''']) do
  begin
    Delete(U, Length(U), 1);
    Dec(E);
  end;
  N := AParent.Add(TDocNode.Create(dnUrl));
  N.Text := U;
  FPos := E;
  Result := True;
end;

function TDocParser.HandleEntity(AParent: TDocNode): Boolean;
var
  E, I, Code: Integer;
  Name: string;
  N: TDocNode;
begin
  Result := False;
  E := Pos(';', FText, FPos);
  if (E = 0) or (E - FPos > 10) then
    Exit;
  Name := Copy(FText, FPos + 1, E - FPos - 1);
  Code := -1;
  if (Length(Name) > 1) and (Name[1] = '#') then
  begin
    if CharInSet(Name[2], ['x', 'X']) then
      Code := StrToIntDef('$' + Copy(Name, 3, MaxInt), -1)
    else
      Code := StrToIntDef(Copy(Name, 2, MaxInt), -1);
  end
  else
    for I := 0 to High(EntityNames) do
      if EntityNames[I] = Name then
      begin
        Code := EntityCodes[I];
        Break;
      end;
  if Code < 0 then
    Exit;
  N := AParent.Add(TDocNode.Create(dnSymbol));
  N.Name := Name;
  N.Text := Char(Code);
  FPos := E + 1;
  Result := True;
end;

procedure TDocParser.HandleStyleCommand(AParent: TDocNode; const AStyle: string);
var
  W: string;
  S: TDocNode;
begin
  SkipSpaces;
  W := ReadWord;
  // sentence punctuation after the word is not part of it ("\c Foo.Bar," -> Foo.Bar)
  while (W <> '') and (CharInSet(W[Length(W)], ['.', ',', ';', ':', '!', '?']) or
    ((W[Length(W)] = ')') and (Pos('(', W) = 0))) do
  begin
    Delete(W, Length(W), 1);
    Dec(FPos);
  end;
  if W = '' then
    Exit;
  S := AParent.Add(TDocNode.Create(dnStyle));
  S.Name := AStyle;
  S.AddText(W);
end;

procedure TDocParser.HandleVerbatim(AParent: TDocNode; const AName: string);
var
  N: TDocNode;
  Opt, Body, EndName: string;
begin
  Opt := ReadOptions('{', '}');
  EndName := 'end' + AName;
  if AName = 'startuml' then EndName := 'enduml'
  else if AName = 'f[' then EndName := 'f]'
  else if AName = 'f$' then EndName := 'f$';
  Body := ReadUntilCommand(EndName, '');
  if (AName = 'f$') or (AName = 'f[') then
  begin
    N := AParent.Add(TDocNode.Create(dnFormula));
    if AName = 'f$' then N.Name := 'inline' else N.Name := 'display';
    N.Text := Trim(Body);
    Exit;
  end;
  // the text after the command word on the same line is part of the body, a first empty line is not
  if Body.StartsWith(#10) then
    Body := Copy(Body, 2, MaxInt)
  else
    Body := Body.TrimLeft([' ', #9]);
  Body := Body.TrimRight([' ', #9, #10]);
  N := AParent.Add(TDocNode.Create(dnVerbatim));
  N.Name := AName;
  if AName = 'icode' then N.Name := 'code'
  else if AName = 'iverbatim' then N.Name := 'verbatim'
  else if AName = 'startuml' then N.Name := 'uml';
  N.Text := Body;
  N.Extra := Opt;
end;

procedure TDocParser.HandleSimpleSection(AParent: TDocNode; const AName: string);
var
  S, P: TDocNode;
  R: TStopReason;
  Title: string;
begin
  S := AParent.Add(TDocNode.Create(dnSimpleSect));
  S.Name := SimpleSectionName(AName);
  if AName = 'par' then
  begin
    Title := ReadLine;
    S.Text := Title;
  end;
  P := S.Add(TDocNode.Create(dnPara));
  R := ParseInline(P, '', '', True, True);
  if (P.Children.Count > 0) and (P.Children.Last.Kind = dnText) then
    P.Children.Last.Text := P.Children.Last.Text.TrimRight;
  if P.Children.Count = 0 then
    S.Children.Remove(P);
  // the blank line that ended the section also ends the enclosing paragraph
  if R = srBlank then
    FEndPara := True;
end;

procedure TDocParser.HandleParam(AParent: TDocNode; const AName, ADir: string);
var
  L, Item, P: TDocNode;
  Section: string;
begin
  Section := ParamSectionName(AName);
  L := nil;
  if (AParent.Children.Count > 0) and (AParent.Children.Last.Kind = dnParamList) and
    (AParent.Children.Last.Name = Section) then
    L := AParent.Children.Last;
  if L = nil then
  begin
    L := AParent.Add(TDocNode.Create(dnParamList));
    L.Name := Section;
  end;
  Item := L.Add(TDocNode.Create(dnParamItem));
  Item.Extra := ADir;
  Item.Text := ReadWord;
  P := Item.Add(TDocNode.Create(dnPara));
  if ParseInline(P, '', '', True, True) = srBlank then
    FEndPara := True;
  if (P.Children.Count > 0) and (P.Children.Last.Kind = dnText) then
    P.Children.Last.Text := P.Children.Last.Text.TrimRight;
end;

{ Returns True if the command was recognised (and consumed). }
function TDocParser.HandleCommand(AParent: TDocNode; const AName: string; AEndCmd: string; ASection: Boolean): Boolean;
var
  N: TDocNode;
  W, Dir: string;
begin
  Result := True;
  // style commands
  if AName = 'b' then HandleStyleCommand(AParent, 'b')
  else if (AName = 'c') or (AName = 'p') then HandleStyleCommand(AParent, 'code')
  else if (AName = 'a') or (AName = 'e') or (AName = 'em') then HandleStyleCommand(AParent, 'em')
  else if AName = 'n' then AParent.Add(TDocNode.Create(dnLineBreak))
  else if (AName = '\') or (AName = '@') or (AName = '&') or (AName = '$') or (AName = '#') or (AName = '<') or
    (AName = '>') or (AName = '%') or (AName = '"') or (AName = '.') or (AName = '::') or (AName = '|') then
    AParent.AddText(AName)
  else if (AName = '') or (not AName[1].IsLetter) then
    // "\*", "\_", "\ " ...: the character itself
    AParent.AddText(AName)
  else if (AName = 'code') or (AName = 'verbatim') or (AName = 'htmlonly') or (AName = 'latexonly') or
    (AName = 'xmlonly') or (AName = 'rtfonly') or (AName = 'manonly') or (AName = 'docbookonly') or
    (AName = 'dot') or (AName = 'msc') or (AName = 'startuml') or (AName = 'icode') or (AName = 'iverbatim') then
    HandleVerbatim(AParent, AName)
  else if AName = 'f' then
  begin
    if Cur = '$' then begin Inc(FPos); HandleVerbatim(AParent, 'f$'); end
    else if Cur = '[' then begin Inc(FPos); HandleVerbatim(AParent, 'f['); end
    else if Cur = '{' then
    begin
      W := ReadOptions('{', '}');
      N := AParent.Add(TDocNode.Create(dnFormula));
      N.Name := 'display';
      N.Text := '\begin{' + W + '}' + ReadUntilCommand('f}', '') + '\end{' + W + '}';
    end
    else
      AParent.AddText('\f');
  end
  else if AName = 'ref' then
  begin
    N := AParent.Add(TDocNode.Create(dnRef));
    N.Text := ReadLinkWord;
    W := ReadQuoted;
    if W <> '' then
      N.AddText(W);
  end
  else if AName = 'subpage' then
  begin
    N := AParent.Add(TDocNode.Create(dnRef));
    N.Name := 'subpage';
    N.Text := ReadLinkWord;
    W := ReadQuoted;
    if W <> '' then
      N.AddText(W);
  end
  else if AName = 'link' then
  begin
    N := AParent.Add(TDocNode.Create(dnLink));
    N.Text := ReadLinkWord;
    N.Name := 'link';
    ParseInline(N, '', 'endlink', False, False);
    if (N.Children.Count > 0) and (N.Children.First.Kind = dnText) then
      N.Children.First.Text := N.Children.First.Text.TrimLeft;
  end
  else if AName = 'endlink' then
    Warn('\endlink without \link')
  else if AName = 'anchor' then
  begin
    N := AParent.Add(TDocNode.Create(dnAnchor));
    N.Text := ReadWord;
  end
  else if AName = 'cite' then
  begin
    N := AParent.Add(TDocNode.Create(dnCite));
    N.Text := ReadWord;
  end
  else if AName = 'image' then
  begin
    N := AParent.Add(TDocNode.Create(dnImage));
    N.Name := ReadWord;
    N.Text := ReadWord;
    N.Extra := ReadQuoted;
    ReadLine; // size options are not interpreted
  end
  else if (AName = 'copydoc') or (AName = 'copybrief') or (AName = 'copydetails') then
  begin
    N := AParent.Add(TDocNode.Create(dnCopyDoc));
    N.Name := AName;
    N.Text := ReadLinkWord;
  end
  else if AName = 'inheritdoc' then
  begin
    N := AParent.Add(TDocNode.Create(dnCopyDoc));
    N.Name := 'inheritdoc';
  end
  else if (AName = 'include') or (AName = 'dontinclude') or (AName = 'snippet') or (AName = 'includelineno') or
    (AName = 'htmlinclude') or (AName = 'verbinclude') then
  begin
    N := AParent.Add(TDocNode.Create(dnInclude));
    N.Name := AName;
    N.Text := ReadWord;
    if AName = 'snippet' then
      N.Extra := ReadWord;          // the name of the block between the [name] markers
  end
  else if ParamSectionName(AName) <> '' then
  begin
    Dir := ReadOptions('[', ']');
    HandleParam(AParent, AName, Dir);
  end
  else if SimpleSectionName(AName) <> '' then
    HandleSimpleSection(AParent, AName)
  else if (AName = 'brief') or (AName = 'short') or (AName = 'details') or (AName = 'internal') or
    (AName = 'endinternal') or (AName = 'hideinitializer') or (AName = 'showinitializer') or (AName = 'static') then
    // consumed by the comment scanner normally; harmless here
  else if (AName = 'ingroup') or (AName = 'defgroup') or (AName = 'addtogroup') or (AName = 'weakgroup') or
    (AName = 'relates') or (AName = 'relatedalso') or (AName = 'memberof') or (AName = 'file') or
    (AName = 'class') or (AName = 'namespace') or (AName = 'fn') or (AName = 'var') or (AName = 'name') then
    ReadLine
  else
  begin
    Warn('unknown command \' + AName);
    AParent.AddText('\' + AName);
  end;
end;

procedure TDocParser.ParseStyleTag(AParent: TDocNode; const ATag, AStyle: string);
var
  N: TDocNode;
begin
  N := AParent.Add(TDocNode.Create(dnStyle));
  N.Name := AStyle;
  PushTag(ATag);
  try
    ParseInline(N, ATag, '', False, False);
  finally
    PopTag;
  end;
  // the closing tag is consumed by ParseInline's caller contract: it stops before it
  if StartsAt('</' + ATag) then
  begin
    var E := Pos('>', FText, FPos);
    if E > 0 then
      FPos := E + 1;
  end;
end;

procedure TDocParser.ParseList(AParent: TDocNode; const ATag: string);
var
  L, Item: TDocNode;
  E: Integer;
  Name: string;
begin
  L := AParent.Add(TDocNode.Create(dnList));
  L.Name := ATag;
  PushTag(ATag);
  try
    while not AtEnd do
    begin
      SkipBlanks;
      if StartsAt('</' + ATag) then
      begin
        E := Pos('>', FText, FPos);
        if E > 0 then FPos := E + 1;
        Exit;
      end;
      if StartsAt('<li') or StartsAt('<dt') or StartsAt('<dd') then
      begin
        Name := Copy(FText, FPos + 1, 2);
        E := Pos('>', FText, FPos);
        if E = 0 then Break;
        FPos := E + 1;
        Item := L.Add(TDocNode.Create(dnListItem));
        Item.Name := Name;
        PushTag(Name);
        try
          ParseBlocks(Item, Name);
        finally
          PopTag;
        end;
        if StartsAt('</' + Name) then
        begin
          E := Pos('>', FText, FPos);
          if E > 0 then FPos := E + 1;
        end;
      end
      else
      begin
        // text between items: ignore up to the next tag
        E := Pos('<', FText, FPos + 1);
        if E = 0 then Break;
        FPos := E;
      end;
    end;
  finally
    PopTag;
  end;
end;

procedure TDocParser.ParseTable(AParent: TDocNode);
var
  T, Row, Cell: TDocNode;
  E: Integer;
  Name: string;
begin
  T := AParent.Add(TDocNode.Create(dnTable));
  Row := nil;
  PushTag('table');
  try
    while not AtEnd do
    begin
      SkipBlanks;
      if StartsAt('</table') then
      begin
        E := Pos('>', FText, FPos);
        if E > 0 then FPos := E + 1;
        Exit;
      end;
      if StartsAt('<tr') then
      begin
        E := Pos('>', FText, FPos);
        if E = 0 then Break;
        FPos := E + 1;
        Row := T.Add(TDocNode.Create(dnTableRow));
      end
      else if StartsAt('</tr') then
      begin
        E := Pos('>', FText, FPos);
        if E > 0 then FPos := E + 1;
      end
      else if StartsAt('<td') or StartsAt('<th') then
      begin
        Name := Copy(FText, FPos + 1, 2);
        E := Pos('>', FText, FPos);
        if E = 0 then Break;
        if Row = nil then
          Row := T.Add(TDocNode.Create(dnTableRow));
        Cell := Row.Add(TDocNode.Create(dnTableCell));
        Cell.Name := Name;
        Cell.Extra := Copy(FText, FPos + 3, E - FPos - 3).Trim;
        FPos := E + 1;
        PushTag(Name);
        try
          ParseBlocks(Cell, Name);
        finally
          PopTag;
        end;
        if StartsAt('</' + Name) then
        begin
          E := Pos('>', FText, FPos);
          if E > 0 then FPos := E + 1;
        end;
      end
      else if StartsAt('<caption') then
      begin
        E := Pos('</caption>', FText, FPos);
        if E = 0 then Break;
        FPos := E + Length('</caption>');
      end
      else
      begin
        E := Pos('<', FText, FPos + 1);
        if E = 0 then Break;
        FPos := E;
      end;
    end;
  finally
    PopTag;
  end;
end;

{ Called with FPos on '<'. Returns True if the tag was handled; AReason tells ParseInline to stop (the closing tag
  of an enclosing element, or a paragraph break) - in that case closing tags are left for their owner. }
function TDocParser.HandleHtml(AParent: TDocNode; const AStopTag: string; out AReason: TStopReason): Boolean;
var
  E, S: Integer;
  Tag, Raw, Body: string;
  Closing: Boolean;
  N: TDocNode;

  function AttrValue(const AName: string): string;
  var
    P, Q: Integer;
  begin
    Result := '';
    P := Pos(AName + '=', LowerCase(Raw));
    if P = 0 then
      Exit;
    Inc(P, Length(AName) + 1);
    if (P <= Length(Raw)) and CharInSet(Raw[P], ['"', '''']) then
    begin
      Q := Pos(Raw[P], Raw, P + 1);
      if Q = 0 then
        Q := Length(Raw) + 1;
      Result := Copy(Raw, P + 1, Q - P - 1);
    end
    else
    begin
      Q := P;
      while (Q <= Length(Raw)) and (Raw[Q] > ' ') and (Raw[Q] <> '/') do
        Inc(Q);
      Result := Copy(Raw, P, Q - P);
    end;
  end;

  function InsideAny(const ATags: array of string): Boolean;
  var
    T: string;
    I: Integer;
  begin
    for I := 0 to High(ATags) do
    begin
      T := ATags[I];
      if FOpenTags.Contains(T) then
        Exit(True);
    end;
    Result := False;
  end;

begin
  Result := False;
  AReason := srEof;
  if Copy(FText, FPos, 4) = '<!--' then
  begin
    E := Pos('-->', FText, FPos);
    if E = 0 then
      E := Length(FText) - 2;
    FPos := E + 3;
    Exit(True);
  end;
  E := Pos('>', FText, FPos);
  if E = 0 then
    Exit;
  Raw := Copy(FText, FPos + 1, E - FPos - 1);
  Closing := Raw.StartsWith('/');
  if Closing then
    Raw := Copy(Raw, 2, MaxInt);
  S := 1;
  while (S <= Length(Raw)) and Raw[S].IsLetterOrDigit do
    Inc(S);
  Tag := LowerCase(Copy(Raw, 1, S - 1));
  if Tag = '' then
    Exit;

  if Closing then
  begin
    if (Tag = AStopTag) or FOpenTags.Contains(Tag) then
    begin
      AReason := srClose;
      Exit(True);
    end;
    if Tag = 'p' then
    begin
      FPos := E + 1;
      Exit(True);
    end;
    Exit(False); // stray closing tag: literal
  end;

  // an opening <li>/<td>... implicitly closes the previous one
  if ((Tag = 'li') or (Tag = 'dt') or (Tag = 'dd')) and InsideAny(['li', 'dt', 'dd']) then
  begin
    AReason := srClose;
    Exit(True);
  end;
  if ((Tag = 'td') or (Tag = 'th') or (Tag = 'tr')) and InsideAny(['td', 'th']) then
  begin
    AReason := srClose;
    Exit(True);
  end;

  if (Tag = 'b') or (Tag = 'strong') then begin FPos := E + 1; ParseStyleTag(AParent, Tag, 'b'); end
  else if Tag = 'i' then begin FPos := E + 1; ParseStyleTag(AParent, Tag, 'i'); end
  else if Tag = 'em' then begin FPos := E + 1; ParseStyleTag(AParent, Tag, 'em'); end
  else if (Tag = 'code') or (Tag = 'tt') then begin FPos := E + 1; ParseStyleTag(AParent, Tag, 'code'); end
  else if (Tag = 'u') or (Tag = 'ins') then begin FPos := E + 1; ParseStyleTag(AParent, Tag, 'u'); end
  else if (Tag = 's') or (Tag = 'strike') or (Tag = 'del') then begin FPos := E + 1; ParseStyleTag(AParent, Tag, 's'); end
  else if (Tag = 'sub') or (Tag = 'sup') or (Tag = 'small') or (Tag = 'center') or (Tag = 'kbd') or (Tag = 'var') or
    (Tag = 'samp') or (Tag = 'span') or (Tag = 'div') or (Tag = 'cite') or (Tag = 'summary') or (Tag = 'details') then
  begin
    FPos := E + 1;
    ParseStyleTag(AParent, Tag, Tag);
  end
  else if Tag = 'br' then
  begin
    FPos := E + 1;
    AParent.Add(TDocNode.Create(dnLineBreak));
  end
  else if Tag = 'hr' then
  begin
    FPos := E + 1;
    AParent.Add(TDocNode.Create(dnHRuler));
  end
  else if Tag = 'p' then
  begin
    FPos := E + 1;
    AReason := srBlank;
  end
  else if Tag = 'img' then
  begin
    FPos := E + 1;
    N := AParent.Add(TDocNode.Create(dnImage));
    N.Name := 'html';
    N.Text := AttrValue('src');
    N.Extra := AttrValue('alt');
  end
  else if Tag = 'a' then
  begin
    FPos := E + 1;
    if (AttrValue('name') <> '') or (AttrValue('id') <> '') then
    begin
      N := AParent.Add(TDocNode.Create(dnAnchor));
      N.Text := AttrValue('name') + AttrValue('id');
    end;
    if AttrValue('href') <> '' then
    begin
      N := AParent.Add(TDocNode.Create(dnLink));
      N.Name := 'href';
      N.Text := AttrValue('href');
    end
    else
      N := AParent; // <a name="x">text</a>: the anchor, then the text as it is
    PushTag('a');
    try
      ParseInline(N, 'a', '', False, False);
    finally
      PopTag;
    end;
    if StartsAt('</a') then
      FPos := Pos('>', FText, FPos) + 1;
  end
  else if (Tag = 'ul') or (Tag = 'ol') or (Tag = 'dl') then
  begin
    FPos := E + 1;
    ParseList(AParent, Tag);
  end
  else if Tag = 'table' then
  begin
    FPos := E + 1;
    ParseTable(AParent);
  end
  else if Tag = 'pre' then
  begin
    FPos := E + 1;
    S := Pos('</pre>', LowerCase(FText), FPos);
    if S = 0 then
      S := Length(FText) + 1;
    Body := Copy(FText, FPos, S - FPos);
    N := AParent.Add(TDocNode.Create(dnVerbatim));
    N.Name := 'pre';
    N.Text := Body.Replace('&lt;', '<').Replace('&gt;', '>').Replace('&amp;', '&').Trim([#10]);
    FPos := S + 6;
  end
  else if (Length(Tag) = 2) and (Tag[1] = 'h') and CharInSet(Tag[2], ['1'..'6']) then
  begin
    FPos := E + 1;
    N := AParent.Add(TDocNode.Create(dnHeading));
    N.Level := Ord(Tag[2]) - Ord('0');
    PushTag(Tag);
    try
      ParseInline(N, Tag, '', False, False);
    finally
      PopTag;
    end;
    if StartsAt('</' + Tag) then
      FPos := Pos('>', FText, FPos) + 1;
  end
  else if Tag = 'blockquote' then
  begin
    FPos := E + 1;
    N := AParent.Add(TDocNode.Create(dnBlockQuote));
    PushTag(Tag);
    try
      ParseBlocks(N, Tag);
    finally
      PopTag;
    end;
    if StartsAt('</' + Tag) then
      FPos := Pos('>', FText, FPos) + 1;
  end
  else
    Exit(False); // unknown tag: literal text (e.g. the generic "TList<T>")
  Result := True;
end;

function TDocParser.ParseInline(AParent: TDocNode; const AStopTag, AEndCmd: string; AParaEnd, ASection: Boolean): TStopReason;
var
  Buf: TStringBuilder;
  Save, Newlines: Integer;
  C: Char;
  Name: string;
  Reason: TStopReason;
  StartCount: Integer;

  procedure Flush;
  begin
    if Buf.Length > 0 then
    begin
      AParent.AddText(Buf.ToString);
      Buf.Clear;
    end;
  end;

begin
  Buf := TStringBuilder.Create;
  StartCount := AParent.Children.Count;
  try
    while not AtEnd do
    begin
      C := Cur;
      if (C = ' ') or (C = #9) or (C = #10) then
      begin
        Newlines := 0;
        while (Cur = ' ') or (Cur = #9) or (Cur = #10) do
        begin
          if Cur = #10 then
            Inc(Newlines);
          Inc(FPos);
        end;
        if (Newlines >= 2) and AParaEnd then
        begin
          Flush;
          Exit(srBlank);
        end;
        if (Buf.Length > 0) and (Buf[Buf.Length - 1] = ' ') then
          Continue;
        if (Buf.Length = 0) and ((AParent.Children.Count = 0) or
          ((AParent.Children.Last.Kind = dnText) and AParent.Children.Last.Text.EndsWith(' '))) then
          Continue;
        Buf.Append(' ');
      end
      else if (C = '\') or (C = '@') then
      begin
        // glued to a word or a path ("me@host", "C:\Tempile"): literal character, not a command
        if (FPos > 1) and At(1).IsLetter and
          ((FText[FPos - 1].IsLetterOrDigit or (FText[FPos - 1] = '_')) and not ((C = '\') and (Copy(FText, FPos + 1, 3) = 'end')) or
           CharInSet(FText[FPos - 1], [':', '\', '/'])) then
        begin
          Buf.Append(C);
          Inc(FPos);
          Continue;
        end;
        Save := FPos;
        Inc(FPos);
        // "\" or "@" followed by a space or digit is a literal character
        if (Cur <= ' ') and (Cur <> #0) or Cur.IsDigit or AtEnd then
        begin
          Buf.Append(C);
          Continue;
        end;
        Name := ReadCommandName;
        if (AEndCmd <> '') and (Name = AEndCmd) then
        begin
          Flush;
          Exit(srClose);
        end;
        if ASection and IsSectionStarter(Name) then
        begin
          Flush;
          FPos := Save;
          Exit(srBreak);
        end;
        if AParaEnd and IsSectionName(Name) then
        begin
          Flush;
          FPos := Save;
          Exit(srBreak);
        end;
        Flush;
        HandleCommand(AParent, Name, AEndCmd, ASection);
        if FEndPara then
        begin
          FEndPara := False;
          Exit(srBlank);
        end;
      end
      else if C = '<' then
      begin
        Flush;
        if HandleHtml(AParent, AStopTag, Reason) then
        begin
          if Reason in [srClose, srBlank] then
            Exit(Reason);
        end
        else
        begin
          Buf.Append(C);
          Inc(FPos);
        end;
      end
      else if C = '&' then
      begin
        Flush;
        if not HandleEntity(AParent) then
        begin
          Buf.Append(C);
          Inc(FPos);
        end;
      end
      else if C.IsLetterOrDigit and ((FPos = 1) or not (FText[FPos - 1].IsLetterOrDigit or (FText[FPos - 1] = '_'))) then
      begin
        Flush;
        if not (((C = 'h') or (C = 'f') or (C = 'm')) and TryUrl(AParent)) and not TryEmail(AParent) then
        begin
          Buf.Append(C);
          Inc(FPos);
        end;
      end
      else
      begin
        Buf.Append(C);
        Inc(FPos);
      end;
    end;
    Flush;
    Result := srEof;
  finally
    Buf.Free;
  end;
  if StartCount < 0 then
    Result := srEof;
end;

function TDocParser.Parse: TDocNode;
begin
  Result := TDocNode.Create(dnRoot);
  ParseBlocks(Result, '');
end;

function ParseDoc(const AText: string; AWarnings: TStrings): TDocNode;
var
  P: TDocParser;
begin
  P := TDocParser.Create(AText, AWarnings);
  try
    Result := P.Parse;
  finally
    P.Free;
  end;
end;

end.
