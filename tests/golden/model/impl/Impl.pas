unit Impl;

interface

type
  /// A class whose methods are implemented below.
  TWorker = class
  public
    /// Declared doc.
    procedure Run(A: Integer); overload;
    procedure Run(const S: string); overload;
    function Calc: Integer;
  end;

/// Interface routine.
function Twice(X: Integer): Integer;

procedure Undocumented;

implementation

type
  TLocal = class
    procedure Hidden;
  end;

/// Implementation doc for Run(Integer).
procedure TWorker.Run(A: Integer);
begin
end;

procedure TWorker.Run(const S: string);
begin
end;

/// Doc only in the implementation.
function TWorker.Calc: Integer;
begin
  Result := 0;
end;

function Twice(X: Integer): Integer;
begin
  Result := X * 2;
end;

procedure Undocumented;
begin
end;

procedure OnlyHere;
begin
end;

procedure TLocal.Hidden;
begin
end;

end.
