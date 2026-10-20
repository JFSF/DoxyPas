program DoxyPas;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DoxyPas.Core.Version in 'Core\DoxyPas.Core.Version.pas',
  DoxyPas.Core.Log in 'Core\DoxyPas.Core.Log.pas';

begin
  if (ParamCount = 1) and (SameText(ParamStr(1), '--version') or SameText(ParamStr(1), '-v')) then
    Writeln(DoxyPasVersion)
  else
  begin
    Writeln('DoxyPas ', DoxyPasVersion, ' (based on Doxygen ', DoxygenReferenceVersion, ')');
    Writeln('Usage: doxypas [--version]');
    if ParamCount > 0 then
      ExitCode := 1;
  end;
end.
