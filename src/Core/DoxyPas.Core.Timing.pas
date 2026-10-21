unit DoxyPas.Core.Timing;

{ Phase timing for development: with the environment variable DOXYPAS_TIMING set, Lap writes the time of each phase to
  the error output (the time since the previous lap and the total). Without it nothing is measured or written. }

interface

/// <summary>Ends the phase called AWhat.</summary>
procedure Lap(const AWhat: string);

/// <summary>For the time spent in a piece of code that is run many times: T0 := Tick; ...; Add('name', T0). The totals are
/// written when the program ends. Without DOXYPAS_TIMING Tick is 0 and Add does nothing.</summary>
function Tick: Int64;
procedure Add(const AWhat: string; AStart: Int64);

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  System.Generics.Collections,
  System.Generics.Defaults{$IFDEF MSWINDOWS},
  Winapi.Windows,
  Winapi.PsAPI{$ENDIF};

var
  Enabled: Boolean;
  Watch: TStopwatch;
  LastMs: Int64;
  Totals: TDictionary<string, Int64>;
  Counts: TDictionary<string, Integer>;
  Lock: TObject;

{$IFDEF MSWINDOWS}
function LiveMB: Int64;
var
  C: TProcessMemoryCounters;
begin
  C.cb := SizeOf(C);
  if GetProcessMemoryInfo(GetCurrentProcess, @C, SizeOf(C)) then
    Result := C.WorkingSetSize div (1024 * 1024)
  else
    Result := 0;
end;
{$ENDIF}

procedure Lap(const AWhat: string);
var
  Now_: Int64;
begin
  if not Enabled then
    Exit;
  Now_ := Watch.ElapsedMilliseconds;
{$IFDEF MSWINDOWS}
  Writeln(ErrOutput, Format('[timing] %-28s %8d ms   (total %d ms, %d MB)', [AWhat, Now_ - LastMs, Now_, LiveMB]));
{$ELSE}
  Writeln(ErrOutput, Format('[timing] %-28s %8d ms   (total %d ms)', [AWhat, Now_ - LastMs, Now_]));
{$ENDIF}
  LastMs := Now_;
end;

function Tick: Int64;
begin
  if Enabled then
    Result := TStopwatch.GetTimeStamp
  else
    Result := 0;
end;

procedure Add(const AWhat: string; AStart: Int64);
var
  Spent, N_: Int64;
  N: Integer;
begin
  if not Enabled then
    Exit;
  Spent := (TStopwatch.GetTimeStamp - AStart) * 1000 div TStopwatch.Frequency;
  TMonitor.Enter(Lock);
  try
    if not Totals.TryGetValue(AWhat, N_) then
      N_ := 0;
    Totals.AddOrSetValue(AWhat, N_ + Spent);
    if not Counts.TryGetValue(AWhat, N) then
      N := 0;
    Counts.AddOrSetValue(AWhat, N + 1);
  finally
    TMonitor.Exit(Lock);
  end;
end;

procedure Report;
var
  P: TPair<string, Int64>;
  List: TList<TPair<string, Int64>>;
begin
  if not Enabled or (Totals.Count = 0) then
    Exit;
  List := TList<TPair<string, Int64>>.Create;
  try
    for P in Totals do
      List.Add(P);
    List.Sort(TComparer<TPair<string, Int64>>.Construct(
      function(const A, B: TPair<string, Int64>): Integer
      begin
        Result := Integer(B.Value - A.Value);
      end));
    for P in List do
      Writeln(ErrOutput, Format('[timing] sum %-34s %8d ms  x%d', [P.Key, P.Value, Counts[P.Key]]));
  finally
    List.Free;
  end;
end;

initialization
  Enabled := GetEnvironmentVariable('DOXYPAS_TIMING') <> '';
  if Enabled then
  begin
    Watch := TStopwatch.StartNew;
    Totals := TDictionary<string, Int64>.Create;
    Counts := TDictionary<string, Integer>.Create;
    Lock := TObject.Create;
  end;

finalization
  Report;

end.
