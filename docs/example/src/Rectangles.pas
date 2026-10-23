{** \file Rectangles.pas
    Shapes with straight sides. }
unit Rectangles;

interface

uses
  Shapes, Circles;

const
  /// Largest side accepted by TRectangle.
  MaxSide = 1000;

type
  /// A rectangle defined by its sides.
  /// \ingroup geometry
  TRectangle = class(TShape)
  private
    FWidth, FHeight: Double;
  public
    /// Creates a rectangle.
    constructor Create(AWidth, AHeight: Double);
    function Area: Double; override;
    function Perimeter: Double; override;
    /// Gives the smallest circle that contains the rectangle.
    function Bounding: TCircle;
    /// Width of the rectangle.
    property Width: Double read FWidth write FWidth;
    /// Height of the rectangle.
    property Height: Double read FHeight write FHeight;
  end;

  /// A rectangle with equal sides.
  TSquare = class(TRectangle)
  public
    /// \copydoc TRectangle::Create
    constructor Create(ASide: Double);
  end;

/// Sums the areas of several shapes.
/// \param AShapes the shapes
/// \return the total area
/// \sa TShape::Area
function TotalArea(const AShapes: array of TShape): Double;

implementation

constructor TRectangle.Create(AWidth, AHeight: Double);
begin
  inherited Create('Rectangle');
  FWidth := AWidth;
  FHeight := AHeight;
end;

function TRectangle.Area: Double;
begin
  Result := FWidth * FHeight;
end;

function TRectangle.Perimeter: Double;
begin
  Result := 2 * (FWidth + FHeight);
end;

function TRectangle.Bounding: TCircle;
begin
  Result := TCircle.Create(Sqrt(Sqr(FWidth) + Sqr(FHeight)) / 2);
end;

constructor TSquare.Create(ASide: Double);
begin
  inherited Create(ASide, ASide);
end;

function TotalArea(const AShapes: array of TShape): Double;
var
  S: TShape;
begin
  Result := 0;
  for S in AShapes do
    Result := Result + S.Area;
end;

end.
