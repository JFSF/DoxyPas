{** \file Circles.pas
    Round shapes. }
unit Circles;

interface

uses
  Shapes;

type
  /// A circle defined by its radius.
  /// \ingroup geometry
  TCircle = class(TShape)
  private
    FRadius: Double;
  public
    /// Creates a circle.
    /// \param ARadius the radius, it must be greater than zero
    constructor Create(ARadius: Double);
    function Area: Double; override;
    function Perimeter: Double; override;
    /// The radius of the circle.
    property Radius: Double read FRadius write FRadius;
  end;

  /// A circle of radius one.
  TUnitCircle = class(TCircle)
  public
    /// Creates the circle with radius one.
    constructor Create;
  end;

implementation

constructor TCircle.Create(ARadius: Double);
begin
  inherited Create('Circle');
  FRadius := ARadius;
end;

function TCircle.Area: Double;
begin
  Result := Pi * Sqr(FRadius);
end;

function TCircle.Perimeter: Double;
begin
  Result := 2 * Pi * FRadius;
end;

constructor TUnitCircle.Create;
begin
  inherited Create(1);
end;

end.
