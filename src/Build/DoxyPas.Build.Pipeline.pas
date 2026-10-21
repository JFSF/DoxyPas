unit DoxyPas.Build.Pipeline;

{ From configuration to the semantic model: collect the input files (INPUT, FILE_PATTERNS, RECURSIVE, EXCLUDE*),
  parse them (in parallel), scan their documentation and run the model passes. }

interface

uses
  System.Classes,
  DoxyPas.Config,
  DoxyPas.Model.Project;

/// <summary>The files selected by INPUT / FILE_PATTERNS / RECURSIVE / EXCLUDE / EXCLUDE_PATTERNS, sorted.</summary>
function CollectInputFiles(AConfig: TConfig): TArray<string>;

/// <summary>Does AText match the wildcard pattern (* and ?), ignoring case?</summary>
function MatchWildcard(const APattern, AText: string): Boolean;

/// <summary>Parses AFiles and builds the model. Syntax errors and documentation problems are added to
/// AProject.Warnings; AParallel parses the files on several threads.</summary>
function BuildProject(AConfig: TConfig; const AFiles: TArray<string>; AParallel: Boolean = True): TProject;

implementation

uses
  DoxyPas.Core.SourceText,
  DoxyPas.Core.Timing,
  System.SysUtils,
  System.IOUtils,
  System.Types,
  System.Threading,
  System.Generics.Collections,
  System.Generics.Defaults,
  DoxyPas.Model.Entry,
  DoxyPas.Lang.Pascal.Parser,
  DoxyPas.Lang.Pascal.Options,
  DoxyPas.Lang.Pascal.Dfm,
  DoxyPas.Lang.Project,
  DoxyPas.Comments.Scanner,
  DoxyPas.Comments.EntryDocs,
  DoxyPas.Build.Passes,
  DoxyPas.Output.TagFile;

const
  PascalPatterns: array[0..4] of string = ('*.pas', '*.dpr', '*.dpk', '*.pp', '*.lpr');

function MatchAt(const P, T: string; PI, TI: Integer): Boolean;
begin
  while PI <= Length(P) do
  begin
    case P[PI] of
      '*':
        begin
          while (PI <= Length(P)) and (P[PI] = '*') do
            Inc(PI);
          if PI > Length(P) then
            Exit(True);
          while TI <= Length(T) + 1 do
          begin
            if MatchAt(P, T, PI, TI) then
              Exit(True);
            Inc(TI);
          end;
          Exit(False);
        end;
      '?':
        if TI > Length(T) then
          Exit(False);
    else
      if (TI > Length(T)) or (UpCase(P[PI]) <> UpCase(T[TI])) then
        Exit(False);
    end;
    Inc(PI);
    Inc(TI);
  end;
  Result := TI > Length(T);
end;

function MatchWildcard(const APattern, AText: string): Boolean;
begin
  Result := MatchAt(APattern.Replace('\', '/'), AText.Replace('\', '/'), 1, 1);
end;

function IsExcluded(const APath: string; const AExclude, APatterns: TArray<string>): Boolean;
var
  E, P, Norm: string;
begin
  Norm := APath.Replace('\', '/');
  for E in AExclude do
    if SameText(Norm, E.Replace('\', '/')) or Norm.StartsWith(E.Replace('\', '/').TrimRight(['/']) + '/',
      True) then
      Exit(True);
  for P in APatterns do
    if MatchWildcard(P, Norm) or MatchWildcard(P, TPath.GetFileName(APath)) then
      Exit(True);
  Result := False;
end;

function CollectInputFiles(AConfig: TConfig): TArray<string>;
var
  Inputs, Patterns, Exclude, ExcludePatterns: TArray<string>;
  Kept: TList<string>;
  Pat: string;
  Files: TList<string>;
  Seen: TDictionary<string, Boolean>;
  Recursive: Boolean;
  In_, F, Full: string;
  Opt: TConfigOption;
  Opt2: TSearchOption;

  procedure AddFile(const APath: string);
  begin
    Full := TPath.GetFullPath(APath);
    if Seen.ContainsKey(LowerCase(Full)) or IsExcluded(Full, Exclude, ExcludePatterns) then
      Exit;
    Seen.Add(LowerCase(Full), True);
    Files.Add(Full);
  end;

  function MatchesPatterns(const AName: string): Boolean;
  var
    P: string;
  begin
    for P in Patterns do
      if MatchWildcard(P, AName) then
        Exit(True);
    Result := False;
  end;

begin
  Inputs := AConfig.GetList('INPUT');
  if Length(Inputs) = 0 then
    Inputs := ['.'];
  Opt := AConfig.Find('FILE_PATTERNS');
  Patterns := AConfig.GetList('FILE_PATTERNS');       // the default list is the one of Pascal (config.xml)
  if (Opt <> nil) and Opt.IsDefault and not AConfig.GetBool('PASCAL_PARSE_DFM') then
  begin
    Kept := TList<string>.Create;
    try
      for Pat in Patterns do
        if not SameText(Pat, '*.dfm') and not SameText(Pat, '*.fmx') then
          Kept.Add(Pat);
      Patterns := Kept.ToArray;
    finally
      Kept.Free;
    end;
  end;
  Recursive := AConfig.GetBool('RECURSIVE');
  Exclude := AConfig.GetList('EXCLUDE');
  ExcludePatterns := AConfig.GetList('EXCLUDE_PATTERNS');
  if Recursive then Opt2 := TSearchOption.soAllDirectories else Opt2 := TSearchOption.soTopDirectoryOnly;
  Files := TList<string>.Create;
  Seen := TDictionary<string, Boolean>.Create;
  try
    for In_ in Inputs do
      if TDirectory.Exists(In_) then
      begin
        for F in TDirectory.GetFiles(In_, '*', Opt2) do
          if MatchesPatterns(TPath.GetFileName(F)) then
            AddFile(F);
      end
      else if TFile.Exists(In_) then
        AddFile(In_);
    for In_ in AConfig.GetList('DELPHI_PROJECT') do
      if TFile.Exists(In_) then
        for F in ReadDelphiProject(In_).Sources do
          if TFile.Exists(F) then
            AddFile(F);
    Files.Sort(TComparer<string>.Construct(
      function(const A, B: string): Integer
      begin
        Result := CompareText(A, B);
      end));
    Result := Files.ToArray;
  finally
    Seen.Free;
    Files.Free;
  end;
end;

type
  TParsed = record
    Root: TEntry;
    Warnings: TStringList;
  end;

  // state shared by the parsing threads: each thread only touches its own element of Parsed
  TParseJob = class
  public
    Files: TArray<string>;
    PascalOptions: TPascalParseOptions;
    DocOptions: TDocOptions;
    DfmProperties: Boolean;
    Parsed: TArray<TParsed>;
    procedure ParseOne(AIndex: Integer);
  end;

procedure TParseJob.ParseOne(AIndex: Integer);
var
  R: TPascalParseResult;
  Local: TStringList;
  Form: TEntry;
  Err: string;
  T0: Int64;
begin
  Local := TStringList.Create;
  Parsed[AIndex].Warnings := Local;
  if MatchWildcard('*.dfm', Files[AIndex]) or MatchWildcard('*.fmx', Files[AIndex]) then
  begin
    Form := ParseDfmFile(Files[AIndex], DfmProperties, Err);
    if Form = nil then
      Local.Add(Format('%s: warning: %s', [Files[AIndex], Err]))
    else
    begin
      ScanEntryDocs(Form, DocOptions, Local);
      Parsed[AIndex].Root := Form;
    end;
    Exit;
  end;
  try
    T0 := Tick;
    R := ParsePascalFile(Files[AIndex], PascalOptions);
    Add('parse: ParsePascalFile (cpu)', T0);
  except
    on E: Exception do
    begin
      Local.Add(Format('%s: error: %s', [Files[AIndex], E.Message]));
      Exit;
    end;
  end;
  if R.ErrorMessage <> '' then
    Local.Add(Format('%s:%d: error: %s', [Files[AIndex], R.ErrorLine, R.ErrorMessage]));
  if R.Root <> nil then
  begin
    T0 := Tick;
    ScanEntryDocs(R.Root, DocOptions, Local);
    Add('parse: ScanEntryDocs (cpu)', T0);
    Parsed[AIndex].Root := R.Root;
  end;
end;

function BuildProject(AConfig: TConfig; const AFiles: TArray<string>; AParallel: Boolean): TProject;
var
  Job: TParseJob;
  I, Last, Threads: Integer;
  W: string;
  Pool: TThreadPool;
begin
  SetInputEncoding(AConfig.GetString('INPUT_ENCODING'), AConfig.GetList('INPUT_FILE_ENCODING'));
  Job := TParseJob.Create;
  try
    Job.Files := AFiles;
    Job.PascalOptions := PascalOptionsFromConfig(AConfig);
    Job.DocOptions := DocOptionsFromConfig(AConfig);
    Job.DfmProperties := AConfig.GetBool('PASCAL_DFM_PROPERTIES');
    SetLength(Job.Parsed, Length(AFiles));
    Last := Length(AFiles) - 1;
    if AParallel and (Last > 0) then
    begin
      // DOXYPAS_THREADS: how many threads parse (development: to see how the parse scales)
      Threads := StrToIntDef(GetEnvironmentVariable('DOXYPAS_THREADS'), 0);
      if Threads > 0 then
      begin
        Pool := TThreadPool.Create;
        try
          Pool.SetMinWorkerThreads(Threads);
          Pool.SetMaxWorkerThreads(Threads);
          TParallel.For(0, Last,
            procedure(AIndex: Integer)
            begin
              Job.ParseOne(AIndex);
            end, Pool);
        finally
          Pool.Free;
        end;
      end
      else
        TParallel.For(0, Last,
          procedure(AIndex: Integer)
          begin
            Job.ParseOne(AIndex);
          end);
    end
    else
      for I := 0 to Last do
        Job.ParseOne(I);
    Lap('parse (all files)');
    Result := TProject.Create(TProjectOptions.FromConfig(AConfig));
    try
      for I := 0 to Last do
      begin
        for W in Job.Parsed[I].Warnings do
          Result.Warnings.Add(W);
        Job.Parsed[I].Warnings.Free;
        if Job.Parsed[I].Root <> nil then
          Result.Roots.Add(Job.Parsed[I].Root);
      end;
      ReadTagFiles(Result, AConfig.GetList('TAGFILES'));
      Lap('tag files');
      BuildModel(Result);
    except
      Result.Free;
      raise;
    end;
  finally
    Job.Free;
  end;
end;

end.
