unit DoxyPas.Lang.Pascal.Options;

interface

uses
  DoxyPas.Config,
  DoxyPas.Lang.Pascal.Parser;

/// <summary>Parser options from the configuration: PASCAL_DIALECT, PASCAL_PLATFORM, PREDEFINED, INCLUDE_PATH.</summary>
function PascalOptionsFromConfig(AConfig: TConfig): TPascalParseOptions;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  DoxyPas.Lang.Project;

function PascalOptionsFromConfig(AConfig: TConfig): TPascalParseOptions;
var
  Item, Define: string;
  P: Integer;
  Project: TDelphiProject;
begin
  Result := TPascalParseOptions.Default;
  Result.Defines := DefaultPascalDefines(AConfig.GetString('PASCAL_DIALECT'), AConfig.GetString('PASCAL_PLATFORM'));
  // PREDEFINED entries are NAME or NAME=value; only the name matters to a Pascal conditional
  for Item in AConfig.GetList('PREDEFINED') do
  begin
    P := Pos('=', Item);
    if P > 0 then
      Result.Defines := Result.Defines + [Copy(Item, 1, P - 1)]
    else
      Result.Defines := Result.Defines + [Item];
  end;
  Result.IncludePaths := AConfig.GetList('INCLUDE_PATH');
  // the defines and unit search paths of the Delphi projects
  for Item in AConfig.GetList('DELPHI_PROJECT') do
    if TFile.Exists(Item) then
    begin
      Project := ReadDelphiProject(Item);
      for Define in Project.Defines do
        Result.Defines := Result.Defines + [Define];
      Result.IncludePaths := Result.IncludePaths + Project.SearchPaths;
    end;
end;

end.
