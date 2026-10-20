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
  DoxyPas.Lang.Pascal.Options in 'Lang\Pascal\DoxyPas.Lang.Pascal.Options.pas',
  DoxyPas.Doc.Nodes in 'Doc\DoxyPas.Doc.Nodes.pas',
  DoxyPas.Doc.Dump in 'Doc\DoxyPas.Doc.Dump.pas',
  DoxyPas.Doc.Markdown in 'Doc\DoxyPas.Doc.Markdown.pas',
  DoxyPas.Doc.Parser in 'Doc\DoxyPas.Doc.Parser.pas',
  DoxyPas.Comments.XmlDoc in 'Comments\DoxyPas.Comments.XmlDoc.pas',
  DoxyPas.Comments.Scanner in 'Comments\DoxyPas.Comments.Scanner.pas',
  DoxyPas.Comments.EntryDocs in 'Comments\DoxyPas.Comments.EntryDocs.pas',
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
