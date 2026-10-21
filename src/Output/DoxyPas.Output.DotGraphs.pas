unit DoxyPas.Output.DotGraphs;

{ The dot graphs shared by the HTML and LaTeX outputs: the text of the graphs of a class (inheritance, collaboration),
  of a unit (uses, used by) and of a routine (calls, callers), and the runner of dot. }

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DoxyPas.Config,
  DoxyPas.Model.Defs,
  DoxyPas.Model.Project,
  DoxyPas.Model.Links,
  DoxyPas.Model.Calls;

type
  /// <summary>The URL a node of a graph links to ('' for none).</summary>
  TDefUrl = reference to function(ADef: TDefinition): string;

  /// <summary>Builds the text of one dot graph; stops adding nodes at DOT_GRAPH_MAX_NODES.</summary>
  TDotBuilder = class
  strict private
    FSB: TStringBuilder;
    FIds: TDictionary<string, Integer>;
    FMax: Integer;
  public
    constructor Create(const AName: string; AMaxNodes: Integer; const ARankDir: string);
    destructor Destroy; override;
    function Full: Boolean;
    function Node(const AKey, ALabel, AUrl, AStyle: string): Integer;
    procedure Edge(AFrom, ATo: Integer; const AAttrs: string);
    function Finish: string;
  end;


  TDotGraphs = class
  strict private
    FProject: TProject;
    FLinks: TLinkResolver;
    FConfig: TConfig;
    FCalls: TCallIndex;
    FUrl: TDefUrl;
    function UrlOf(ADef: TDefinition): string;
  public
    /// <summary>ACalls (CALL_GRAPH / CALLER_GRAPH) and AUrl may be nil.</summary>
    constructor Create(AProject: TProject; ALinks: TLinkResolver; AConfig: TConfig; ACalls: TCallIndex;
      const AUrl: TDefUrl);
    /// <summary>Inheritance graph; with ACollab the collaboration graph.</summary>
    function ClassDot(C: TClassDef; ACollab: Boolean): string;
    /// <summary>The units U uses; with AUsedBy the units that use U.</summary>
    function UnitDot(U: TUnitDef; AUsedBy: Boolean): string;
    /// <summary>What M calls; with ACallers the routines that call M.</summary>
    function CallDot(M: TMemberDef; ACallers: Boolean): string;
  end;

  /// <summary>Writes the .dot files and turns them into images with a single dot run per 25 files.</summary>
  TDotRunner = class
  strict private
    FDir: string;
    FPath: string;
    FFormat: string;
    FCleanup: Boolean;
    FPending: TList<string>;
  public
    /// <summary>ADotPath: DOT_PATH; AFormat: svg, pdf, png...</summary>
    constructor Create(const ADir, ADotPath, AFormat: string; ACleanup: Boolean);
    destructor Destroy; override;
    /// <summary>dot can be run.</summary>
    function Available: Boolean;
    /// <summary>Writes ABase.dot; the image ABase.<format> exists after Flush.</summary>
    procedure Queue(const ABase, ADot: string);
    /// <summary>Runs dot on the queued files; returns the number of images made.</summary>
    function Flush: Integer;
  end;

function DotQuote(const S: string): string;

/// <summary>Runs a command line in ADir and waits for it; False when it could not be started or failed.</summary>
function RunTool(const ACmd, ADir: string): Boolean;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
{$IFDEF POSIX}
  Posix.Stdlib,
{$ENDIF}
  System.Classes,
  System.IOUtils,
  System.Math,
  System.RegularExpressions,
  DoxyPas.Model.Entry;

{$IFDEF MSWINDOWS}
// Runs a command line in ADir and waits for it; False when it could not be started or exited with a non-zero code.
function RunTool(const ACmd, ADir: string): Boolean;
var
  SI: TStartupInfo;
  PI: TProcessInformation;
  Cmd: string;
  Code: Cardinal;
begin
  Result := False;
  ZeroMemory(@SI, SizeOf(SI));
  SI.cb := SizeOf(SI);
  Cmd := ACmd;
  UniqueString(Cmd);
  if CreateProcess(nil, PChar(Cmd), nil, nil, False, CREATE_NO_WINDOW, nil, PChar(ADir), SI, PI) then
  begin
    WaitForSingleObject(PI.hProcess, 600000);
    GetExitCodeProcess(PI.hProcess, Code);
    Result := Code = 0;
    CloseHandle(PI.hProcess);
    CloseHandle(PI.hThread);
  end;
end;
{$ENDIF}
{$IFDEF POSIX}
// Same for Linux: through the shell (system), in ADir, without output.
function RunTool(const ACmd, ADir: string): Boolean;
var
  M: TMarshaller;
begin
  Result := _system(M.AsAnsi('cd ''' + ADir.Replace('''', '''\''''') + ''' && ' + ACmd + ' >/dev/null 2>&1').ToPointer) = 0;
end;
{$ENDIF}
function DotQuote(const S: string): string;
begin
  Result := '"' + S.Replace('\', '\\').Replace('"', '\"') + '"';
end;

{ TDotBuilder }

constructor TDotBuilder.Create(const AName: string; AMaxNodes: Integer; const ARankDir: string);
begin
  inherited Create;
  FMax := AMaxNodes;
  if FMax <= 0 then
    FMax := MaxInt;
  FSB := TStringBuilder.Create;
  FIds := TDictionary<string, Integer>.Create;
  FSB.Append('digraph ').Append(DotQuote(AName)).Append(' {'#10'  rankdir=').Append(ARankDir).Append(';'#10 +
    '  bgcolor="transparent";'#10 +
    '  edge [fontname="Helvetica", fontsize=10, labelfontname="Helvetica", labelfontsize=10];'#10 +
    '  node [fontname="Helvetica", fontsize=10, shape=box, height=0.2, width=0.4, color="gray40", ' +
    'fillcolor="white", style=filled];'#10);
end;

destructor TDotBuilder.Destroy;
begin
  FIds.Free;
  FSB.Free;
  inherited;
end;

function TDotBuilder.Full: Boolean;
begin
  Result := FIds.Count >= FMax;
end;

// Existing nodes are reused (AKey); a new one is created even when the graph is full so that edges stay valid.
function TDotBuilder.Node(const AKey, ALabel, AUrl, AStyle: string): Integer;
begin
  if FIds.TryGetValue(AKey, Result) then
    Exit;
  Result := FIds.Count;
  FIds.Add(AKey, Result);
  FSB.Append('  n').Append(Result).Append(' [label=').Append(DotQuote(ALabel)).Append(AStyle);
  if AUrl <> '' then
    FSB.Append(', URL=').Append(DotQuote(AUrl)).Append(', target="_top"');
  FSB.Append('];'#10);
end;

procedure TDotBuilder.Edge(AFrom, ATo: Integer; const AAttrs: string);
begin
  FSB.Append('  n').Append(AFrom).Append(' -> n').Append(ATo).Append(' [').Append(AAttrs).Append('];'#10);
end;

function TDotBuilder.Finish: string;
begin
  Result := FSB.Append('}'#10).ToString;
end;


{ TDotGraphs }

constructor TDotGraphs.Create(AProject: TProject; ALinks: TLinkResolver; AConfig: TConfig; ACalls: TCallIndex;
  const AUrl: TDefUrl);
begin
  inherited Create;
  FProject := AProject;
  FLinks := ALinks;
  FConfig := AConfig;
  FCalls := ACalls;
  FUrl := AUrl;
end;

function TDotGraphs.UrlOf(ADef: TDefinition): string;
begin
  if Assigned(FUrl) then
    Result := FUrl(ADef)
  else
    Result := '';
end;

// Doxygen's inheritance graph: all ancestors above the class, its descendants (three levels) below it.
function TDotGraphs.ClassDot(C: TClassDef; ACollab: Boolean): string;
const
  MaxDepth = 3;
  InheritEdge = 'dir="back", color="midnightblue", style="solid"';
var
  G: TDotBuilder;

  function ClassNode(X: TClassDef; ARoot: Boolean): Integer;
  begin
    if ARoot then
      Result := G.Node(X.DiskName, X.Name, '', ', fillcolor="#bfbfbf"')
    else
      Result := G.Node(X.DiskName, X.Name, UrlOf(X), '');
  end;

  procedure Ancestors(X: TClassDef; AId: Integer);
  var
    B: TBaseRef;
    P: Integer;
  begin
    for B in X.Bases do
    begin
      if G.Full then
        Exit;
      if (B.ClassDef <> nil) and FLinks.IsLinkable(B.ClassDef) then
      begin
        P := ClassNode(B.ClassDef, False);
        G.Edge(P, AId, InheritEdge);
        Ancestors(B.ClassDef, P);
      end
      else
      begin
        P := G.Node('?' + B.Text, B.Text, '', '');
        G.Edge(P, AId, InheritEdge);
      end;
    end;
  end;

  procedure Descendants(X: TClassDef; AId, ADepth: Integer);
  var
    D: TClassDef;
    N: Integer;
  begin
    if ADepth > MaxDepth then
      Exit;
    for D in X.Derived do
      if FLinks.IsLinkable(D) and not G.Full then
      begin
        N := ClassNode(D, False);
        G.Edge(AId, N, InheritEdge);
        Descendants(D, N, ADepth + 1);
      end;
  end;

  // member of C -> project class named in its type
  procedure Usages(AId: Integer);
  var
    Targets: TList<TClassDef>;
    Labels: TDictionary<TClassDef, string>;
    M: TMemberDef;
    Mt: TMatch;
    T: TLinkTarget;
    X: TClassDef;
    S: string;
  begin
    Targets := TList<TClassDef>.Create;
    Labels := TDictionary<TClassDef, string>.Create;
    try
      for M in C.Members do
        if (M.Kind in [memVariable, memProperty]) and (M.Entry.TypeText <> '') then
          for Mt in TRegEx.Matches(M.Entry.TypeText, '[A-Za-z_][A-Za-z_0-9.]*') do
          begin
            T := FLinks.Resolve(Mt.Value, M);
            if (T.Def is TClassDef) and (T.Def <> C) and FLinks.IsLinkable(T.Def) then
            begin
              X := TClassDef(T.Def);
              if not Labels.TryGetValue(X, S) then
              begin
                Targets.Add(X);
                Labels.Add(X, M.Name);
              end
              else if not ('|' + S.Replace(#10, '|') + '|').Contains('|' + M.Name + '|') then
                Labels[X] := S + #10 + M.Name;
            end;
          end;
      for X in Targets do
        if not G.Full then
          G.Edge(AId, ClassNode(X, False), 'color="darkorchid3", style="dashed", arrowhead="open", label=' +
            DotQuote(Labels[X]));
    finally
      Labels.Free;
      Targets.Free;
    end;
  end;

var
  Root: Integer;
begin
  G := TDotBuilder.Create(C.Name, FConfig.GetInt('DOT_GRAPH_MAX_NODES'), 'TB');
  try
    Root := ClassNode(C, True);
    Ancestors(C, Root);
    if ACollab then
      Usages(Root)
    else
      Descendants(C, Root, 1);
    Result := G.Finish;
  finally
    G.Free;
  end;
end;

// Include graphs of a unit: the units it uses (or, with AUsedBy, the units that use it).
// shortcut: direct dependencies only (a transitive graph is unreadable beyond a handful of units), add a depth limit if wanted.
function TDotGraphs.UnitDot(U: TUnitDef; AUsedBy: Boolean): string;
var
  G: TDotBuilder;

  procedure Walk(X: TUnitDef; AId: Integer);
  var
    S: string;
    T: TUnitDef;
    N: Integer;
  begin
    if AUsedBy then
    begin
      for T in X.UsedBy do
        if FLinks.IsLinkable(T) and not G.Full then
        begin
          N := G.Node(T.DiskName, T.Name, UrlOf(T), '');
          G.Edge(N, AId, 'color="midnightblue", arrowhead="open"');
        end;
      Exit;
    end;
    for S in X.UsesInterfaceNames do
    begin
      if G.Full then
        Exit;
      T := FProject.FindUnit(S);
      if (T <> nil) and FLinks.IsLinkable(T) then
      begin
        N := G.Node(T.DiskName, T.Name, UrlOf(T), '');
        G.Edge(AId, N, 'color="midnightblue", arrowhead="open"');
      end
      else
        G.Edge(AId, G.Node('?' + S, S, '', ', color="gray60"'), 'color="midnightblue", arrowhead="open"');
    end;
  end;

begin
  G := TDotBuilder.Create(U.Name, FConfig.GetInt('DOT_GRAPH_MAX_NODES'), 'LR');
  try
    Walk(U, G.Node(U.DiskName, U.Name, '', ', fillcolor="#bfbfbf"'));
    Result := G.Finish;
  finally
    G.Free;
  end;
end;


// Call graph of a routine (what it calls) or, with ACallers, its caller graph; two levels deep.
// shortcut: depth 2, deeper chains make the graph unreadable; the calls are found by name (see DoxyPas.Model.Calls).
function TDotGraphs.CallDot(M: TMemberDef; ACallers: Boolean): string;
const
  MaxDepth = 2;
var
  G: TDotBuilder;

  function NodeOf(X: TMemberDef; ARoot: Boolean): Integer;
  var
    Name, Style: string;
  begin
    Name := X.Name;
    if X.Scope is TClassDef then
      Name := X.Scope.Name + '.' + Name;
    if ARoot then
      Result := G.Node(X.DiskName, Name, '', ', fillcolor="#bfbfbf"')
    else
      Result := G.Node(X.DiskName, Name, UrlOf(X), '');
  end;

  procedure Walk(X: TMemberDef; AId, ADepth: Integer);
  var
    L: TList<TMemberDef>;
    T: TMemberDef;
    N: Integer;
  begin
    if ADepth > MaxDepth then
      Exit;
    if ACallers then
      L := FCalls.CallersOf(X)
    else
      L := FCalls.CallsOf(X);
    if L = nil then
      Exit;
    for T in L do
      if not G.Full then
      begin
        N := NodeOf(T, False);
        if ACallers then
          G.Edge(N, AId, 'color="midnightblue", arrowhead="open"')
        else
          G.Edge(AId, N, 'color="midnightblue", arrowhead="open"');
        Walk(T, N, ADepth + 1);
      end;
  end;

begin
  G := TDotBuilder.Create(M.Name, FConfig.GetInt('DOT_GRAPH_MAX_NODES'), 'LR');
  try
    Walk(M, NodeOf(M, True), 1);
    Result := G.Finish;
  finally
    G.Free;
  end;
end;


{ TDotRunner }

constructor TDotRunner.Create(const ADir, ADotPath, AFormat: string; ACleanup: Boolean);
begin
  inherited Create;
  FDir := ADir;
  FPath := ADotPath;
  if FPath <> '' then
    FPath := IncludeTrailingPathDelimiter(FPath);
  FFormat := AFormat;
  FCleanup := ACleanup;
  FPending := TList<string>.Create;
end;

destructor TDotRunner.Destroy;
begin
  FPending.Free;
  inherited;
end;

function TDotRunner.Available: Boolean;
begin
  Result := RunTool('"' + FPath + 'dot" -V', FDir);
end;

procedure TDotRunner.Queue(const ABase, ADot: string);
begin
  TFile.WriteAllText(TPath.Combine(FDir, ABase + '.dot'), ADot, TUTF8Encoding.Create(False)); // dot 2.x rejects a BOM
  FPending.Add(ABase);
end;

// dot -T<format> -O writes <name>.dot.<format> for every file it is given; they are renamed to <name>.<format>.
function TDotRunner.Flush: Integer;
const
  Chunk = 25;
var
  I, J: Integer;
  Cmd, Dot, Img, Target: string;
begin
  Result := 0;
  I := 0;
  while I < FPending.Count do
  begin
    Cmd := '"' + FPath + 'dot" -T' + FFormat + ' -O';
    for J := I to Min(I + Chunk, FPending.Count) - 1 do
      Cmd := Cmd + ' "' + FPending[J] + '.dot"';
    RunTool(Cmd, FDir);
    for J := I to Min(I + Chunk, FPending.Count) - 1 do
    begin
      Dot := TPath.Combine(FDir, FPending[J] + '.dot');
      Img := Dot + '.' + FFormat;
      Target := TPath.Combine(FDir, FPending[J] + '.' + FFormat);
      if TFile.Exists(Img) then
      begin
        if TFile.Exists(Target) then
          TFile.Delete(Target);
        TFile.Move(Img, Target);
        Inc(Result);
      end;
      if FCleanup then
        TFile.Delete(Dot);
    end;
    Inc(I, Chunk);
  end;
  FPending.Clear;
end;

end.