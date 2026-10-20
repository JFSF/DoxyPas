program DoxyPas;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DoxyPas.Core.Version in 'Core\DoxyPas.Core.Version.pas',
  DoxyPas.Core.Log in 'Core\DoxyPas.Core.Log.pas',
  DoxyPas.Config.Options in 'Config\DoxyPas.Config.Options.pas',
  DoxyPas.Config in 'Config\DoxyPas.Config.pas',
  DoxyPas.Config.Reader in 'Config\DoxyPas.Config.Reader.pas',
  DoxyPas.Config.Writer in 'Config\DoxyPas.Config.Writer.pas',
  DoxyPas.Cli in 'Cli\DoxyPas.Cli.pas';

var
  Args: TArray<string>;
  I: Integer;
begin
  SetLength(Args, ParamCount);
  for I := 1 to ParamCount do
    Args[I - 1] := ParamStr(I);
  ExitCode := RunCli(Args);
end.
