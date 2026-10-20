unit Modern;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

interface

uses
  System.SysUtils, System.Generics.Collections;

type
  /// <summary>Attribute with doc.</summary>
  [AttributeUsage(1)]
  TMyAttr = class(TCustomAttribute)
  end;

  TGuid1 = type string;

  IShape = interface
    ['{11111111-2222-3333-4444-555555555555}']
    /// <summary>Area.</summary>
    function Area: Double;
    property Name: string read GetName write SetName;
  end;

  TPoint3<T: record> = record
    X, Y, Z: T;
    class operator Add(const A, B: TPoint3<T>): TPoint3<T>;
    class operator Implicit(const A: Integer): TPoint3<T>;
  end;

  TIntHelper = record helper for Integer
    function Twice: Integer; inline;
  end;

  TBox<T: class, constructor> = class(TObject, IShape)
  strict private
    FItems: TList<T>;
    class var FCount: Integer;
  private
    type TInner = record A: Integer; end;
  protected
    function GetName: string; virtual; abstract;
  public
    //! Brief doc
    constructor Create; overload;
    destructor Destroy; override;
    [MyAttr]
    procedure Run(const AProc: TProc<Integer>; out AResult: string); stdcall;
    class function Make<U>(const A: U): TBox<T>; static;
    property Items[Index: Integer]: T read GetItem write SetItem; default;
  published
    property OnDone: TNotifyEvent read FOnDone write FOnDone;
  end;

  TRef = reference to function(A: Integer): Integer;

const
  Pi2 = 6.28;
  Names: array[0..1] of string = ('a', 'b');

var
  GCount: Integer = 0;

implementation

procedure Test;
begin
  var X := 10;
  var Y: Integer := X * 2;
  for var I := 0 to 9 do
    Inc(X, I);
  for var S in ['a', 'b'] do
    Writeln(S);
  const K = 5;
  var F: TRef := function(A: Integer): Integer begin Result := A + K; end;
  TThread.Queue(nil, procedure begin Writeln('x'); end);
  if X is not Integer then Exit;
end;

end.
