unit DoxyPas.Model.Dirs;

{ The directories of the source files (Doxygen's dirdef): a tree rooted at the directory all the unit files share,
  and the dependencies between directories (a unit of one directory uses a unit of another). }

interface

uses
  System.Generics.Collections,
  DoxyPas.Model.Defs,
  DoxyPas.Model.Project,
  DoxyPas.Model.Links;

type
  TDirDef = class
  public
    Name: string;                // last segment
    Path: string;                // shown: root name and the segments below it, "src/UI"
    DiskName: string;            // "dir_<md5 of the path>"
    Parent: TDirDef;
    Dirs: TList<TDirDef>;        // sub-directories (not owned)
    Units: TList<TUnitDef>;      // the units whose file is directly in this directory
    constructor Create(const AName, APath: string; AParent: TDirDef);
    destructor Destroy; override;
  end;

  TDirDependency = record
    Dir: TDirDef;
    Count: Integer;              // units of the first directory using units of Dir
  end;

  TDirTree = class
  strict private
    FRoot: TDirDef;
    FAll: TObjectList<TDirDef>;
    FOf: TDictionary<TUnitDef, TDirDef>;
    function Add(const AName, APath: string; AParent: TDirDef): TDirDef;
  public
    constructor Create(AProject: TProject; ALinks: TLinkResolver);
    destructor Destroy; override;
    property Root: TDirDef read FRoot;     // nil when no unit has a file
    property All: TObjectList<TDirDef> read FAll;
    function DirOf(AUnit: TUnitDef): TDirDef;
    /// <summary>The directories the units of ADir use (AUsers = False) or the directories whose units use ADir.</summary>
    function Dependencies(ADir: TDirDef; AUsers: Boolean): TArray<TDirDependency>;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Defaults,
  System.Hash;

{ TDirDef }

constructor TDirDef.Create(const AName, APath: string; AParent: TDirDef);
begin
  inherited Create;
  Name := AName;
  Path := APath;
  Parent := AParent;
  DiskName := 'dir_' + THashMD5.GetHashString(APath.ToLower);
  Dirs := TList<TDirDef>.Create;
  Units := TList<TUnitDef>.Create;
  if AParent <> nil then
    AParent.Dirs.Add(Self);
end;

destructor TDirDef.Destroy;
begin
  Units.Free;
  Dirs.Free;
  inherited;
end;

{ TDirTree }

function TDirTree.Add(const AName, APath: string; AParent: TDirDef): TDirDef;
begin
  Result := TDirDef.Create(AName, APath, AParent);
  FAll.Add(Result);
end;

constructor TDirTree.Create(AProject: TProject; ALinks: TLinkResolver);
var
  U: TUnitDef;
  Segs: TList<TArray<string>>;
  Units: TList<TUnitDef>;
  Common: TArray<string>;
  I, K, N: Integer;
  S: TArray<string>;
  Cur: TDirDef;
  Key, Shown: string;
  ByPath: TDictionary<string, TDirDef>;
begin
  inherited Create;
  FAll := TObjectList<TDirDef>.Create(True);
  FOf := TDictionary<TUnitDef, TDirDef>.Create;
  Segs := TList<TArray<string>>.Create;
  Units := TList<TUnitDef>.Create;
  ByPath := TDictionary<string, TDirDef>.Create;
  try
    for U in AProject.Units do
      if ALinks.IsLinkable(U) and (U.FileName <> '') then
      begin
        S := AProject.OutputPath(U.FileName).Replace('\', '/').Split(['/']);
        SetLength(S, Length(S) - 1);                       // the file name
        Segs.Add(S);
        Units.Add(U);
      end;
    if Units.Count = 0 then
      Exit;
    // the directory every file is in or below
    Common := Segs[0];
    for I := 1 to Segs.Count - 1 do
    begin
      N := 0;
      while (N < Length(Common)) and (N < Length(Segs[I])) and SameText(Common[N], Segs[I][N]) do
        Inc(N);
      SetLength(Common, N);
    end;
    // a root that has a name: the last shared segment (or "." when there is none)
    if (Length(Common) > 0) and (Common[High(Common)] <> '') then
      Shown := Common[High(Common)]
    else
      Shown := '.';
    FRoot := Add(Shown, Shown, nil);
    ByPath.Add('', FRoot);
    for I := 0 to Units.Count - 1 do
    begin
      Cur := FRoot;
      Key := '';
      for K := Length(Common) to High(Segs[I]) do
      begin
        Key := Key + '/' + Segs[I][K];
        if not ByPath.TryGetValue(Key.ToLower, Cur) then
        begin
          Cur := Add(Segs[I][K], Shown + Key, ByPath[Copy(Key, 1, LastDelimiter('/', Key) - 1).ToLower]);
          ByPath.Add(Key.ToLower, Cur);
        end;
      end;
      Cur.Units.Add(Units[I]);
      FOf.Add(Units[I], Cur);
    end;
  finally
    ByPath.Free;
    Units.Free;
    Segs.Free;
  end;
end;

destructor TDirTree.Destroy;
begin
  FOf.Free;
  FAll.Free;
  inherited;
end;

function TDirTree.DirOf(AUnit: TUnitDef): TDirDef;
begin
  if not FOf.TryGetValue(AUnit, Result) then
    Result := nil;
end;

function TDirTree.Dependencies(ADir: TDirDef; AUsers: Boolean): TArray<TDirDependency>;
var
  Counts: TDictionary<TDirDef, Integer>;
  D, Other: TDirDef;
  U, T: TUnitDef;
  List: TList<TUnitDef>;
  Pair: TPair<TDirDef, Integer>;
  R: TDirDependency;
  Res: TList<TDirDependency>;

  procedure Bump(AKey: TDirDef);
  var
    N: Integer;
  begin
    if not Counts.TryGetValue(AKey, N) then
      N := 0;
    Counts.AddOrSetValue(AKey, N + 1);
  end;

begin
  Counts := TDictionary<TDirDef, Integer>.Create;
  Res := TList<TDirDependency>.Create;
  try
    for D in FAll do
      for U in D.Units do
      begin
        List := TList<TUnitDef>.Create;
        try
          List.AddRange(U.UsesInterface);
          for T in U.UsesImplementation do
            if not List.Contains(T) then
              List.Add(T);
          for T in List do
          begin
            Other := DirOf(T);
            if (Other = nil) or (Other = D) then
              Continue;
            if AUsers and (Other = ADir) then
              Bump(D)
            else if not AUsers and (D = ADir) then
              Bump(Other);
          end;
        finally
          List.Free;
        end;
      end;
    for Pair in Counts do
    begin
      R.Dir := Pair.Key;
      R.Count := Pair.Value;
      Res.Add(R);
    end;
    Res.Sort(TComparer<TDirDependency>.Construct(
      function(const L, R: TDirDependency): Integer
      begin
        Result := CompareText(L.Dir.Path, R.Dir.Path);
      end));
    Result := Res.ToArray;
  finally
    Res.Free;
    Counts.Free;
  end;
end;

end.
