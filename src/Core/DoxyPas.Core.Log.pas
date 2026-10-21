unit DoxyPas.Core.Log;

{ The diagnostics (warnings and errors) of the run: "file:line: warning: text" like Doxygen, in the format of WARN_FORMAT,
  to the error output or to the file of WARN_LOGFILE. }

interface

type
  TMessageKind = (mkWarning, mkError);

  TLogSink = reference to procedure(const AText: string);

var
  /// <summary>Receives every formatted diagnostic; nil (default) writes to stderr (or to WARN_LOGFILE).</summary>
  LogSink: TLogSink;
  /// <summary>How many diagnostics were written with Warn and Error since ConfigureLog.</summary>
  MessageCount: Integer;

/// <summary>WARN_FORMAT ($file, $line and $text; "" is the default "$file:$line: $text") and WARN_LOGFILE ("" is stderr, "-" is
/// stdout, else the file that is made again). Resets MessageCount.</summary>
procedure ConfigureLog(const AFormat, ALogFile: string);

/// <summary>Formats a diagnostic like Doxygen does: "file:line: warning: text".</summary>
function FormatMessage(AKind: TMessageKind; const AFileName: string; ALine: Integer;
  const AText: string): string;

/// <summary>A diagnostic that was formatted already as "file:line: text" or "warning: text" (the warnings of the model), in
/// the format of WARN_FORMAT.</summary>
function ReformatMessage(const AText: string): string;

/// <summary>Writes a diagnostic that is formatted already.</summary>
procedure Emit(const AText: string);

procedure Warn(const AFileName: string; ALine: Integer; const AText: string);
procedure Error(const AFileName: string; ALine: Integer; const AText: string);

implementation

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.RegularExpressions;

var
  Format_: string = '$file:$line: $text';
  LogFile: string;
  Writer: TStreamWriter;
  Lock: TObject;

procedure CloseLog;
begin
  FreeAndNil(Writer);
end;

procedure ConfigureLog(const AFormat, ALogFile: string);
begin
  CloseLog;
  if Trim(AFormat) = '' then
    Format_ := '$file:$line: $text'
  else
    Format_ := AFormat;
  LogFile := ALogFile;
  MessageCount := 0;
  if (LogFile <> '') and (LogFile <> '-') then
    try
      Writer := TStreamWriter.Create(LogFile, False, TEncoding.UTF8);
    except
      on Exception do
        Writer := nil;                     // it cannot be written: stderr
    end;
end;

// The format with its $file, $line, $text and $version replaced.
function Apply(const AFileName: string; ALine: Integer; const AText: string): string;
var
  I: Integer;
  SB: TStringBuilder;

  function Take(const AName, AValue: string): Boolean;
  begin
    Result := Copy(Format_, I, Length(AName)) = AName;
    if Result then
    begin
      SB.Append(AValue);
      Inc(I, Length(AName));
    end;
  end;

begin
  SB := TStringBuilder.Create;
  try
    I := 1;
    while I <= Length(Format_) do
      if (Format_[I] <> '$') or not (Take('$file', AFileName) or Take('$line', IntToStr(ALine)) or
        Take('$text', AText) or Take('$version', '')) then
      begin
        SB.Append(Format_[I]);
        Inc(I);
      end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function FormatMessage(AKind: TMessageKind; const AFileName: string; ALine: Integer;
  const AText: string): string;
const
  KindText: array[TMessageKind] of string = ('warning', 'error');
begin
  if AFileName = '' then
    Result := Format('%s: %s', [KindText[AKind], AText])
  else
    Result := Apply(AFileName, ALine, Format('%s: %s', [KindText[AKind], AText]));
end;

function ReformatMessage(const AText: string): string;
var
  M: TMatch;
  Text: string;
begin
  M := TRegEx.Match(AText, '^(.+?):(\d+): (.*)$', [roSingleLine]);
  if not M.Success then
    Exit(AText);
  Text := M.Groups[3].Value;
  if not (Text.StartsWith('warning:') or Text.StartsWith('error:')) then
    Text := 'warning: ' + Text;
  Result := Apply(M.Groups[1].Value, StrToIntDef(M.Groups[2].Value, 0), Text);
end;

procedure Emit(const AText: string);
begin
  TMonitor.Enter(Lock);
  try
    if Assigned(LogSink) then
      LogSink(AText)
    else if Writer <> nil then
    begin
      Writer.WriteLine(AText);
      Writer.Flush;
    end
    else if LogFile = '-' then
      Writeln(AText)
    else
      Writeln(ErrOutput, AText);
  finally
    TMonitor.Exit(Lock);
  end;
end;

procedure Warn(const AFileName: string; ALine: Integer; const AText: string);
begin
  TInterlocked.Increment(MessageCount);
  Emit(FormatMessage(mkWarning, AFileName, ALine, AText));
end;

procedure Error(const AFileName: string; ALine: Integer; const AText: string);
begin
  TInterlocked.Increment(MessageCount);
  Emit(FormatMessage(mkError, AFileName, ALine, AText));
end;

initialization
  Lock := TObject.Create;

finalization
  CloseLog;
  Lock.Free;

end.