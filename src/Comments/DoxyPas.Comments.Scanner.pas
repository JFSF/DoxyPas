unit DoxyPas.Comments.Scanner;

{ Documentation block -> brief + detailed description plus the entry-level commands (Doxygen's commentscan).
  Pipeline: ALIASES -> XML documentation -> conditional sections (\cond, \if) -> Markdown -> brief/detail split ->
  entry commands (\ingroup, \internal, \public ...). The detailed text is parsed later by DoxyPas.Doc.Parser. }

interface

uses
  System.Classes,
  DoxyPas.Config;

type
  TDocOptions = record
    JavadocAutobrief: Boolean;
    QtAutobrief: Boolean;
    Markdown: Boolean;
    XmlDoc: Boolean;
    InternalDocs: Boolean;
    TabSize: Integer;
    DistributeGroupDoc: Boolean;
    Aliases: TArray<string>;
    EnabledSections: TArray<string>;
    class function Default: TDocOptions; static;
  end;

  TCommentInfo = record
    Brief: string;
    Detailed: string;
    Groups: TArray<string>;
    IsInternal: Boolean;
    HideInitializer: Boolean;
    ShowInitializer: Boolean;
    IsOverload: Boolean;
    IsStatic: Boolean;
    ProtectionOverride: string;  // '', public, protected or private
  end;

/// <summary>Reads JAVADOC_AUTOBRIEF, QT_AUTOBRIEF, MARKDOWN_SUPPORT, PASCAL_XMLDOC, INTERNAL_DOCS, TAB_SIZE,
/// ALIASES and ENABLED_SECTIONS.</summary>
function DocOptionsFromConfig(AConfig: TConfig): TDocOptions;

/// <summary>Processes one documentation block. AIsAfter: the comment follows its declaration (///&lt;).</summary>
function ScanComment(const AText: string; AIsAfter: Boolean; const AOptions: TDocOptions;
  AWarnings: TStrings = nil): TCommentInfo;

/// <summary>Replaces \alias and \alias{args} by their definitions (ALIASES).</summary>
function ExpandAliases(const AText: string; const AAliases: TArray<string>): string;

/// <summary>Removes the text of disabled \cond ... \endcond and \if ... \endif sections.</summary>
function ApplyConditionals(const AText: string; const AEnabled: TArray<string>; AWarnings: TStrings = nil): string;

implementation

uses
  System.SysUtils,
  System.Character,
  System.Generics.Collections,
  System.RegularExpressions,
  DoxyPas.Comments.XmlDoc,
  DoxyPas.Doc.Markdown;

class function TDocOptions.Default: TDocOptions;
begin
  Result.JavadocAutobrief := False;
  Result.QtAutobrief := False;
  Result.Markdown := True;
  Result.XmlDoc := True;
  Result.InternalDocs := False;
  Result.TabSize := 4;
  Result.DistributeGroupDoc := False;
  Result.Aliases := nil;
  Result.EnabledSections := nil;
end;

function DocOptionsFromConfig(AConfig: TConfig): TDocOptions;
begin
  Result.JavadocAutobrief := AConfig.GetBool('JAVADOC_AUTOBRIEF');
  Result.QtAutobrief := AConfig.GetBool('QT_AUTOBRIEF');
  Result.Markdown := AConfig.GetBool('MARKDOWN_SUPPORT');
  Result.XmlDoc := AConfig.GetBool('PASCAL_XMLDOC');
  Result.InternalDocs := AConfig.GetBool('INTERNAL_DOCS');
  Result.TabSize := AConfig.GetInt('TAB_SIZE');
  Result.DistributeGroupDoc := AConfig.GetBool('DISTRIBUTE_GROUP_DOC');
  Result.Aliases := AConfig.GetList('ALIASES');
  Result.EnabledSections := AConfig.GetList('ENABLED_SECTIONS');
end;

{ ---------------------------------------------------------------- aliases }

type
  TAlias = record
    Name: string;
    Args: Integer;   // number of arguments, 0 for "name=value"
    Value: string;
  end;

function ParseAliases(const AAliases: TArray<string>): TArray<TAlias>;
var
  L: TList<TAlias>;
  S: string;
  A: TAlias;
  P, B: Integer;
  Key: string;
begin
  L := TList<TAlias>.Create;
  try
    for S in AAliases do
    begin
      P := Pos('=', S);
      if P < 2 then
        Continue;
      Key := Trim(Copy(S, 1, P - 1));
      A.Value := Copy(S, P + 1, MaxInt).Replace('\n', #10);
      A.Args := 0;
      B := Pos('{', Key);
      if (B > 0) and Key.EndsWith('}') then
      begin
        A.Args := StrToIntDef(Copy(Key, B + 1, Length(Key) - B - 1), 0);
        Key := Copy(Key, 1, B - 1);
      end;
      A.Name := Key;
      L.Add(A);
    end;
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

{ Splits "a,b\,c" (the text between braces) at unescaped commas. }
function SplitArgs(const S: string): TArray<string>;
var
  L: TList<string>;
  I: Integer;
  Cur: string;
begin
  L := TList<string>.Create;
  try
    Cur := '';
    I := 1;
    while I <= Length(S) do
    begin
      if (S[I] = '\') and (I < Length(S)) and (S[I + 1] = ',') then
      begin
        Cur := Cur + ',';
        Inc(I, 2);
      end
      else if S[I] = ',' then
      begin
        L.Add(Cur);
        Cur := '';
        Inc(I);
      end
      else
      begin
        Cur := Cur + S[I];
        Inc(I);
      end;
    end;
    L.Add(Cur);
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

function ExpandAliases(const AText: string; const AAliases: TArray<string>): string;
var
  Defs: TArray<TAlias>;
  Pass, I, J, K, Depth: Integer;
  Changed: Boolean;
  Name, Value: string;
  SB: TStringBuilder;
  A: TAlias;
  Found: Boolean;
  Args: TArray<string>;
begin
  Result := AText;
  if Length(AAliases) = 0 then
    Exit;
  Defs := ParseAliases(AAliases);
  for Pass := 1 to 10 do
  begin
    Changed := False;
    SB := TStringBuilder.Create;
    try
      I := 1;
      while I <= Length(Result) do
      begin
        if ((Result[I] = '\') or (Result[I] = '@')) and (I < Length(Result)) and Result[I + 1].IsLetter then
        begin
          J := I + 1;
          while (J <= Length(Result)) and (Result[J].IsLetterOrDigit or (Result[J] = '_')) do
            Inc(J);
          Name := Copy(Result, I + 1, J - I - 1);
          Found := False;
          for A in Defs do
            if A.Name = Name then
            begin
              Args := nil;
              K := J;
              if A.Args > 0 then
              begin
                if (K <= Length(Result)) and (Result[K] = '{') then
                begin
                  Depth := 1;
                  Inc(K);
                  J := K;
                  while (K <= Length(Result)) and (Depth > 0) do
                  begin
                    if Result[K] = '{' then Inc(Depth)
                    else if Result[K] = '}' then Dec(Depth);
                    Inc(K);
                  end;
                  Args := SplitArgs(Copy(Result, J, K - J - 1));
                end
                else
                  Continue; // alias with arguments used without them
                if Length(Args) <> A.Args then
                  Continue;
              end;
              Value := A.Value;
              for Depth := High(Args) downto 0 do
                Value := Value.Replace('\' + IntToStr(Depth + 1), Args[Depth]);
              SB.Append(Value);
              I := K;
              Found := True;
              Changed := True;
              Break;
            end;
          if Found then
            Continue;
          SB.Append(Copy(Result, I, J - I));
          I := J;
        end
        else
        begin
          SB.Append(Result[I]);
          Inc(I);
        end;
      end;
      Result := SB.ToString;
    finally
      SB.Free;
    end;
    if not Changed then
      Break;
  end;
end;

{ ---------------------------------------------------------------- conditional sections }

type
  TCondParser = class
  strict private
    FText: string;
    FPos: Integer;
    FEnabled: TArray<string>;
    function Peek: Char;
    procedure SkipWs;
    function ParseOr: Boolean;
    function ParseAnd: Boolean;
    function ParseNot: Boolean;
    function ParseAtom: Boolean;
  public
    constructor Create(const AText: string; const AEnabled: TArray<string>);
    function Evaluate: Boolean;
  end;

constructor TCondParser.Create(const AText: string; const AEnabled: TArray<string>);
begin
  inherited Create;
  FText := AText;
  FPos := 1;
  FEnabled := AEnabled;
end;

function TCondParser.Peek: Char;
begin
  if FPos <= Length(FText) then Result := FText[FPos] else Result := #0;
end;

procedure TCondParser.SkipWs;
begin
  while Peek = ' ' do
    Inc(FPos);
end;

function TCondParser.Evaluate: Boolean;
begin
  Result := ParseOr;
end;

function TCondParser.ParseOr: Boolean;
begin
  Result := ParseAnd;
  SkipWs;
  while Copy(FText, FPos, 2) = '||' do
  begin
    Inc(FPos, 2);
    Result := ParseAnd or Result;
    SkipWs;
  end;
end;

function TCondParser.ParseAnd: Boolean;
begin
  Result := ParseNot;
  SkipWs;
  while Copy(FText, FPos, 2) = '&&' do
  begin
    Inc(FPos, 2);
    Result := ParseNot and Result;
    SkipWs;
  end;
end;

function TCondParser.ParseNot: Boolean;
begin
  SkipWs;
  if Peek = '!' then
  begin
    Inc(FPos);
    Result := not ParseNot;
  end
  else
    Result := ParseAtom;
end;

function TCondParser.ParseAtom: Boolean;
var
  S: Integer;
  Name, E: string;
begin
  SkipWs;
  if Peek = '(' then
  begin
    Inc(FPos);
    Result := ParseOr;
    SkipWs;
    if Peek = ')' then
      Inc(FPos);
    Exit;
  end;
  S := FPos;
  while (Peek <> #0) and (Peek > ' ') and not CharInSet(Peek, ['!', '&', '|', '(', ')']) do
    Inc(FPos);
  Name := Copy(FText, S, FPos - S);
  Result := False;
  for E in FEnabled do
    if SameText(E, Name) then
      Exit(True);
end;

function EvalCondition(const ALabel: string; const AEnabled: TArray<string>): Boolean;
var
  P: TCondParser;
begin
  P := TCondParser.Create(ALabel, AEnabled);
  try
    Result := P.Evaluate;
  finally
    P.Free;
  end;
end;

{ \cond [label] ... \endcond, \if label ... [\elseif label] [\else] ... \endif, \ifnot label. }
function ApplyConditionals(const AText: string; const AEnabled: TArray<string>; AWarnings: TStrings): string;
type
  TFrame = record
    Parent: Boolean;   // enclosing section is active
    Taken: Boolean;    // a branch of this \if was already active
    Active: Boolean;
    IsCond: Boolean;
  end;
var
  Lines: TArray<string>;
  Stack: TList<TFrame>;
  SB: TStringBuilder;
  Line, T, Cmd, Rest: string;
  F: TFrame;
  Active: Boolean;
  M: TMatch;
  I: Integer;

  function CurrentActive: Boolean;
  begin
    if Stack.Count = 0 then Result := True else Result := Stack.Last.Active;
  end;

  procedure Push(AActive, AIsCond: Boolean);
  begin
    F.Parent := CurrentActive;
    F.Taken := AActive;
    F.Active := F.Parent and AActive;
    F.IsCond := AIsCond;
    Stack.Add(F);
  end;

begin
  if not TRegEx.IsMatch(AText, '[\\@](cond|if|ifnot|endcond|endif)\b') then
    Exit(AText);
  Lines := AText.Replace(#13#10, #10).Split([#10]);
  Stack := TList<TFrame>.Create;
  SB := TStringBuilder.Create;
  try
    for I := 0 to High(Lines) do
    begin
      Line := Lines[I];
      T := TrimLeft(Line);
      M := TRegEx.Match(T, '^[\\@](cond|ifnot|if|elseif|else|endcond|endif)\b[ \t]*(.*)$');
      if M.Success then
      begin
        Cmd := M.Groups[1].Value;
        Rest := Trim(M.Groups[2].Value);
        if Cmd = 'cond' then
          Push((Rest <> '') and EvalCondition(Rest, AEnabled), True)
        else if Cmd = 'if' then
          Push(EvalCondition(Rest, AEnabled), False)
        else if Cmd = 'ifnot' then
          Push(not EvalCondition(Rest, AEnabled), False)
        else if (Cmd = 'elseif') and (Stack.Count > 0) then
        begin
          F := Stack.Last;
          Active := (not F.Taken) and EvalCondition(Rest, AEnabled);
          F.Taken := F.Taken or Active;
          F.Active := F.Parent and Active;
          Stack[Stack.Count - 1] := F;
        end
        else if (Cmd = 'else') and (Stack.Count > 0) then
        begin
          F := Stack.Last;
          F.Active := F.Parent and not F.Taken;
          F.Taken := True;
          Stack[Stack.Count - 1] := F;
        end
        else if (Cmd = 'endcond') or (Cmd = 'endif') then
        begin
          if Stack.Count > 0 then
            Stack.Delete(Stack.Count - 1)
          else if AWarnings <> nil then
            AWarnings.Add('\' + Cmd + ' without matching start');
        end
        else if AWarnings <> nil then
          AWarnings.Add('\' + Cmd + ' without matching start');
        Continue;
      end;
      if CurrentActive then
        SB.Append(Line).Append(#10);
    end;
    if (Stack.Count > 0) and (AWarnings <> nil) then
      AWarnings.Add('unterminated \cond/\if section');
    Result := SB.ToString.TrimRight([#10]);
  finally
    SB.Free;
    Stack.Free;
  end;
end;

{ ---------------------------------------------------------------- brief / detailed }

const
  // commands that end a brief description when they start a line
  BlockCommands: array[0..39] of string = ('details', 'param', 'tparam', 'retval', 'return', 'returns', 'result',
    'exception', 'throws', 'throw', 'see', 'sa', 'author', 'authors', 'version', 'since', 'date', 'note', 'warning',
    'pre', 'post', 'copyright', 'invariant', 'remark', 'remarks', 'attention', 'important', 'todo', 'test', 'bug',
    'deprecated', 'par', 'code', 'verbatim', 'section', 'subsection', 'page', 'ingroup', 'copydoc', 'xrefitem');

function IsBlockCommandAt(const AText: string; APos: Integer): Boolean;
var
  E: Integer;
  Name: string;
  I: Integer;
begin
  Result := False;
  if (APos > Length(AText)) or not CharInSet(AText[APos], ['\', '@']) then
    Exit;
  E := APos + 1;
  while (E <= Length(AText)) and AText[E].IsLetter do
    Inc(E);
  Name := Copy(AText, APos + 1, E - APos - 1);
  for I := 0 to High(BlockCommands) do
    if BlockCommands[I] = Name then
      Exit(True);
end;

{ End of the paragraph that starts at AFrom: a blank line, or a line that starts with a block command. }
function ParagraphEnd(const AText: string; AFrom: Integer): Integer;
var
  I: Integer;
  LineStart: Integer;
begin
  I := AFrom;
  while I <= Length(AText) do
  begin
    if AText[I] = #10 then
    begin
      LineStart := I + 1;
      // blank line?
      while (LineStart <= Length(AText)) and ((AText[LineStart] = ' ') or (AText[LineStart] = #9)) do
        Inc(LineStart);
      if (LineStart > Length(AText)) or (AText[LineStart] = #10) then
        Exit(I);
      if IsBlockCommandAt(AText, LineStart) then
        Exit(I);
    end;
    Inc(I);
  end;
  Result := Length(AText) + 1;
end;

{ End of the first sentence: ". " or ".\n" outside of tags and not after a single letter ("e.g. x"). }
function SentenceEnd(const AText: string): Integer;
var
  I: Integer;
begin
  for I := 1 to Length(AText) do
  begin
    if (AText[I] = '.') and ((I = Length(AText)) or (AText[I + 1] = ' ') or (AText[I + 1] = #10)) then
      Exit(I + 1);
    if (AText[I] = #10) and (I < Length(AText)) and (AText[I + 1] = #10) then
      Exit(I);
    if (AText[I] = '\') or (AText[I] = '@') then
      if IsBlockCommandAt(AText, I) and (I > 1) and (AText[I - 1] = #10) then
        Exit(I - 1);
  end;
  Result := Length(AText) + 1;
end;

procedure SplitBrief(const AText: string; AIsAfter: Boolean; const AOptions: TDocOptions; out ABrief,
  ADetailed: string);
var
  M: TMatch;
  Start, E, FirstLine: Integer;
  Before, After, T: string;
begin
  ABrief := '';
  ADetailed := '';
  T := AText;
  M := TRegEx.Match(T, '[\\@](brief|short)\b');
  if M.Success then
  begin
    Start := M.Index + M.Length;           // 1-based position after the command
    E := ParagraphEnd(T, Start);
    ABrief := Trim(Copy(T, Start, E - Start));
    Before := Copy(T, 1, M.Index - 1);
    After := Copy(T, E, MaxInt);
    ADetailed := Trim(Trim(Before) + #10#10 + Trim(After));
    Exit;
  end;
  if AOptions.JavadocAutobrief then
  begin
    E := SentenceEnd(T);
    ABrief := Trim(Copy(T, 1, E - 1));
    ADetailed := Trim(Copy(T, E, MaxInt));
    Exit;
  end;
  if AOptions.QtAutobrief then
  begin
    FirstLine := Pos(#10, T);
    if FirstLine = 0 then
      FirstLine := Length(T) + 1;
    E := SentenceEnd(Copy(T, 1, FirstLine - 1));
    ABrief := Trim(Copy(T, 1, E - 1));
    ADetailed := Trim(Copy(T, E, MaxInt));
    Exit;
  end;
  if AIsAfter then
  begin
    // a comment after a member is its brief description
    E := ParagraphEnd(T, 1);
    ABrief := Trim(Copy(T, 1, E - 1));
    ADetailed := Trim(Copy(T, E, MaxInt));
    Exit;
  end;
  ADetailed := Trim(T);
end;

{ ---------------------------------------------------------------- entry-level commands }

function ExtractEntryCommands(var AText: string; var AInfo: TCommentInfo; const AOptions: TDocOptions): Boolean;
var
  G: TList<string>;
  M: TMatch;
  Names: string;
  S: string;
  E: Integer;
begin
  Result := False;
  G := TList<string>.Create;
  try
    S := AText;
    // \ingroup name [name...]  (to end of line)
    M := TRegEx.Match(S, '[\\@]ingroup\b[ \t]*([^\n]*)');
    while M.Success do
    begin
      for Names in Trim(M.Groups[1].Value).Split([' '], TStringSplitOptions.ExcludeEmpty) do
        G.Add(Names);
      S := S.Remove(M.Index - 1, M.Length);
      M := TRegEx.Match(S, '[\\@]ingroup\b[ \t]*([^\n]*)');
    end;
    AInfo.Groups := G.ToArray;
    // single-word flags
    if TRegEx.IsMatch(S, '[\\@]hideinitializer\b') then
    begin
      AInfo.HideInitializer := True;
      S := TRegEx.Replace(S, '[\\@]hideinitializer\b', '');
    end;
    if TRegEx.IsMatch(S, '[\\@]showinitializer\b') then
    begin
      AInfo.ShowInitializer := True;
      S := TRegEx.Replace(S, '[\\@]showinitializer\b', '');
    end;
    if TRegEx.IsMatch(S, '[\\@]overload\b') then
    begin
      AInfo.IsOverload := True;
      S := TRegEx.Replace(S, '[\\@]overload\b[^\n]*', '');
    end;
    if TRegEx.IsMatch(S, '[\\@]static\b') then
    begin
      AInfo.IsStatic := True;
      S := TRegEx.Replace(S, '[\\@]static\b', '');
    end;
    for Names in ['public', 'protected', 'private'] do
      if TRegEx.IsMatch(S, '[\\@]' + Names + '\b') then
      begin
        AInfo.ProtectionOverride := Names;
        S := TRegEx.Replace(S, '[\\@]' + Names + '\b', '');
      end;
    // \internal [text] [\endinternal]
    M := TRegEx.Match(S, '[\\@]internal\b');
    if M.Success then
    begin
      AInfo.IsInternal := True;
      if not AOptions.InternalDocs then
      begin
        E := Pos('\endinternal', S, M.Index);
        if E = 0 then
          E := Pos('@endinternal', S, M.Index);
        if E = 0 then
          S := Copy(S, 1, M.Index - 1)
        else
          S := Copy(S, 1, M.Index - 1) + Copy(S, E + Length('\endinternal'), MaxInt);
      end
      else
        S := TRegEx.Replace(S, '[\\@](end)?internal\b', '');
    end;
    // \details only separates the brief from the details
    S := TRegEx.Replace(S, '[\\@]details\b', '');
    AText := S;
    Result := True;
  finally
    G.Free;
  end;
end;

function ScanComment(const AText: string; AIsAfter: Boolean; const AOptions: TDocOptions;
  AWarnings: TStrings): TCommentInfo;
var
  T, Brief, Detailed: string;
begin
  Result := Default(TCommentInfo);
  T := AText.Replace(#13#10, #10).Replace(#13, #10);
  T := ExpandAliases(T, AOptions.Aliases);
  if AOptions.XmlDoc then
    T := ConvertXmlDoc(T);
  T := ApplyConditionals(T, AOptions.EnabledSections, AWarnings);
  if AOptions.Markdown then
    T := MarkdownToDoxygen(T, AOptions.TabSize);
  ExtractEntryCommands(T, Result, AOptions);
  SplitBrief(T, AIsAfter, AOptions, Brief, Detailed);
  Result.Brief := Brief;
  Result.Detailed := TRegEx.Replace(Detailed, '\n{3,}', #10#10);
end;

end.
