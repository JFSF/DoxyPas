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
  DoxyPas.Model.Entry in 'Model\DoxyPas.Model.Entry.pas',
  DoxyPas.Model.EntryDump in 'Model\DoxyPas.Model.EntryDump.pas',
  DoxyPas.Lang.Pascal.Source in 'Lang\Pascal\DoxyPas.Lang.Pascal.Source.pas',
  DoxyPas.Lang.Pascal.DocBlocks in 'Lang\Pascal\DoxyPas.Lang.Pascal.DocBlocks.pas',
  DoxyPas.Lang.Pascal.Parser in 'Lang\Pascal\DoxyPas.Lang.Pascal.Parser.pas',
  DoxyPas.Lang.Pascal.Dfm in 'Lang\Pascal\DoxyPas.Lang.Pascal.Dfm.pas',
  DoxyPas.Lang.Project in 'Lang\Project\DoxyPas.Lang.Project.pas',
  DoxyPas.Lang.Pascal.Options in 'Lang\Pascal\DoxyPas.Lang.Pascal.Options.pas',
  DoxyPas.Doc.Nodes in 'Doc\DoxyPas.Doc.Nodes.pas',
  DoxyPas.Doc.Dump in 'Doc\DoxyPas.Doc.Dump.pas',
  DoxyPas.Doc.Markdown in 'Doc\DoxyPas.Doc.Markdown.pas',
  DoxyPas.Doc.Parser in 'Doc\DoxyPas.Doc.Parser.pas',
  DoxyPas.Comments.XmlDoc in 'Comments\DoxyPas.Comments.XmlDoc.pas',
  DoxyPas.Comments.Scanner in 'Comments\DoxyPas.Comments.Scanner.pas',
  DoxyPas.Comments.EntryDocs in 'Comments\DoxyPas.Comments.EntryDocs.pas',
  DoxyPas.Model.Defs in 'Model\DoxyPas.Model.Defs.pas',
  DoxyPas.Model.Project in 'Model\DoxyPas.Model.Project.pas',
  DoxyPas.Model.ProjectDump in 'Model\DoxyPas.Model.ProjectDump.pas',
  DoxyPas.Model.Links in 'Model\DoxyPas.Model.Links.pas',
  DoxyPas.Model.Calls in 'Model\DoxyPas.Model.Calls.pas',
  DoxyPas.Output.XmlWriter in 'Output\DoxyPas.Output.XmlWriter.pas',
  DoxyPas.Output.XmlDoc in 'Output\DoxyPas.Output.XmlDoc.pas',
  DoxyPas.Output.XmlGen in 'Output\DoxyPas.Output.XmlGen.pas',
  DoxyPas.Output.HtmlTemplate in 'Output\DoxyPas.Output.HtmlTemplate.pas',
  DoxyPas.Output.SqliteGen in 'Output\DoxyPas.Output.SqliteGen.pas',
  DoxyPas.Output.LatexGen in 'Output\DoxyPas.Output.LatexGen.pas',
  DoxyPas.Output.Translator in 'Output\DoxyPas.Output.Translator.pas',
  DoxyPas.Output.HtmlCode in 'Output\DoxyPas.Output.HtmlCode.pas',
  DoxyPas.Output.HtmlDoc in 'Output\DoxyPas.Output.HtmlDoc.pas',
  DoxyPas.Output.HtmlGen in 'Output\DoxyPas.Output.HtmlGen.pas',
  DoxyPas.Resources.Html in 'Resources\DoxyPas.Resources.Html.pas',
  DoxyPas.Output.TagFile in 'Output\DoxyPas.Output.TagFile.pas',
  DoxyPas.Resources.Xml in 'Resources\DoxyPas.Resources.Xml.pas',
  DoxyPas.Build.Passes in 'Build\DoxyPas.Build.Passes.pas',
  DoxyPas.Build.Pipeline in 'Build\DoxyPas.Build.Pipeline.pas',
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
