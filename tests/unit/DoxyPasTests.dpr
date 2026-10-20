program DoxyPasTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DoxyPas.Core.Version in '..\..\src\Core\DoxyPas.Core.Version.pas',
  DoxyPas.Core.Log in '..\..\src\Core\DoxyPas.Core.Log.pas',
  DoxyPas.Config.Options in '..\..\src\Config\DoxyPas.Config.Options.pas',
  DoxyPas.Config in '..\..\src\Config\DoxyPas.Config.pas',
  DoxyPas.Config.Reader in '..\..\src\Config\DoxyPas.Config.Reader.pas',
  DoxyPas.Config.Writer in '..\..\src\Config\DoxyPas.Config.Writer.pas',
  DoxyPas.Tests.Core in 'DoxyPas.Tests.Core.pas',
  DoxyPas.Tests.Config in 'DoxyPas.Tests.Config.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
begin
  try
    TDUnitX.CheckCommandLine;
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.AddLogger(TDUnitXConsoleLogger.Create(True));
    Results := Runner.Execute;
    if not Results.AllPassed then
      ExitCode := 1;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
