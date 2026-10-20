unit DoxyPas.Cli;

interface

/// <summary>Command line driver; returns the process exit code.</summary>
function RunCli(const AArgs: TArray<string>): Integer;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  DoxyPas.Core.Version,
  DoxyPas.Core.Log,
  DoxyPas.Config,
  DoxyPas.Config.Reader,
  DoxyPas.Config.Writer;

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
  Writeln('  doxypas -v | --version      print the version');
  Writeln('  doxypas -h | --help         print this help');
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
  Short: Boolean;
  Name, Arg: string;
  I: Integer;
  Config: TConfig;
begin
  Cmd := cmdRun;
  Short := False;
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
    else if (Arg = '-') or ((Arg <> '') and (Arg[1] <> '-')) then
      Name := Arg
    else
    begin
      Error('', 0, Format('unknown option ''%s'' (try -h)', [Arg]));
      Exit(1);
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
