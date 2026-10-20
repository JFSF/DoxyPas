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
  DoxyPas.Lang.Pascal.Dfm in '..\..\src\Lang\Pascal\DoxyPas.Lang.Pascal.Dfm.pas',
  DoxyPas.Lang.Project in '..\..\src\Lang\Project\DoxyPas.Lang.Project.pas',
  DoxyPas.Lang.Pascal.Options in '..\..\src\Lang\Pascal\DoxyPas.Lang.Pascal.Options.pas',
  DoxyPas.Doc.Nodes in '..\..\src\Doc\DoxyPas.Doc.Nodes.pas',
  DoxyPas.Doc.Dump in '..\..\src\Doc\DoxyPas.Doc.Dump.pas',
  DoxyPas.Doc.Markdown in '..\..\src\Doc\DoxyPas.Doc.Markdown.pas',
  DoxyPas.Doc.Parser in '..\..\src\Doc\DoxyPas.Doc.Parser.pas',
  DoxyPas.Comments.XmlDoc in '..\..\src\Comments\DoxyPas.Comments.XmlDoc.pas',
  DoxyPas.Comments.Scanner in '..\..\src\Comments\DoxyPas.Comments.Scanner.pas',
  DoxyPas.Comments.EntryDocs in '..\..\src\Comments\DoxyPas.Comments.EntryDocs.pas',
  DoxyPas.Model.Defs in '..\..\src\Model\DoxyPas.Model.Defs.pas',
  DoxyPas.Model.Project in '..\..\src\Model\DoxyPas.Model.Project.pas',
  DoxyPas.Model.ProjectDump in '..\..\src\Model\DoxyPas.Model.ProjectDump.pas',
  DoxyPas.Model.Links in '..\..\src\Model\DoxyPas.Model.Links.pas',
  DoxyPas.Output.XmlWriter in '..\..\src\Output\DoxyPas.Output.XmlWriter.pas',
  DoxyPas.Output.XmlDoc in '..\..\src\Output\DoxyPas.Output.XmlDoc.pas',
  DoxyPas.Output.XmlGen in '..\..\src\Output\DoxyPas.Output.XmlGen.pas',
  DoxyPas.Output.HtmlTemplate in '..\..\src\Output\DoxyPas.Output.HtmlTemplate.pas',
  DoxyPas.Output.LatexGen in '..\..\src\Output\DoxyPas.Output.LatexGen.pas',
  DoxyPas.Output.HtmlCode in '..\..\src\Output\DoxyPas.Output.HtmlCode.pas',
  DoxyPas.Output.HtmlDoc in '..\..\src\Output\DoxyPas.Output.HtmlDoc.pas',
  DoxyPas.Output.HtmlGen in '..\..\src\Output\DoxyPas.Output.HtmlGen.pas',
  DoxyPas.Resources.Html in '..\..\src\Resources\DoxyPas.Resources.Html.pas',
  DoxyPas.Output.TagFile in '..\..\src\Output\DoxyPas.Output.TagFile.pas',
  DoxyPas.Resources.Xml in '..\..\src\Resources\DoxyPas.Resources.Xml.pas',
  DoxyPas.Build.Passes in '..\..\src\Build\DoxyPas.Build.Passes.pas',
  DoxyPas.Build.Pipeline in '..\..\src\Build\DoxyPas.Build.Pipeline.pas',
  DoxyPas.Tests.Core in 'DoxyPas.Tests.Core.pas',
  DoxyPas.Tests.Config in 'DoxyPas.Tests.Config.pas',
  DoxyPas.Tests.Pascal in 'DoxyPas.Tests.Pascal.pas',
  DoxyPas.Tests.Doc in 'DoxyPas.Tests.Doc.pas',
  DoxyPas.Tests.Model in 'DoxyPas.Tests.Model.pas',
  DoxyPas.Tests.Output in 'DoxyPas.Tests.Output.pas';

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
