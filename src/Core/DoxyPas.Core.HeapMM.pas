unit DoxyPas.Core.HeapMM;

{ The memory manager of the Windows process heap instead of Delphi's. The parse allocates a very large number of small
  blocks from every thread, and Delphi's memory manager serialises them: with 16 threads the parse took as long as with
  one (about 20 s for the RTL, VCL and FMX). The Windows heap lets the threads allocate side by side, and is faster
  with a single thread too. This unit has to be the first of the program, before anything allocates a block (a block
  that the old manager made must not be freed by the new one). Set DOXYPAS_DEFAULT_MM to keep Delphi's. On Linux the
  RTL already uses the C library's allocator and this unit does nothing. }

interface

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows;

var
  Heap: THandle;
  Manager: TMemoryManagerEx;

function HeapGetMem(ASize: NativeInt): Pointer;
begin
  Result := HeapAlloc(Heap, 0, ASize);
end;

function HeapFreeMem(P: Pointer): Integer;
begin
  if HeapFree(Heap, 0, P) then
    Result := 0
  else
    Result := 1;
end;

function HeapReallocMem(P: Pointer; ASize: NativeInt): Pointer;
begin
  if P = nil then
    Result := HeapAlloc(Heap, 0, ASize)
  else
    Result := HeapReAlloc(Heap, 0, P, ASize);
end;

function HeapAllocMem(ASize: NativeInt): Pointer;
begin
  Result := HeapAlloc(Heap, HEAP_ZERO_MEMORY, ASize);
end;

function HeapNoLeakCheck(P: Pointer): Boolean;
begin
  Result := False;
end;

var
  Probe: array[0..0] of WideChar;

initialization
  // read without allocating: the answer is the length of the value, 0 when there is none
  if GetEnvironmentVariableW('DOXYPAS_DEFAULT_MM', @Probe[0], 1) = 0 then
  begin
    Heap := GetProcessHeap;
    Manager.GetMem := HeapGetMem;
    Manager.FreeMem := HeapFreeMem;
    Manager.ReallocMem := HeapReallocMem;
    Manager.AllocMem := HeapAllocMem;
    Manager.RegisterExpectedMemoryLeak := HeapNoLeakCheck;
    Manager.UnregisterExpectedMemoryLeak := HeapNoLeakCheck;
    SetMemoryManager(Manager);
  end;
{$ENDIF}

end.
