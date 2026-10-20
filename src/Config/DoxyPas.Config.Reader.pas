unit DoxyPas.Config.Reader;

interface

uses
  DoxyPas.Config;

/// <summary>Reads a Doxyfile (with @INCLUDE support) into AConfig. Values stay as read: call
/// AConfig.PostProcess afterwards unless the file is only going to be rewritten (update mode).</summary>
procedure ReadDoxyfile(AConfig: TConfig; const AFileName: string);

/// <summary>Same as ReadDoxyfile, for text already in memory; AName is used in diagnostics.</summary>
procedure ReadDoxyfileText(AConfig: TConfig; const AText, AName: string);

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.RegularExpressions,
  System.StrUtils,
  DoxyPas.Config.Options,
  DoxyPas.Core.Log;

const
  MaxIncludeDepth = 10;

type
  TDoxyfileReader = class
  strict private
    FConfig: TConfig;
    FIncludePath: TList<string>;
    FFile: string;
    FLine: Integer;
    function StripComment(const AText: string): string;
    function ProcessString(const AName, AText: string): string;
    procedure ProcessList(const AName, AText: string; AItems: TList<string>);
    procedure Statement(const AName: string; AAppend: Boolean; const AValue: string);
    procedure ReadInclude(const AValue: string; ADepth: Integer);
    function FindFile(const AName: string): string;
    procedure WarnHere(const AText: string);
  public
    constructor Create(AConfig: TConfig);
    destructor Destroy; override;
    procedure ParseText(const AText, AFileName: string; ADepth: Integer);
    procedure ParseFile(const AFileName: string; ADepth: Integer);
  end;

function DecodeDoxyfile(const ABytes: TBytes): string;
var
  Enc: TEncoding;
  Probe: string;
  M: TMatch;
  Offset: Integer;
begin
  Enc := TEncoding.UTF8;
  // shortcut: Doxygen switches encoding at the DOXYFILE_ENCODING tag; we decode the whole file with it
  Probe := TEncoding.ANSI.GetString(ABytes);
  M := TRegEx.Match(Probe, '(?m)^[ \t]*DOXYFILE_ENCODING[ \t]*=[ \t]*"?([^\s"#]+)');
  if M.Success and not SameText(M.Groups[1].Value, 'UTF-8') then
    try
      Enc := TEncoding.GetEncoding(M.Groups[1].Value);
    except
      Warn('', 0, Format('unsupported DOXYFILE_ENCODING ''%s'', using UTF-8', [M.Groups[1].Value]));
    end;
  Offset := TEncoding.GetBufferEncoding(ABytes, Enc);
  Result := Enc.GetString(ABytes, Offset, Length(ABytes) - Offset);
end;

{ TDoxyfileReader }

constructor TDoxyfileReader.Create(AConfig: TConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FIncludePath := TList<string>.Create;
end;

destructor TDoxyfileReader.Destroy;
begin
  FIncludePath.Free;
  inherited;
end;

procedure TDoxyfileReader.WarnHere(const AText: string);
begin
  Warn('', 0, AText);
end;

function TDoxyfileReader.StripComment(const AText: string): string;
var
  I, L: Integer;
  InQuote: Boolean;
  C: Char;
begin
  InQuote := False;
  L := Length(AText);
  I := 1;
  while I <= L do
  begin
    C := AText[I];
    if C = '\' then
      Inc(I) // skip over the escaped character
    else if C = '"' then
      InQuote := not InQuote
    else if (not InQuote) and (C = '#') then
    begin
      if (I < L) and (AText[I + 1] = '#') then // "##" -> user comment
        FConfig.AppendUserComment(Copy(AText, I, MaxInt) + #10);
      Exit(Trim(Copy(AText, 1, I - 1)));
    end;
    Inc(I);
  end;
  Result := AText;
end;

function TDoxyfileReader.ProcessString(const AName, AText: string): string;
var
  S: string;
  I, L: Integer;
  Warned: Boolean;
  C: Char;
begin
  S := StripComment(Trim(AText));
  L := Length(S);
  // remove surrounding quotes if present (and not escaped)
  if (L >= 2) and (S[1] = '"') and (S[L] = '"') and
    ((S[L - 1] <> '\') or ((L >= 3) and (S[L - 1] = '\') and (S[L - 2] = '\'))) then
  begin
    S := Copy(S, 2, L - 2);
    L := Length(S);
  end;
  Result := '';
  Warned := False;
  I := 1;
  while I <= L do
  begin
    C := S[I];
    if C = '\' then
    begin
      if (I < L) and (S[I + 1] = '"') then // unescape the quote character
        Result := Result + '"'
      else // keep other escaped characters in escaped form
      begin
        Result := Result + C;
        if I < L then
          Result := Result + S[I + 1];
      end;
      Inc(I);
    end
    else if C = '"' then
    begin
      if not Warned then
        WarnHere(Format('Invalid value for ''%s'' tag at line %d, file %s: Value ''%s'' is not properly quoted',
          [AName, FLine, FFile, Trim(AText)]));
      Warned := True;
    end
    else
      Result := Result + C;
    Inc(I);
  end;
end;

procedure TDoxyfileReader.ProcessList(const AName, AText: string; AItems: TList<string>);
var
  S, Elem: string;
  I, L: Integer;
  C: Char;
  WasQuote, NeedsSeparator, InsideQuote, Warned, AllowComma: Boolean;

  procedure AddElem;
  begin
    if Elem <> '' then
    begin
      if WasQuote then
        Elem := '"' + Elem + '"';
      WasQuote := False;
      AItems.Add(Elem);
      Elem := '';
    end;
  end;

begin
  AllowComma := AName <> 'PREDEFINED';
  S := StripComment(Trim(AText));
  L := Length(S);
  Elem := '';
  WasQuote := False;
  NeedsSeparator := False;
  InsideQuote := False;
  Warned := False;
  I := 1;
  while I <= L do
  begin
    C := S[I];
    if (not NeedsSeparator) and (C = '\') then // escaped character
    begin
      if (I < L) and (S[I + 1] = '"') then
        Elem := Elem + '"'
      else if InsideQuote and (I < L - 1) and (S[I + 1] = '\') and (S[I + 2] = '"') then
        Elem := Elem + '\' // escaped "\" at the end of a quoted section
      else
      begin
        Elem := Elem + C;
        if I < L then
          Elem := Elem + S[I + 1];
      end;
      Inc(I);
    end
    else if (not NeedsSeparator) and (C = '"') then
    begin
      if not InsideQuote then
      begin
        InsideQuote := True;
        WasQuote := True;
      end
      else // this quote ends an element
      begin
        InsideQuote := False;
        NeedsSeparator := True;
      end;
    end
    else if (not InsideQuote) and (((C = ',') and AllowComma) or (C <= ' ')) then // separator
    begin
      NeedsSeparator := False;
      AddElem;
    end
    else if NeedsSeparator then
    begin
      if not Warned then
      begin
        WarnHere(Format('Invalid value for ''%s'' tag at line %d, file %s: Values in list ''%s'' are not properly ' +
          'space %sseparated', [AName, FLine, FFile, Trim(AText), IfThen(AllowComma, 'or comma ', '')]));
        Warned := True;
      end;
      NeedsSeparator := False;
      Dec(I); // try the character again as part of a new element
      AddElem;
    end
    else
      Elem := Elem + C;
    Inc(I);
  end;
  AddElem;
  if InsideQuote then
    WarnHere(Format('Invalid value for ''%s'' tag at line %d, file %s: Values in list ''%s'' are not properly quoted',
      [AName, FLine, FFile, Trim(AText)]));
end;

procedure TDoxyfileReader.Statement(const AName: string; AAppend: Boolean; const AValue: string);
var
  Opt: TConfigOption;
  Tmp: TList<string>;
begin
  Opt := FConfig.Find(AName);
  if Opt = nil then
  begin
    WarnHere(Format('ignoring unsupported tag ''%s'' at line %d, file %s', [AName, FLine, FFile]));
    Exit;
  end;
  Opt.UserComment := FConfig.TakeUserComment;
  case Opt.Info.Kind of
    okList:
      begin
        if not AAppend then
          Opt.List.Clear;
        ProcessList(AName, AValue, Opt.List);
      end;
    okString, okEnum:
      if AAppend then
        WarnHere(Format('operator += not supported for ''%s''. Ignoring line at line %d, file %s',
          [AName, FLine, FFile]))
      else
        Opt.Str := ProcessString(AName, AValue);
    okInt, okBool:
      if AAppend then
        WarnHere(Format('operator += not supported for ''%s''. Ignoring line at line %d, file %s',
          [AName, FLine, FFile]))
      else
        Opt.Raw := ProcessString(AName, AValue);
    okObsolete:
      begin
        WarnHere(Format('Tag ''%s'' at line %d of file ''%s'' has become obsolete. To avoid this warning ' +
          'please remove this line from your configuration file or upgrade it using "doxypas -u"',
          [AName, FLine, FFile]));
        Opt.Present := True;
        if Opt.Info.OrgKind = okList then
        begin
          Tmp := TList<string>.Create;
          try
            ProcessList(AName, AValue, Tmp);
          finally
            Tmp.Free;
          end;
        end;
      end;
  end;
end;

function TDoxyfileReader.FindFile(const AName: string): string;
var
  P: string;
begin
  for P in FIncludePath do
  begin
    Result := TPath.Combine(P, AName);
    if TFile.Exists(Result) then
      Exit;
  end;
  Result := AName;
  if not TFile.Exists(Result) then
    Result := '';
end;

procedure TDoxyfileReader.ReadInclude(const AValue: string; ADepth: Integer);
var
  Inc_, Path: string;
  OldFile: string;
  OldLine: Integer;
begin
  if ADepth >= MaxIncludeDepth then
    raise EConfigError.CreateFmt('maximum include depth (%d) reached, %s is not included. Aborting...',
      [MaxIncludeDepth, AValue]);
  Inc_ := Trim(SubstEnvVars(AValue));
  if (Length(Inc_) >= 2) and (Inc_[1] = '"') and (Inc_[Length(Inc_)] = '"') then
    Inc_ := Copy(Inc_, 2, Length(Inc_) - 2);
  Path := FindFile(Inc_);
  if Path = '' then
    raise EConfigError.CreateFmt('@INCLUDE = %s: not found!', [Inc_]);
  OldFile := FFile;
  OldLine := FLine;
  ParseFile(Path, ADepth + 1);
  FFile := OldFile;
  FLine := OldLine;
end;

procedure TDoxyfileReader.ParseFile(const AFileName: string; ADepth: Integer);
begin
  ParseText(DecodeDoxyfile(TFile.ReadAllBytes(AFileName)), AFileName, ADepth);
end;

procedure TDoxyfileReader.ParseText(const AText, AFileName: string; ADepth: Integer);
var
  Lines: TArray<string>;
  I: Integer;
  Cur, T, Tok: string;
  M: TMatch;
begin
  FFile := AFileName;
  Lines := AText.Replace(#13, '').Split([#10]);
  I := 0;
  while I < Length(Lines) do
  begin
    FLine := I + 1;
    Cur := Lines[I];
    Inc(I);
    T := TrimLeft(Cur);
    if T = '' then
      Continue;
    if T.StartsWith('##') then
    begin
      FConfig.AppendUserComment(T + #10);
      Continue;
    end;
    if T[1] = '#' then
      Continue;
    // a backslash as last non-blank character continues the statement on the next line
    while (I < Length(Lines)) and TRegEx.IsMatch(Cur, '\\[ \t]*$') do
    begin
      Cur := TRegEx.Replace(Cur, '\\[ \t]*$', ' ') + Lines[I];
      Inc(I);
    end;
    Cur := TRegEx.Replace(Cur, '\\[ \t]*$', ' ');
    T := TrimLeft(Cur);

    M := TRegEx.Match(T, '^@INCLUDE_PATH[ \t]*=(.*)$');
    if M.Success then
    begin
      FIncludePath.Clear;
      ProcessList('@INCLUDE_PATH', M.Groups[1].Value, FIncludePath);
      Continue;
    end;
    M := TRegEx.Match(T, '^@INCLUDE[ \t]*=(.*)$');
    if M.Success then
    begin
      Tok := Trim(M.Groups[1].Value);
      ReadInclude(Tok, ADepth);
      FFile := AFileName;
      FLine := I;
      Continue;
    end;
    M := TRegEx.Match(T, '^([A-Za-z_][A-Za-z_0-9]*)[ \t]*(\+?=)(.*)$');
    if M.Success then
      Statement(M.Groups[1].Value, M.Groups[2].Value = '+=', M.Groups[3].Value)
    else
      WarnHere(Format('ignoring unknown tag ''%s'' at line %d, file %s',
        [T.Split([' ', #9])[0], FLine, FFile]));
  end;
end;

procedure ReadDoxyfile(AConfig: TConfig; const AFileName: string);
var
  R: TDoxyfileReader;
begin
  if not TFile.Exists(AFileName) then
    raise EConfigError.CreateFmt('Configuration file ''%s'' not found', [AFileName]);
  R := TDoxyfileReader.Create(AConfig);
  try
    R.ParseFile(AFileName, 0);
  finally
    R.Free;
  end;
end;

procedure ReadDoxyfileText(AConfig: TConfig; const AText, AName: string);
var
  R: TDoxyfileReader;
begin
  R := TDoxyfileReader.Create(AConfig);
  try
    R.ParseText(AText, AName, 0);
  finally
    R.Free;
  end;
end;

end.
