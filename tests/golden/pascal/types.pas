unit Types1;

interface

uses
  SysUtils;

const
  Max = 10;
  Typed: Integer = 5;
  Names: array[0..1] of string = ('a', 'b');

resourcestring
  SHello = 'Hello';

type
  TColor = (clRed, clGreen = 5, clBlue);
  TRange = 1..10;
  TColors = set of TColor;
  TArr = array[0..9] of Integer;
  TDyn = array of string;
  PInt = ^Integer;
  TProcA = procedure(A: Integer; const B: string);
  TFuncB = function(A: Integer): Boolean of object;
  TRefC = reference to procedure(X: Integer);
  TFile = file of Byte;
  TClassRef = class of TObject;
  TFwd = class;
  TMyRec = record
    A: Integer;
    B: array[0..3] of Char;
  end;
  TObj = class(TInterfacedObject, IInterface)
  private
    FA: Integer; FB: string;
    function GetA: Integer;
  public
    constructor Create(const AName: string = 'x'; AValue: Integer = 3 + 4);
    function Calc(A, B: Integer; var C: Double): Integer; overload; virtual;
    function Calc(A: Double): Integer; overload;
    procedure Done; reintroduce; deprecated 'use X';
    class procedure Stat; static;
    procedure Msg(var M: TMessage); message 1;
    property A: Integer read GetA write FA default 0;
    property Items[I: Integer]: string read GetItem; default;
    property Name: string index 3 read GetS;
  end;

var
  GVar: Integer;
  GInit: Integer = 5;

threadvar
  TV: Integer;

function Free1(A: Integer): Integer; stdcall;
procedure Ext; external 'lib.dll' name 'Ext';
function Inl: Integer; inline;

implementation

function Free1(A: Integer): Integer; stdcall;
begin
end;

procedure Ext; external 'lib.dll' name 'Ext';

function Inl: Integer; inline;
begin
end;

function TObj.GetA: Integer;
begin
end;

end.
