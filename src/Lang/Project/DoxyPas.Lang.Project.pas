unit DoxyPas.Lang.Project;

{ Delphi project files (.dproj, .dpr, .dpk): the source files they list, the conditional defines and the unit search
  paths. The .dproj is read with regular expressions (no XML parser: it also has to work on Linux); only the settings
  that apply to every configuration (the "Base" property groups) are used. }

interface

type
  TDelphiProject = record
    Sources: TArray<string>;      // full paths of the .pas/.dpr/.dpk files
    Defines: TArray<string>;
    SearchPaths: TArray<string>;  // full paths
  end;

/// <summary>Reads a .dproj, .dpr or .dpk. Raises an exception if the file cannot be read.</summary>
function ReadDelphiProject(const AFileName: string): TDelphiProject;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.RegularExpressions,
  System.Generics.Collections;

procedure AddUnique(AList: TList<string>; const AValue: string);
var
  S: string;
begin
  for S in AList do
    if SameText(S, AValue) then
      Exit;
  AList.Add(AValue);
end;

function FullPath(const ABase, APath: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(ABase, APath.Replace('\', PathDelim).Replace('/', PathDelim)));
end;

// the first group of the first match ('' if there is none: a failed match has no groups)
function Capture(const AText, APattern: string): string;
var
  M: TMatch;
begin
  M := TRegEx.Match(AText, APattern);
  if M.Success and (M.Groups.Count > 1) then
    Result := M.Groups[1].Value
  else
    Result := '';
end;

procedure ReadDproj(const AText, ADir: string; ASources, ADefines, APaths: TList<string>);
var
  M: TMatch;
  S, Item, Cond: string;
  Last: Integer;
begin
  for M in TRegEx.Matches(AText, '<MainSource>([^<]+)</MainSource>') do
    AddUnique(ASources, FullPath(ADir, M.Groups[1].Value));
  for M in TRegEx.Matches(AText, '<DCCReference\s+Include="([^"]+)"') do
  begin
    S := M.Groups[1].Value;
    if SameText(ExtractFileExt(S), '.pas') then
      AddUnique(ASources, FullPath(ADir, S));
  end;
  // only the groups without a Condition or with the "Base" one apply to every configuration
  for M in TRegEx.Matches(AText, '<PropertyGroup(?:\s+Condition="([^"]*)")?\s*>(.*?)</PropertyGroup>',
    [roSingleLine]) do
  begin
    Last := M.Groups.Count - 1;   // an optional group that did not take part is missing from the collection
    Cond := '';
    if M.Groups.Count > 2 then
      Cond := M.Groups[1].Value;
    if Cond.Contains('Base') or (Cond = '') then
    begin
      S := Capture(M.Groups[Last].Value, '<DCC_Define>([^<]*)</DCC_Define>');
      for Item in S.Split([';']) do
        if (Trim(Item) <> '') and not Item.StartsWith('$(') then
          AddUnique(ADefines, Trim(Item));
      S := Capture(M.Groups[Last].Value, '<DCC_UnitSearchPath>([^<]*)</DCC_UnitSearchPath>');
      for Item in S.Split([';']) do
        if (Trim(Item) <> '') and not Item.Contains('$(') then
          AddUnique(APaths, FullPath(ADir, Trim(Item)));
    end;
  end;
end;

procedure ReadSourceList(const AText, ADir: string; ASources: TList<string>);
var
  M: TMatch;
begin
  // uses Unit1 in 'src\Unit1.pas', ...  /  contains ...
  for M in TRegEx.Matches(AText, '\bin\s+''([^'']+\.pas)''', [roIgnoreCase]) do
    AddUnique(ASources, FullPath(ADir, M.Groups[1].Value));
end;

function ReadDelphiProject(const AFileName: string): TDelphiProject;
var
  Text, Dir: string;
  Sources, Defines, Paths: TList<string>;
begin
  Text := TFile.ReadAllText(AFileName);
  Dir := ExtractFilePath(TPath.GetFullPath(AFileName));
  Sources := TList<string>.Create;
  Defines := TList<string>.Create;
  Paths := TList<string>.Create;
  try
    if SameText(ExtractFileExt(AFileName), '.dproj') then
      ReadDproj(Text, Dir, Sources, Defines, Paths)
    else
    begin
      AddUnique(Sources, TPath.GetFullPath(AFileName));
      ReadSourceList(Text, Dir, Sources);
    end;
    Result.Sources := Sources.ToArray;
    Result.Defines := Defines.ToArray;
    Result.SearchPaths := Paths.ToArray;
  finally
    Paths.Free;
    Defines.Free;
    Sources.Free;
  end;
end;

end.
