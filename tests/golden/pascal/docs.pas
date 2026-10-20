unit Docs;

{ plain comment: not documentation }

interface

{** Brief of TColor, block style. }
type
  TColor = (
    clRed,    ///< red (after)
    clGreen,  //!< green (after, doxygen style)
    /// blue (before)
    clBlue
  );

/// Unit-level routine.
/// Second line of the same block.
function Max(A, B: Integer): Integer;

//! Qt-style before
procedure Qt;

(** Pascal-style block comment
    with a second line. *)
procedure Pas;

(*! Another variant *)
procedure Pas2;

// not a doc comment
procedure Plain;

{ not a doc comment either }
procedure Plain2;

type
  /// <summary>XML documentation of a class.</summary>
  /// <remarks>Second line.</remarks>
  TFoo = class
  private
    FValue: Integer; {!< field, after }
  public
    /// Constructor doc.
    constructor Create; ///< trailing doc of Create
    [Weak]
    /// Doc placed between an attribute and its member.
    procedure Bar; virtual;
    /// Property doc.
    property Value: Integer read FValue write FValue;
  end; ///< trailing doc of TFoo

var
  /// Global variable doc.
  GFoo: TFoo;

implementation

/// Implementation-only helper.
procedure Hidden;
begin
end;

end.
