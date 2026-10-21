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

implementation

uses
  System.IOUtils,
  System.Masks,
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

initialization

finalization
  FreeOwned;

end.
