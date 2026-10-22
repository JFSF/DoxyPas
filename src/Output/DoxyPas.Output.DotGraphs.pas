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
    /// <summary>DOT_COMMON_ATTR, DOT_NODE_ATTR and DOT_EDGE_ATTR (set by TDotGraphs).</summary>
    class var CommonAttr, NodeAttr, EdgeAttr: string;
    /// <summary>DOT_WRAP_THRESHOLD: the longest line of a node label (0: no wrapping).</summary>
    class var WrapAt: Integer;
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
    FMaxDepth: Integer;           // MAX_DOT_GRAPH_DEPTH
    FUml: Boolean;                // UML_LOOK
    FHideUndoc: Boolean;          // HIDE_UNDOC_RELATIONS
    FUmlDetails: string;          // DOT_UML_DETAILS: NO, YES or NONE
    FUmlLimit: Integer;           // UML_LIMIT_NUM_FIELDS
    FUmlEdgeLabels: Integer;      // UML_MAX_EDGE_LABELS
    function UrlOf(ADef: TDefinition): string;
    function Shown(X: TClassDef): Boolean;
    function UmlLabel(C: TClassDef): string;
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
    FFormat: string;      // as dot knows it (png:cairo)
    FExt: string;         // the extension of the images (png)
    FCleanup: Boolean;
    FPending: TList<string>;
  public
    /// <summary>DOT_BATCH_SIZE: the graphs of each run of dot; DOT_NUM_THREADS: the runs at the same time (0: one for each processor).</summary>
    BatchSize: Integer;
    Threads: Integer;
    /// <summary>The extension of the images (svg, png, ...).</summary>
    property Extension: string read FExt;
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
  System.Character,
  System.IOUtils,
  System.Math,
  System.RegularExpressions,
  System.Threading,
  DoxyPas.Core.Env,
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
  Result := '"' + S.Replace('\', '\\').Replace('"', '\"').Replace(#10, '\n') + '"';
end;

{ TDotBuilder }

// Two lists of attributes as one (either may be empty).
// DOT_WRAP_THRESHOLD: a label longer than the threshold by half is broken after a '.', '_' or ':' (else before a capital
// that follows a small letter, else where the line is full), so that no line is longer than the threshold much.
function WrapLabel(const S: string; AWidth: Integer): string;
var
  Rest: string;
  I, Cut: Integer;
begin
  Result := '';
  Rest := S;
  while (AWidth > 0) and (Length(Rest) > AWidth + AWidth div 2) do
  begin
    Cut := 0;
    for I := AWidth downto AWidth div 2 do
      if CharInSet(Rest[I], ['.', '_', ':']) then
      begin
        Cut := I;
        Break;
      end;
    if Cut = 0 then
      for I := AWidth downto AWidth div 2 do
        if (I > 1) and Rest[I].IsUpper and Rest[I - 1].IsLower then
        begin
          Cut := I - 1;
          Break;
        end;
    if Cut = 0 then
      Cut := AWidth;
    Result := Result + Copy(Rest, 1, Cut) + #10;
    Rest := Copy(Rest, Cut + 1, MaxInt);
  end;
  Result := Result + Rest;
end;

function Join(const A, B: string): string;
begin
  if A = '' then Result := B
  else if B = '' then Result := A
  else Result := A + ',' + B;
end;

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
    '  edge [' + Join(CommonAttr, EdgeAttr) + '];'#10 +   // DOT_COMMON_ATTR goes to the nodes and to the edges
    '  node [' + Join(CommonAttr, NodeAttr) + ', color="gray40", fillcolor="white", style=filled];'#10);
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
  FSB.Append('  n').Append(Result).Append(' [label=').Append(DotQuote(WrapLabel(ALabel, WrapAt))).Append(AStyle);
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
  FMaxDepth := AConfig.GetInt('MAX_DOT_GRAPH_DEPTH');
  FUml := AConfig.GetBool('UML_LOOK');
  FHideUndoc := AConfig.GetBool('HIDE_UNDOC_RELATIONS');
  FUmlDetails := AConfig.GetString('DOT_UML_DETAILS').ToUpper;
  FUmlLimit := AConfig.GetInt('UML_LIMIT_NUM_FIELDS');
  FUmlEdgeLabels := AConfig.GetInt('UML_MAX_EDGE_LABELS');
  TDotBuilder.WrapAt := AConfig.GetInt('DOT_WRAP_THRESHOLD');
  TDotBuilder.CommonAttr := AConfig.GetString('DOT_COMMON_ATTR');
  TDotBuilder.NodeAttr := AConfig.GetString('DOT_NODE_ATTR');
  TDotBuilder.EdgeAttr := AConfig.GetString('DOT_EDGE_ATTR');
  if AConfig.GetString('DOT_FONTPATH') <> '' then
    SetEnv('DOTFONTPATH', AConfig.GetString('DOT_FONTPATH'));
end;

// A related class is in the graph when it has pages, or always with HIDE_UNDOC_RELATIONS = NO.
function TDotGraphs.Shown(X: TClassDef): Boolean;
begin
  Result := (not FHideUndoc) or FLinks.IsLinkable(X);
end;

function TDotGraphs.UrlOf(ADef: TDefinition): string;
begin
  if Assigned(FUrl) then
    Result := FUrl(ADef)
  else
    Result := '';
end;

// The label of a class node in UML_LOOK: a record "{name|fields|methods}" with +/#/- for the visibility.
function TDotGraphs.UmlLabel(C: TClassDef): string;

  function Esc(const S: string): string;
  var
    Ch: Char;
  begin
    Result := '';
    for Ch in S do
      if CharInSet(Ch, ['\', '{', '}', '|', '<', '>', '"']) then
        Result := Result + '\' + Ch
      else
        Result := Result + Ch;
  end;

  function Mark(M: TMemberDef): string;
  begin
    case M.Entry.Protection of
      prProtected, prStrictProtected: Result := '#';
      prPrivate, prStrictPrivate: Result := '-';
    else
      Result := '+';
    end;
  end;

  // The lines of one compartment: up to 50 % over the limit all are shown, beyond that only the limit and "...".
  function Section(AMethods: Boolean): string;
  var
    M: TMemberDef;
    Lines: TList<string>;
    I, Count: Integer;
    S: string;
  begin
    Lines := TList<string>.Create;
    try
      for M in C.Members do
        if ((M.Kind = memFunction) = AMethods) and (M.Kind in [memFunction, memVariable, memProperty]) and
          (M.Entry <> nil) then
        begin
          S := Mark(M) + ' ' + M.Name;
          if FUmlDetails = 'YES' then
            S := S + M.Signature
          else if M.Kind = memFunction then
            S := S + '()';
          Lines.Add(S);
        end;
      Count := Lines.Count;
      if (FUmlLimit > 0) and (Count > FUmlLimit + FUmlLimit div 2) then
        Count := FUmlLimit;
      Result := '';
      for I := 0 to Count - 1 do
        Result := Result + Esc(Lines[I]) + '\l';
      if Count < Lines.Count then
        Result := Result + '...\l';
    finally
      Lines.Free;
    end;
  end;

begin
  Result := '{' + Esc(C.Name) + '\n|' + Section(False) + '|' + Section(True) + '}';
end;

// Doxygen's inheritance graph: all ancestors above the class, its descendants (three levels) below it.
function TDotGraphs.ClassDot(C: TClassDef; ACollab: Boolean): string;
const
  InheritEdge = 'dir="back", color="midnightblue", style="solid"';
var
  G: TDotBuilder;
  MaxDepth: Integer;
  Inherit: string;

  function ClassNode(X: TClassDef; ARoot: Boolean): Integer;
  var
    Style, Url: string;
  begin
    Style := '';
    Url := '';
    if ARoot then
      Style := ', fillcolor="#bfbfbf"'
    else
      Url := UrlOf(X);
    // a later label= overrides the first one; the record label has its own \l escapes
    if FUml and (FUmlDetails <> 'NONE') then
      Style := Style + ', shape=record, label="' + UmlLabel(X) + '"';
    Result := G.Node(X.DiskName, X.Name, Url, Style);
  end;

  procedure Ancestors(X: TClassDef; AId, ADepth: Integer);
  var
    B: TBaseRef;
    P: Integer;
  begin
    if (FMaxDepth > 0) and (ADepth > FMaxDepth) then
      Exit;
    for B in X.Bases do
    begin
      if G.Full then
        Exit;
      if (B.ClassDef <> nil) and Shown(B.ClassDef) then
      begin
        P := ClassNode(B.ClassDef, False);
        G.Edge(P, AId, Inherit);
        Ancestors(B.ClassDef, P, ADepth + 1);
      end
      else
      begin
        P := G.Node('?' + B.Text, B.Text, '', '');
        G.Edge(P, AId, Inherit);
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
      if Shown(D) and not G.Full then
      begin
        N := ClassNode(D, False);
        G.Edge(AId, N, Inherit);
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
            if (T.Def is TClassDef) and (T.Def <> C) and Shown(TClassDef(T.Def)) then
            begin
              X := TClassDef(T.Def);
              if not Labels.TryGetValue(X, S) then
              begin
                Targets.Add(X);
                Labels.Add(X, M.Name);
              end
              else if not ('|' + S.Replace(#10, '|') + '|').Contains('|' + M.Name + '|') and
                ((not FUml) or (FUmlEdgeLabels <= 0) or (Length(S) - Length(S.Replace(#10, '')) + 1 < FUmlEdgeLabels)) then
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
  // the descendants: three levels, or MAX_DOT_GRAPH_DEPTH
  MaxDepth := 3;
  if FMaxDepth > 0 then
    MaxDepth := FMaxDepth;
  Inherit := InheritEdge;
  if FUml then
    Inherit := Inherit + ', arrowtail="onormal"';
  G := TDotBuilder.Create(C.Name, FConfig.GetInt('DOT_GRAPH_MAX_NODES'), 'TB');
  try
    Root := ClassNode(C, True);
    Ancestors(C, Root, 1);
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
var
  G: TDotBuilder;
  MaxDepth: Integer;

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
  MaxDepth := 2;                             // or MAX_DOT_GRAPH_DEPTH
  if FMaxDepth > 0 then
    MaxDepth := FMaxDepth;
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
  FExt := Copy(AFormat, 1, Pos(':', AFormat + ':') - 1);
  FCleanup := ACleanup;
  BatchSize := 25;
  Threads := 1;
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

// dot -T<format> -O writes <name>.dot.<extension> for every file it is given; they are renamed to <name>.<extension>.
function TDotRunner.Flush: Integer;
var
  I, J, N: Integer;
  Cmd, Dot, Img, Target: string;
  Cmds: TList<string>;
  Pool: TThreadPool;
begin
  Result := 0;
  if FPending.Count = 0 then
    Exit;
  Cmds := TList<string>.Create;
  try
    I := 0;
    while I < FPending.Count do
    begin
      Cmd := '"' + FPath + 'dot" -T' + FFormat + ' -O';
      for J := I to Min(I + Max(BatchSize, 1), FPending.Count) - 1 do
        Cmd := Cmd + ' "' + FPending[J] + '.dot"';
      Cmds.Add(Cmd);
      Inc(I, Max(BatchSize, 1));
    end;
    // the runs of dot are independent: several at the same time (the work is the one of dot, in other processes)
    N := Threads;
    if N <= 0 then
      N := TThread.ProcessorCount;
    N := Min(N, Cmds.Count);
    if N <= 1 then
      for I := 0 to Cmds.Count - 1 do
        RunTool(Cmds[I], FDir)
    else
    begin
      Pool := TThreadPool.Create;
      try
        Pool.SetMinWorkerThreads(N);
        Pool.SetMaxWorkerThreads(N);
        TParallel.For(0, Cmds.Count - 1,
          procedure(AIndex: Integer)
          begin
            RunTool(Cmds[AIndex], FDir);
          end, Pool);
      finally
        Pool.Free;
      end;
    end;
  finally
    Cmds.Free;
  end;
  for J := 0 to FPending.Count - 1 do
  begin
    Dot := TPath.Combine(FDir, FPending[J] + '.dot');
    Img := Dot + '.' + FExt;
    Target := TPath.Combine(FDir, FPending[J] + '.' + FExt);
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
  FPending.Clear;
end;
end.
