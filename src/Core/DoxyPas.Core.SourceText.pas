unit DoxyPas.Core.SourceText;

{ The text of the source files and the encoding they are in (INPUT_ENCODING and INPUT_FILE_ENCODING). A byte order mark
  always wins. Without one the encoding is the one of the first pattern of INPUT_FILE_ENCODING that matches the file, else
  INPUT_ENCODING. UTF-8 (the default) is read leniently: a file that is not valid UTF-8 is read in the ANSI code page, which
  is what the Delphi sources written before Unicode have. Any other encoding is used as it is. }

interface

uses
  System.SysUtils;

/// <summary>Sets the encodings. APatterns are the items of INPUT_FILE_ENCODING: "pattern=encoding". Call it before the files
/// are read (by one thread); an encoding that is not known is a warning and UTF-8 is used.</summary>
procedure SetInputEncoding(const ADefault: string; const APatterns: TArray<string>);

/// <summary>The text of the bytes of the file AFileName.</summary>
function DecodeSourceBytes(const ABytes: TBytes; const AFileName: string): string;

/// <summary>The text of a source file.</summary>
function ReadSourceFile(const AFileName: string): string;

/// <summary>Sets INPUT_FILTER (AFilter) and FILTER_PATTERNS (APatterns: "pattern=filter"). Call it before the files are read.</summary>
procedure SetInputFilter(const AFilter: string; const APatterns: TArray<string>);

/// <summary>The text of an input file after the filter that applies to it (the command is run with the name of the file and
/// its output is the text); the file as it is when there is no filter or the filter fails (a warning).</summary>
function ReadInputFile(const AFileName: string): string;

/// <summary>FILTER_SOURCE_FILES and FILTER_SOURCE_PATTERNS ("pattern=filter"): whether the source pages (ReadBrowseFile) use the filters.</summary>
procedure SetSourceFilter(AEnabled: Boolean; const APatterns: TArray<string>);

/// <summary>FILE_VERSION_FILTER: the command that prints the version of a file (run with the name of the file); the version is
/// $version in WARN_FORMAT. An empty command: no version.</summary>
procedure SetFileVersionFilter(const ACommand: string);

/// <summary>The text of a file for the source pages: filtered only with FILTER_SOURCE_FILES (the patterns of FILTER_SOURCE_PATTERNS
/// first), else the file as it is.</summary>
function ReadBrowseFile(const AFileName: string): string;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
{$IFDEF POSIX}
  Posix.Stdlib,
{$ENDIF}
  System.IOUtils,
  System.Masks,
  System.Generics.Collections,
  DoxyPas.Core.Log;

type
  TPatternEncoding = record
    Pattern: string;
    Encoding: TEncoding;       // nil: UTF-8 (lenient)
  end;

var
  DefaultEncoding: TEncoding;  // nil: UTF-8 (lenient)
  Patterns: TArray<TPatternEncoding>;
  Owned: TArray<TEncoding>;    // the encodings that were made here (to free)

// The encoding with this name; nil for UTF-8 (also when the name is not known, with a warning).
function FindEncoding(const AName: string): TEncoding;
var
  Name: string;
begin
  Result := nil;
  Name := Trim(AName);
  if (Name = '') or SameText(Name, 'UTF-8') or SameText(Name, 'UTF8') then
    Exit;
  if SameText(Name, 'UTF-16') or SameText(Name, 'UTF-16LE') then
    Exit(TEncoding.Unicode);
  if SameText(Name, 'UTF-16BE') then
    Exit(TEncoding.BigEndianUnicode);
  if SameText(Name, 'ANSI') or SameText(Name, 'SYSTEM') then
    Exit(TEncoding.ANSI);
  try
    Result := TEncoding.GetEncoding(Name);
    SetLength(Owned, Length(Owned) + 1);
    Owned[High(Owned)] := Result;
  except
    on Exception do
    begin
      Warn('', 0, Format('unsupported INPUT_ENCODING ''%s'', using UTF-8', [Name]));
      Result := nil;
    end;
  end;
end;

procedure FreeOwned;
var
  E: TEncoding;
begin
  for E in Owned do
    E.Free;
  Owned := nil;
end;

procedure SetInputEncoding(const ADefault: string; const APatterns: TArray<string>);
var
  Item: string;
  P: Integer;
  PE: TPatternEncoding;
begin
  FreeOwned;
  Patterns := nil;
  DefaultEncoding := FindEncoding(ADefault);
  for Item in APatterns do
  begin
    P := Item.LastIndexOf('=');
    if P <= 0 then
      Continue;
    PE.Pattern := Trim(Item.Substring(0, P)).Replace('\', '/');
    PE.Encoding := FindEncoding(Item.Substring(P + 1));
    Patterns := Patterns + [PE];
  end;
end;

function DecodeSourceBytes(const ABytes: TBytes; const AFileName: string): string;
var
  Enc, Chosen: TEncoding;
  Offset: Integer;
  PE: TPatternEncoding;
  Full, Name: string;
begin
  Enc := nil;
  Offset := TEncoding.GetBufferEncoding(ABytes, Enc, nil);
  if Enc <> nil then                       // a byte order mark
    Exit(Enc.GetString(ABytes, Offset, Length(ABytes) - Offset));
  Chosen := DefaultEncoding;
  if Length(Patterns) > 0 then
  begin
    Full := AFileName.Replace('\', '/');
    Name := ExtractFileName(AFileName);
    for PE in Patterns do
      if MatchesMask(Name, PE.Pattern) or MatchesMask(Full, PE.Pattern) then
      begin
        Chosen := PE.Encoding;
        Break;
      end;
  end;
  if Chosen <> nil then
    Exit(Chosen.GetString(ABytes));
  // UTF-8 if it decodes without replacement characters, else the ANSI code page
  try
    Result := TEncoding.UTF8.GetString(ABytes);
    if Result.IndexOf(#$FFFD) < 0 then
      Exit;
  except
    on EEncodingError do;
  end;
  Result := TEncoding.ANSI.GetString(ABytes);
end;

function ReadSourceFile(const AFileName: string): string;
begin
  Result := DecodeSourceBytes(TFile.ReadAllBytes(AFileName), AFileName);
end;

type
  TPatternFilter = record
    Pattern, Command: string;
  end;

var
  InputFilter: string;
  FilterPatterns: TArray<TPatternFilter>;
  SourceFilterOn: Boolean;
  SourcePatterns: TArray<TPatternFilter>;

function ParsePatterns(const APatterns: TArray<string>): TArray<TPatternFilter>;
var
  S: string;
  P: Integer;
begin
  Result := nil;
  for S in APatterns do
  begin
    P := S.IndexOf('=');
    if P <= 0 then
      Continue;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)].Pattern := Trim(S.Substring(0, P));
    Result[High(Result)].Command := Trim(S.Substring(P + 1));
  end;
end;

procedure SetInputFilter(const AFilter: string; const APatterns: TArray<string>);
begin
  InputFilter := Trim(AFilter);
  FilterPatterns := ParsePatterns(APatterns);
end;

procedure SetSourceFilter(AEnabled: Boolean; const APatterns: TArray<string>);
begin
  SourceFilterOn := AEnabled;
  SourcePatterns := ParsePatterns(APatterns);
end;

// The command of the first pattern that matches this file, else ADefault.
function FilterFor(const AFileName: string; const APatterns: TArray<TPatternFilter>; const ADefault: string): string;
var
  F: TPatternFilter;
  N: string;
begin
  N := ExtractFileName(AFileName);
  for F in APatterns do
    if MatchesMask(N, F.Pattern) or MatchesMask(AFileName, F.Pattern) then
      Exit(F.Command);
  Result := ADefault;
end;

// Runs the command through the shell with its output in AOutFile; True when it ended with exit code 0.
function RunFilter(const ACommand, AOutFile: string): Boolean;
{$IFDEF MSWINDOWS}
var
  SI: TStartupInfo;
  PI: TProcessInformation;
  Cmd: string;
  Code: Cardinal;
begin
  Result := False;
  ZeroMemory(@SI, SizeOf(SI));
  SI.cb := SizeOf(SI);
  Cmd := 'cmd.exe /s /c "' + ACommand + ' > "' + AOutFile + '""';
  if CreateProcess(nil, PChar(Cmd), nil, nil, False, CREATE_NO_WINDOW, nil, nil, SI, PI) then
  begin
    WaitForSingleObject(PI.hProcess, 600000);
    GetExitCodeProcess(PI.hProcess, Code);
    Result := Code = 0;
    CloseHandle(PI.hProcess);
    CloseHandle(PI.hThread);
  end;
end;
{$ELSE}
var
  M: TMarshaller;
begin
  Result := _system(M.AsAnsi(ACommand + ' > ''' + AOutFile.Replace('''', '''\''''') + '''').ToPointer) = 0;
end;
{$ENDIF}

function ReadFiltered(const AFileName, ACommand: string): string;
var
  Cmd, Tmp: string;
begin
  Cmd := ACommand;
  if Cmd = '' then
    Exit(ReadSourceFile(AFileName));
  Tmp := TPath.Combine(TPath.GetTempPath, 'doxypas_' + TGuid.NewGuid.ToString.Substring(1, 8) + '.tmp');
  try
    if RunFilter(Cmd + ' "' + AFileName + '"', Tmp) and TFile.Exists(Tmp) then
      Result := DecodeSourceBytes(TFile.ReadAllBytes(Tmp), AFileName)
    else
    begin
      Warn(AFileName, 0, 'the input filter ' + Cmd + ' failed: the file is read as it is');
      Result := ReadSourceFile(AFileName);
    end;
  finally
    if TFile.Exists(Tmp) then
      TFile.Delete(Tmp);
  end;
end;

var
  VersionCache: TDictionary<string, string>;

procedure SetFileVersionFilter(const ACommand: string);
var
  Cmd: string;
begin
  Cmd := Trim(ACommand);
  FreeAndNil(VersionCache);
  if Cmd = '' then
  begin
    VersionProvider := nil;
    Exit;
  end;
  VersionCache := TDictionary<string, string>.Create;
  VersionProvider :=
    function(const AFileName: string): string
    var
      Tmp: string;
    begin
      TMonitor.Enter(VersionCache);
      try
        if not VersionCache.TryGetValue(AFileName, Result) then
        begin
          Result := '';
          Tmp := TPath.Combine(TPath.GetTempPath, 'doxypas_' + TGuid.NewGuid.ToString.Substring(1, 8) + '.tmp');
          try
            if RunFilter(Cmd + ' "' + AFileName + '"', Tmp) and TFile.Exists(Tmp) then
              Result := Trim(TFile.ReadAllText(Tmp));
          finally
            if TFile.Exists(Tmp) then
              TFile.Delete(Tmp);
          end;
          VersionCache.Add(AFileName, Result);
        end;
      finally
        TMonitor.Exit(VersionCache);
      end;
    end;
end;

function ReadInputFile(const AFileName: string): string;
begin
  Result := ReadFiltered(AFileName, FilterFor(AFileName, FilterPatterns, InputFilter));
end;

function ReadBrowseFile(const AFileName: string): string;
begin
  if SourceFilterOn then
    Result := ReadFiltered(AFileName, FilterFor(AFileName, SourcePatterns, FilterFor(AFileName, FilterPatterns, InputFilter)))
  else
    Result := ReadSourceFile(AFileName);
end;

initialization

finalization
  FreeOwned;
  VersionCache.Free;

end.
