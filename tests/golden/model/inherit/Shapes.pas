unit Shapes;

interface

type
  /// Something that can be drawn.
  IDrawable = interface
    ['{11111111-2222-3333-4444-555555555555}']
    /// Draws the object.
    procedure Draw;
  end;

  /// Base class of all shapes.
  TShape = class(TObject)
  private
    FName: string;
  protected
    /// Called before drawing.
    procedure Prepare; virtual;
  public
    /// Creates a shape.
    constructor Create(const AName: string);
    /// Area of the shape.
    function Area: Double; virtual; abstract;
    procedure Move(DX, DY: Integer); overload;
    procedure Move(const P: TObject); overload;
    /// The shape name.
    property Name: string read FName write FName;
  end;

implementation

end.
