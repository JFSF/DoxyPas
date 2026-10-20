{** \file Docs.pas
    The unit documentation. }
unit Docs;

{** \defgroup core Core
    Core routines. }

{** \mainpage Docs Project
    See \ref TBase and \ref Missing and \ref core. }

interface

type
  /// Base with docs.
  TBase = class
  public
    /// Does the work.
    /// \param A the first value
    /// \param Wrong not an argument
    procedure Work(A: Integer); virtual;
    /// Brief of Other. \ingroup core
    procedure Other;
  end;

  TDerived = class(TBase)
  public
    procedure Work(A: Integer); override;
    /// \copydoc TBase::Other
    procedure Copy1;
    /// \inheritdoc
    procedure Copy2;
    /// \copybrief TBase.Work
    procedure Copy3;
    procedure Nothing;
  end;

implementation

end.
