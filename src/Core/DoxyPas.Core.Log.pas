unit DoxyPas.Core.Log;

interface

type
  TMessageKind = (mkWarning, mkError);

/// <summary>Formats a diagnostic like Doxygen does: "file:line: warning: text".</summary>
function FormatMessage(AKind: TMessageKind; const AFileName: string; ALine: Integer;
  const AText: string): string;

procedure Warn(const AFileName: string; ALine: Integer; const AText: string);
procedure Error(const AFileName: string; ALine: Integer; const AText: string);

implementation

uses
  System.SysUtils;

function FormatMessage(AKind: TMessageKind; const AFileName: string; ALine: Integer;
  const AText: string): string;
const
  KindText: array[TMessageKind] of string = ('warning', 'error');
begin
  if AFileName = '' then
    Result := Format('%s: %s', [KindText[AKind], AText])
  else
    Result := Format('%s:%d: %s: %s', [AFileName, ALine, KindText[AKind], AText]);
end;

procedure Warn(const AFileName: string; ALine: Integer; const AText: string);
begin
  Writeln(ErrOutput, FormatMessage(mkWarning, AFileName, ALine, AText));
end;

procedure Error(const AFileName: string; ALine: Integer; const AText: string);
begin
  Writeln(ErrOutput, FormatMessage(mkError, AFileName, ALine, AText));
end;

end.
