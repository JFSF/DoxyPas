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
  DoxyPas.Comments.EntryDocs;

type
  TCommand = (cmdRun, cmdGenerate, cmdUpdate, cmdDiff);

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
  Writeln('  doxypas --parse <path> [configName] [--docs] [--verbose] [--interface-only]');
  Writeln('                              developer: parse a Pascal file/folder and dump the entries');
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
  ParsePath, DocPath: string;
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
    else if Arg = '-s' then Short := True
    else if (Arg = '--parse') and (I < Length(AArgs)) then
    begin
      ParsePath := AArgs[I];
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
        Writeln('Configuration ''', Name, ''' is valid. Documentation generation is not implemented yet.');
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
