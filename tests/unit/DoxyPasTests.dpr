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
  DoxyPas.Model.Entry in '..\..\src\Model\DoxyPas.Model.Entry.pas',
  DoxyPas.Model.EntryDump in '..\..\src\Model\DoxyPas.Model.EntryDump.pas',
  DoxyPas.Lang.Pascal.Source in '..\..\src\Lang\Pascal\DoxyPas.Lang.Pascal.Source.pas',
  DoxyPas.Lang.Pascal.DocBlocks in '..\..\src\Lang\Pascal\DoxyPas.Lang.Pascal.DocBlocks.pas',
  DoxyPas.Lang.Pascal.Parser in '..\..\src\Lang\Pascal\DoxyPas.Lang.Pascal.Parser.pas',
  DoxyPas.Lang.Pascal.Options in '..\..\src\Lang\Pascal\DoxyPas.Lang.Pascal.Options.pas',
  DoxyPas.Tests.Core in 'DoxyPas.Tests.Core.pas',
  DoxyPas.Tests.Config in 'DoxyPas.Tests.Config.pas',
  DoxyPas.Tests.Pascal in 'DoxyPas.Tests.Pascal.pas';

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
