{** \file Shapes.pas
    Base types of the geometry library: the shape hierarchy and the drawing interface. }
unit Shapes;

{** \defgroup geometry Geometry
    Shapes and measures. }

interface

uses
  System.SysUtils;

type
  /// Something that can paint itself.
  IDrawable = interface
    ['{6F1B3C52-8A0E-4C57-9D55-3B7B0C2D1A10}']
    /// Paints the object on the canvas.
    /// \param ACanvasName name of the canvas to paint on
    procedure Draw(const ACanvasName: string);
  end;

  /// The kinds of shape that the library knows.
  TShapeKind = (skCircle, skRectangle, skTriangle);

  /// <summary>Base class of all shapes.</summary>
  /// <remarks>Descendants override <see cref="Area"/> and <see cref="Perimeter"/>.</remarks>
  /// \ingroup geometry
  TShape = class(TInterfacedObject, IDrawable)
  strict private
    FName: string;
  protected
    /// Called when the name changes.
    procedure NameChanged; virtual;
  public
    /// Creates a shape with a name.
    /// \param AName the name shown in the lists
    constructor Create(const AName: string);
    /// Area of the shape.
    /// \return the area in square units
    function Area: Double; virtual; abstract;
    /// Perimeter of the shape.
    function Perimeter: Double; virtual; abstract;
    procedure Draw(const ACanvasName: string);
    /// The name of the shape.
    property Name: string read FName write FName;
  end;

implementation

constructor TShape.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

procedure TShape.NameChanged;
begin
end;

procedure TShape.Draw(const ACanvasName: string);
begin
  Writeln(ACanvasName, ': ', FName);
end;

end.
