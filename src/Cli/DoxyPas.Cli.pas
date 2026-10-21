unit DoxyPas.Cli;

interface

/// <summary>Command line driver; returns the process exit code.</summary>
function RunCli(const AArgs: TArray<string>): Integer;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  DoxyPas.Core.Version,
  DoxyPas.Core.Timing,
  DoxyPas.Resources.Layout,
  DoxyPas.Core.Log,
  DoxyPas.Config,
  DoxyPas.Config.Reader,
  DoxyPas.Config.Writer,
  DoxyPas.Model.Entry,
  DoxyPas.Model.EntryDump,
  DoxyPas.Lang.Pascal.Parser,
  DoxyPas.Lang.Pascal.Options,
  DoxyPas.Doc.Markdown,
  DoxyPas.Doc.Nodes,
  DoxyPas.Doc.Parser,
  DoxyPas.Doc.Dump,
  DoxyPas.Comments.Scanner,
  DoxyPas.Comments.EntryDocs,
  DoxyPas.Model.Project,
  DoxyPas.Model.ProjectDump,
  DoxyPas.Build.Pipeline,
  DoxyPas.Output.XmlGen,
  DoxyPas.Output.HtmlGen,
  DoxyPas.Output.LatexGen,
  DoxyPas.Output.SqliteGen,
  DoxyPas.Output.TagFile;

type
  TCommand = (cmdRun, cmdGenerate, cmdUpdate, cmdDiff, cmdLayout);

const
  DefaultConfigName = 'Doxyfile';

procedure PrintUsage;
begin
  Writeln('DoxyPas ', DoxyPasVersion, ' (based on Doxygen ', DoxygenReferenceVersion, ')');
  Writeln;
  Writeln('Usage:');
  Writeln('  doxypas [configName]        read configuration (default: ', DefaultConfigName, ')');
  Writeln('  doxypas -g [configName]     generate a template configuration file ("-" = stdout)');
  Writeln('  doxypas -s -g [configName]  same, without explanatory comments');
  Writeln('  doxypas -u [configName]     update a configuration file to this version (-s: strip comments)');
  Writeln('  doxypas -x [configName]     show the options that differ from the defaults');
  Writeln('  doxypas -l [layoutName]     generate a layout file (default: DoxygenLayout.xml, "-" = stdout)');
  Writeln('  doxypas --parse <path> [configName] [--docs] [--verbose] [--interface-only]');
  Writeln('                              developer: parse a Pascal file/folder and dump the entries');
  Writeln('  doxypas --model <path> [configName] [--verbose]');
  Writeln('                              developer: build and dump the semantic model (--verbose: single thread)');
  Writeln('  doxypas --doc <file>        developer: Markdown + documentation parser on a text file');
  Writeln('  doxypas -v | --version      print the version');
  Writeln('  doxypas -h | --help         print this help');
end;

{ Parses the brief/detailed text of every entry; problems found by the documentation parser go to AWarnings. }
procedure CheckEntryDocs(AEntry: TEntry; AWarnings: TStrings);
var
  Child: TEntry;
  Root: TDocNode;
  W: TStringList;
  Msg: string;
begin
  if (AEntry.Brief <> '') or (AEntry.Detailed <> '') then
  begin
    W := TStringList.Create;
    try
      Root := ParseDoc(AEntry.Brief + #10#10 + AEntry.Detailed, W);
      Root.Free;
      for Msg in W do
        AWarnings.Add(Format('%s:%d: %s', [AEntry.FileName, AEntry.DocLine, Msg]));
    finally
      W.Free;
    end;
  end;
  for Child in AEntry.Children do
    CheckEntryDocs(Child, AWarnings);
end;

{ Developer command: parse one Pascal file (dump the entries) or a folder (summary; -V dumps every file). }
function RunParse(const APath, AConfigName: string; AVerbose, AInterfaceOnly, AScanDocs: Boolean): Integer;
var
  Opts: TPascalParseOptions;
  Files: TArray<string>;
  F: string;
  R: TPascalParseResult;
  Ok, Failed: Integer;
  Config: TConfig;
  DocOpts: TDocOptions;
  Warnings: TStringList;
  Msg: string;
begin
  Opts := TPascalParseOptions.Default;
  DocOpts := TDocOptions.Default;
  if AConfigName <> '' then
  begin
    Config := TConfig.Create;
    try
      ReadDoxyfile(Config, AConfigName);
      Config.PostProcess;
      Opts := PascalOptionsFromConfig(Config);
      DocOpts := DocOptionsFromConfig(Config);
    finally
      Config.Free;
    end;
  end;
  Opts.InterfaceOnly := AInterfaceOnly;
  if TDirectory.Exists(APath) then
    Files := TDirectory.GetFiles(APath, '*.pas', TSearchOption.soAllDirectories) +
      TDirectory.GetFiles(APath, '*.dpr', TSearchOption.soAllDirectories) +
      TDirectory.GetFiles(APath, '*.dpk', TSearchOption.soAllDirectories)
  else if TFile.Exists(APath) then
    Files := [APath]
  else
  begin
    Error('', 0, Format('''%s'' not found', [APath]));
    Exit(1);
  end;
  Ok := 0;
  Failed := 0;
  for F in Files do
  begin
    R := ParsePascalFile(F, Opts);
    try
      if R.ErrorMessage = '' then
        Inc(Ok)
      else
      begin
        Inc(Failed);
        Error(F, R.ErrorLine, R.ErrorMessage);
      end;
      if (R.Root <> nil) and AScanDocs then
      begin
        Warnings := TStringList.Create;
        try
          ScanEntryDocs(R.Root, DocOpts, Warnings);
          CheckEntryDocs(R.Root, Warnings);
          for Msg in Warnings do
            Warn('', 0, Msg);
        finally
          Warnings.Free;
        end;
      end;
      if (R.Root <> nil) and (AVerbose or (Length(Files) = 1)) then
        Write(DumpEntry(R.Root));
    finally
      R.Root.Free;
    end;
  end;
  if Length(Files) > 1 then
    Writeln(Format('%d files: %d parsed, %d with syntax errors', [Length(Files), Ok, Failed]));
  if Failed > 0 then
    Result := 1
  else
    Result := 0;
end;

{ The normal run: read the input, build the model and write the enabled outputs. }
function RunGenerate(AConfig: TConfig): Integer;
var
  Files: TArray<string>;
  Project: TProject;
  Out_, Xml, Tag, Msg: string;
  Quiet: Boolean;
  Count: Integer;
begin
  Quiet := AConfig.GetBool('QUIET');
  Out_ := AConfig.GetString('OUTPUT_DIRECTORY');
  if Out_ = '' then
    Out_ := GetCurrentDir;
  Out_ := TPath.GetFullPath(Out_);
  if not Quiet then
    Writeln('Searching for source files...');
  Lap('start');
  Files := CollectInputFiles(AConfig);
  Lap('collect input files');
  if Length(Files) = 0 then
  begin
    Error('', 0, 'no input files found (check INPUT, FILE_PATTERNS and RECURSIVE)');
    Exit(1);
  end;
  if not Quiet then
    Writeln(Format('Parsing %d files...', [Length(Files)]));
  Project := BuildProject(AConfig, Files);
  try
    if AConfig.GetBool('GENERATE_XML') then
    begin
      Xml := TPath.Combine(Out_, AConfig.GetString('XML_OUTPUT'));
      if not Quiet then
        Writeln('Generating XML output...');
      Count := GenerateXml(Project, AConfig, Xml);
      Lap('output: xml');
      if not Quiet then
        Writeln(Format('%d files written to %s', [Count, Xml]));
    end;
    Tag := AConfig.GetString('GENERATE_TAGFILE');
    if Tag <> '' then
    begin
      if not Quiet then
        Writeln('Generating tag file...');
      if TPath.IsRelativePath(Tag) then
        Tag := TPath.Combine(Out_, Tag);
      WriteTagFile(Project, Tag);
    end;
    if AConfig.GetBool('GENERATE_HTML') then
    begin
      Xml := TPath.Combine(Out_, AConfig.GetString('HTML_OUTPUT'));
      if not Quiet then
        Writeln('Generating HTML output...');
      Count := GenerateHtml(Project, AConfig, Xml);
      Lap('output: html');
      if not Quiet then
        Writeln(Format('%d files written to %s', [Count, Xml]));
    end;
    if AConfig.GetBool('GENERATE_LATEX') then
    begin
      Xml := TPath.Combine(Out_, AConfig.GetString('LATEX_OUTPUT'));
      if not Quiet then
        Writeln('Generating LaTeX output...');
      Count := GenerateLatex(Project, AConfig, Xml);
      Lap('output: latex');
      if not Quiet then
        Writeln(Format('%d files written to %s', [Count, Xml]));
    end;
    if AConfig.GetBool('GENERATE_SQLITE3') then
    begin
      Xml := TPath.Combine(Out_, AConfig.GetString('SQLITE3_OUTPUT'));
      if not Quiet then
        Writeln('Generating SQLite script...');
      Count := GenerateSqlite(Project, AConfig, Xml);
      Lap('output: sqlite');
      if not Quiet then
        Writeln(Format('%d files written to %s', [Count, Xml]));
    end;
    if AConfig.GetBool('WARNINGS') then
      for Msg in Project.Warnings do
        Writeln(ErrOutput, Msg);
  finally
    // The process ends right after: the operating system gives the memory back at once, freeing the millions of
    // objects of a big project one by one took 5 s of the 28 s of the RTL + VCL + FMX. DOXYPAS_FREE: free them (to
    // look for leaks).
    if GetEnvironmentVariable('DOXYPAS_FREE') <> '' then
      Project.Free;
    Lap('end of the run');
  end;
  Result := 0;
end;

{ Developer command: build the semantic model of AInput (file or folder, searched recursively) and dump it. }
function RunModel(const AInput, AConfigName: string; ASequential: Boolean): Integer;
var
  Config: TConfig;
  Files: TArray<string>;
  Project: TProject;
  Opt: TConfigOption;
begin
  Config := TConfig.Create;
  try
    if AConfigName <> '' then
      ReadDoxyfile(Config, AConfigName);
    Opt := Config.Find('INPUT');
    Opt.List.Clear;
    Opt.List.Add(AInput);
    Config.Find('RECURSIVE').Raw := 'YES';
    Config.PostProcess;
    Files := CollectInputFiles(Config);
    Project := BuildProject(Config, Files, not ASequential);
    try
      Write(DumpProject(Project));
    finally
      Project.Free;
    end;
  finally
    Config.Free;
  end;
  Result := 0;
end;

{ Developer command: run a documentation text file through Markdown + parser and print the result. }
function RunDocFile(const AFileName: string; AMarkdown: Boolean): Integer;
var
  Text: string;
  Root: TDocNode;
  W: TStringList;
begin
  if not TFile.Exists(AFileName) then
  begin
    Error('', 0, Format('''%s'' not found', [AFileName]));
    Exit(1);
  end;
  Text := TFile.ReadAllText(AFileName, TEncoding.UTF8);
  if AMarkdown then
  begin
    Text := MarkdownToDoxygen(Text);
    Writeln('--- markdown output');
    Writeln(Text);
    Writeln('--- parsed');
  end;
  W := TStringList.Create;
  try
    Root := ParseDoc(Text, W);
    try
      Writeln(DumpDoc(Root));
    finally
      Root.Free;
    end;
    for Text in W do
      Warn(AFileName, 0, Text);
  finally
    W.Free;
  end;
  Result := 0;
end;

procedure WriteText(const AFileName, AText: string);
begin
  if AFileName = '-' then
    Write(AText)
  else
    TFile.WriteAllText(AFileName, AText, TUTF8Encoding.Create(False));
end;

function RunCli(const AArgs: TArray<string>): Integer;
var
  Cmd: TCommand;
  Short, Verbose, IfaceOnly, ScanDocs: Boolean;
  ParsePath, DocPath, ModelPath: string;
  Name, Arg: string;
  I: Integer;
  Config: TConfig;
begin
{$IFDEF MSWINDOWS}
  SetConsoleOutputCP(CP_UTF8); // source text may contain characters outside the console's ANSI code page
{$ENDIF}
  SetTextCodePage(Output, 65001);
  SetTextCodePage(ErrOutput, 65001);
  Cmd := cmdRun;
  Short := False;
  Verbose := False;
  IfaceOnly := False;
  ScanDocs := False;
  ParsePath := '';
  DocPath := '';
  ModelPath := '';
  Name := '';
  I := 0;
  while I < Length(AArgs) do
  begin
    Arg := AArgs[I];
    Inc(I);
    if (Arg = '-v') or (Arg = '--version') then
    begin
      Writeln(DoxyPasVersion);
      Exit(0);
    end
    else if (Arg = '-h') or (Arg = '--help') or (Arg = '-?') then
    begin
      PrintUsage;
      Exit(0);
    end
    else if Arg = '-g' then Cmd := cmdGenerate
    else if Arg = '-u' then Cmd := cmdUpdate
    else if Arg = '-x' then Cmd := cmdDiff
    else if Arg = '-l' then Cmd := cmdLayout
    else if Arg = '-s' then Short := True
    else if (Arg = '--parse') and (I < Length(AArgs)) then
    begin
      ParsePath := AArgs[I];
      Inc(I);
    end
    else if (Arg = '--model') and (I < Length(AArgs)) then
    begin
      ModelPath := AArgs[I];
      Inc(I);
    end
    else if (Arg = '--doc') and (I < Length(AArgs)) then
    begin
      DocPath := AArgs[I];
      Inc(I);
    end
    else if Arg = '--docs' then ScanDocs := True
    else if Arg = '--verbose' then Verbose := True
    else if Arg = '--interface-only' then IfaceOnly := True
    else if (Arg = '-') or ((Arg <> '') and (Arg[1] <> '-')) then
      Name := Arg
    else
    begin
      Error('', 0, Format('unknown option ''%s'' (try -h)', [Arg]));
      Exit(1);
    end;
  end;
  if ModelPath <> '' then
  begin
    try
      Exit(RunModel(ModelPath, Name, Verbose));
    except
      on E: EConfigError do
      begin
        Error('', 0, E.Message);
        Exit(1);
      end;
    end;
  end;
  if DocPath <> '' then
    Exit(RunDocFile(DocPath, not IfaceOnly));
  if ParsePath <> '' then
  begin
    try
      Exit(RunParse(ParsePath, Name, Verbose, IfaceOnly, ScanDocs));
    except
      on E: EConfigError do
      begin
        Error('', 0, E.Message);
        Exit(1);
      end;
    end;
  end;
  if Cmd = cmdLayout then
  begin
    if Name = '' then
      Name := 'DoxygenLayout.xml';
    if (Name <> '-') and TFile.Exists(Name) then
    begin
      Error('', 0, Format('file ''%s'' already exists; remove it or use "-" to write to stdout', [Name]));
      Exit(1);
    end;
    WriteText(Name, LayoutResourceText('DoxygenLayout.xml').Replace('$doxygenversion', DoxyPasVersion));
    if Name <> '-' then
      Writeln('Layout file ''', Name, ''' created.');
    Exit(0);
  end;
  if Name = '' then
    Name := DefaultConfigName;

  Config := TConfig.Create;
  try
    try
      case Cmd of
        cmdGenerate:
          begin
            if (Name <> '-') and TFile.Exists(Name) then
            begin
              Error('', 0, Format('file ''%s'' already exists; remove it or use "-" to write to stdout', [Name]));
              Exit(1);
            end;
            WriteText(Name, WriteDoxyfile(Config, Short, False));
            if Name <> '-' then
              Writeln('Configuration file ''', Name, ''' created.');
          end;
        cmdUpdate:
          begin
            ReadDoxyfile(Config, Name);
            TFile.Copy(Name, Name + '.bak', True);
            WriteText(Name, WriteDoxyfile(Config, Short, True));
            Writeln('Configuration file ''', Name, ''' updated (previous version in ''', Name, '.bak'').');
          end;
        cmdDiff:
          begin
            ReadDoxyfile(Config, Name);
            Config.PostProcess;
            WriteText('-', WriteDoxyfileDiff(Config));
          end;
      else
        ReadDoxyfile(Config, Name);
        Config.PostProcess;
        Exit(RunGenerate(Config));
      end;
      Result := 0;
    except
      on E: EConfigError do
      begin
        Error('', 0, E.Message);
        Result := 1;
      end;
    end;
  finally
    Config.Free;
  end;
end;

end.
