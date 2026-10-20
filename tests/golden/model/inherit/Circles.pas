unit Circles;

interface

uses
  Shapes;

type
  /// A circle.
  TCircle = class(TShape, IDrawable)
  private
    FRadius: Double;
    function GetDiameter: Double;
  public
    constructor Create(const AName: string; ARadius: Double);
    function Area: Double; override;
    procedure Draw;
    procedure Move(DX, DY: Integer); reintroduce;
    property Radius: Double read FRadius write FRadius;
    /// Twice the radius.
    property Diameter: Double read GetDiameter;
  end;

  TUnitCircle = class(TCircle)
  public
    function Area: Double; override;
  end;

implementation

end.
