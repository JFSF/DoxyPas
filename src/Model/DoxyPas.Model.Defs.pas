unit DoxyPas.Model.Defs;

{ Semantic model built from the parser's Entry trees (Doxygen's Definition hierarchy):
  units, classes (class/record/interface/...), members, groups and pages, with resolved relations. }

interface

uses
  System.Generics.Collections,
  DoxyPas.Model.Entry;

type
  TMemberKind = (memFunction, memVariable, memProperty, memTypedef, memEnumeration, memEnumValue, memConstant);

  TDefinition = class;
  TScopeDef = class;
  TUnitDef = class;
  TClassDef = class;
  TMemberDef = class;
  TGroupDef = class;

  { The lists of a definition are made when something is added to them (like the ones of TEntry): reading one that does
    not exist gives a shared empty list that must not be changed (it raises); use the Write... function to add. }
  TDefinition = class
  strict private
    FScope: TScopeDef;
    FGroups: TList<TGroupDef>;
    function GetGroups: TList<TGroupDef>;
  public
    Name: string;
    Entry: TEntry;              // the declaration this definition was built from (not owned)
    Brief: string;              // after merging implementation docs, \copydoc and inheritance
    Detailed: string;
    DocInherited: Boolean;      // the documentation was inherited from an overridden member
    DiskName: string;           // output file name without extension (compounds) or anchor (members)
    ImplementationOnly: Boolean; // declared in the implementation section only
    constructor Create(const AName: string; AEntry: TEntry);
    destructor Destroy; override;
    property Scope: TScopeDef read FScope write FScope;
    property Groups: TList<TGroupDef> read GetGroups;
    function WriteGroups: TList<TGroupDef>;
    function QualifiedName: string; virtual;
    function IsDocumented: Boolean;
    function Protection: TProtection;
    function OwnerUnit: TUnitDef;
  end;

  /// <summary>A definition that contains other definitions and can be searched by name.</summary>
  TScopeDef = class(TDefinition)
  strict private
    FSymbols: TObjectDictionary<string, TList<TDefinition>>;
  public
    /// <summary>Counts the symbols added to any scope: an index over many scopes is out of date when it changes.</summary>
    class var SymbolVersion: Integer;
    constructor Create(const AName: string; AEntry: TEntry);
    destructor Destroy; override;
    procedure AddSymbol(ADef: TDefinition);
    /// <summary>Definitions with this (case-insensitive) name declared directly in this scope.</summary>
    function Find(const AName: string): TList<TDefinition>;
    /// <summary>Adds the first symbol of every name to ATarget (names it already has are kept).</summary>
    procedure FirstSymbolsInto(ATarget: TDictionary<string, TDefinition>);
  end;

  TBaseRef = record
    Text: string;               // as written, e.g. "TBase<T>"
    ClassDef: TClassDef;        // nil if not part of the project
    IsInterface: Boolean;
  end;

  TInheritedMember = record
    Member: TMemberDef;
    From: TClassDef;            // the class that declares it (the class itself for own members)
  end;

  TUnitDef = class(TScopeDef)
  public
    UnitKind: string;           // unit, program, library, package
    UsesInterfaceNames: TList<string>;
    UsesImplementationNames: TList<string>;
    UsesInterface: TList<TUnitDef>;       // resolved (units that are part of the project)
    UsesImplementation: TList<TUnitDef>;
    UsedBy: TList<TUnitDef>;
    Members: TList<TMemberDef>;           // routines, variables, constants, types, enumerations
    Classes: TList<TClassDef>;
    FileName: string;
    constructor Create(const AName: string; AEntry: TEntry);
    destructor Destroy; override;
  end;

  TClassDef = class(TScopeDef)
  public
    ClassKind: TClassKind;
    Bases: TList<TBaseRef>;
    Derived: TList<TClassDef>;
    Members: TList<TMemberDef>;           // declared in this class, in source order
    NestedClasses: TList<TClassDef>;
    AllMembers: TList<TInheritedMember>;  // own + inherited, hidden members removed
    constructor Create(const AName: string; AEntry: TEntry);
    destructor Destroy; override;
    function QualifiedName: string; override;
  end;

  TMemberDef = class(TDefinition)
  strict private
    FReimplementedBy: TList<TMemberDef>;
    FEnumValues: TList<TMemberDef>;
    function GetReimplementedBy: TList<TMemberDef>;
    function GetEnumValues: TList<TMemberDef>;
  public
    Kind: TMemberKind;
    Impl: TEntry;                         // the implementation (routines): source location and docs
    Reimplements: TMemberDef;             // overridden / implemented member
    ReadMember: TMemberDef;               // properties
    WriteMember: TMemberDef;
    EnumOwner: TMemberDef;                // enum values
    property ReimplementedBy: TList<TMemberDef> read GetReimplementedBy;
    property EnumValues: TList<TMemberDef> read GetEnumValues;        // enumerations
    function WriteReimplementedBy: TList<TMemberDef>;
    function WriteEnumValues: TList<TMemberDef>;
    constructor Create(const AName: string; AEntry: TEntry; AKind: TMemberKind);
    destructor Destroy; override;
    function QualifiedName: string; override;
    /// <summary>Signature text: "(A: Integer; B: string): Boolean".</summary>
    function Signature: string;
  end;

  TGroupDef = class(TDefinition)
  public
    Title: string;
    Members: TList<TDefinition>;
    Subgroups: TList<TGroupDef>;
    Parent: TGroupDef;
    constructor Create(const AName: string; AEntry: TEntry);
    destructor Destroy; override;
  end;

  TPageDef = class(TDefinition)
  public
    Title: string;
    IsMainPage: Boolean;
  end;

function MemberKindName(AKind: TMemberKind): string;

implementation

uses
  System.SysUtils,
  System.Classes;

type
  TFrozenLists = class
    procedure GroupChanged(Sender: TObject; const Item: TGroupDef; Action: TCollectionNotification);
    procedure MemberChanged(Sender: TObject; const Item: TMemberDef; Action: TCollectionNotification);
  end;

var
  Frozen: TFrozenLists;
  EmptyGroups: TList<TGroupDef>;
  EmptyMembers: TList<TMemberDef>;

procedure TFrozenLists.GroupChanged(Sender: TObject; const Item: TGroupDef; Action: TCollectionNotification);
begin
  raise EInvalidOperation.Create('the shared empty list of groups was changed: use WriteGroups');
end;

procedure TFrozenLists.MemberChanged(Sender: TObject; const Item: TMemberDef; Action: TCollectionNotification);
begin
  raise EInvalidOperation.Create('a shared empty list of members was changed: use the Write... function');
end;

function MemberKindName(AKind: TMemberKind): string;
const
  Names: array[TMemberKind] of string = ('function', 'variable', 'property', 'typedef', 'enumeration', 'enumvalue',
    'constant');
begin
  Result := Names[AKind];
end;

{ TDefinition }

constructor TDefinition.Create(const AName: string; AEntry: TEntry);
begin
  inherited Create;
  Name := AName;
  Entry := AEntry;
  if AEntry <> nil then
  begin
    Brief := AEntry.Brief;
    Detailed := AEntry.Detailed;
  end;
end;

destructor TDefinition.Destroy;
begin
  FGroups.Free;
  inherited;
end;

function TDefinition.GetGroups: TList<TGroupDef>;
begin
  if FGroups <> nil then Result := FGroups else Result := EmptyGroups;
end;

function TDefinition.WriteGroups: TList<TGroupDef>;
begin
  if FGroups = nil then FGroups := TList<TGroupDef>.Create;
  Result := FGroups;
end;

function TDefinition.QualifiedName: string;
begin
  if (FScope <> nil) and (FScope.Name <> '') then
    Result := FScope.QualifiedName + '.' + Name
  else
    Result := Name;
end;

function TDefinition.IsDocumented: Boolean;
begin
  Result := (Brief <> '') or (Detailed <> '');
end;

function TDefinition.Protection: TProtection;
begin
  if Entry <> nil then
    Result := Entry.Protection
  else
    Result := prPublic;
end;

function TDefinition.OwnerUnit: TUnitDef;
var
  D: TDefinition;
begin
  D := Self;
  while (D <> nil) and not (D is TUnitDef) do
    D := D.Scope;
  Result := TUnitDef(D);
end;

{ TScopeDef }

constructor TScopeDef.Create(const AName: string; AEntry: TEntry);
begin
  inherited;
  FSymbols := TObjectDictionary<string, TList<TDefinition>>.Create([doOwnsValues]);
end;

destructor TScopeDef.Destroy;
begin
  FSymbols.Free;
  inherited;
end;

procedure TScopeDef.AddSymbol(ADef: TDefinition);
var
  L: TList<TDefinition>;
  Key: string;
begin
  Inc(SymbolVersion);
  Key := LowerCase(ADef.Name);
  if not FSymbols.TryGetValue(Key, L) then
  begin
    L := TList<TDefinition>.Create;
    FSymbols.Add(Key, L);
  end;
  L.Add(ADef);
end;

function TScopeDef.Find(const AName: string): TList<TDefinition>;
begin
  if not FSymbols.TryGetValue(LowerCase(AName), Result) then
    Result := nil;
end;

procedure TScopeDef.FirstSymbolsInto(ATarget: TDictionary<string, TDefinition>);
var
  P: TPair<string, TList<TDefinition>>;
begin
  for P in FSymbols do
    if (P.Value.Count > 0) and not ATarget.ContainsKey(P.Key) then
      ATarget.Add(P.Key, P.Value[0]);
end;

{ TUnitDef }

constructor TUnitDef.Create(const AName: string; AEntry: TEntry);
begin
  inherited;
  UsesInterfaceNames := TList<string>.Create;
  UsesImplementationNames := TList<string>.Create;
  UsesInterface := TList<TUnitDef>.Create;
  UsesImplementation := TList<TUnitDef>.Create;
  UsedBy := TList<TUnitDef>.Create;
  Members := TList<TMemberDef>.Create;
  Classes := TList<TClassDef>.Create;
end;

destructor TUnitDef.Destroy;
begin
  Classes.Free;
  Members.Free;
  UsedBy.Free;
  UsesImplementation.Free;
  UsesInterface.Free;
  UsesImplementationNames.Free;
  UsesInterfaceNames.Free;
  inherited;
end;

{ TClassDef }

constructor TClassDef.Create(const AName: string; AEntry: TEntry);
begin
  inherited;
  Bases := TList<TBaseRef>.Create;
  Derived := TList<TClassDef>.Create;
  Members := TList<TMemberDef>.Create;
  NestedClasses := TList<TClassDef>.Create;
  AllMembers := TList<TInheritedMember>.Create;
end;

destructor TClassDef.Destroy;
begin
  AllMembers.Free;
  NestedClasses.Free;
  Members.Free;
  Derived.Free;
  Bases.Free;
  inherited;
end;

function TClassDef.QualifiedName: string;
begin
  Result := inherited QualifiedName;
end;

{ TMemberDef }

constructor TMemberDef.Create(const AName: string; AEntry: TEntry; AKind: TMemberKind);
begin
  inherited Create(AName, AEntry);
  Kind := AKind;
end;

destructor TMemberDef.Destroy;
begin
  FEnumValues.Free;
  FReimplementedBy.Free;
  inherited;
end;

function TMemberDef.GetReimplementedBy: TList<TMemberDef>;
begin
  if FReimplementedBy <> nil then Result := FReimplementedBy else Result := EmptyMembers;
end;

function TMemberDef.GetEnumValues: TList<TMemberDef>;
begin
  if FEnumValues <> nil then Result := FEnumValues else Result := EmptyMembers;
end;

function TMemberDef.WriteReimplementedBy: TList<TMemberDef>;
begin
  if FReimplementedBy = nil then FReimplementedBy := TList<TMemberDef>.Create;
  Result := FReimplementedBy;
end;

function TMemberDef.WriteEnumValues: TList<TMemberDef>;
begin
  if FEnumValues = nil then FEnumValues := TList<TMemberDef>.Create;
  Result := FEnumValues;
end;

function TMemberDef.QualifiedName: string;
begin
  Result := inherited QualifiedName;
end;

function TMemberDef.Signature: string;
var
  A: TArgument;
  S: string;
begin
  Result := '';
  if Entry = nil then
    Exit;
  for A in Entry.Args do
  begin
    S := A.Name;
    if A.Modifier <> '' then
      S := A.Modifier + ' ' + S;
    if A.TypeText <> '' then
      S := S + ': ' + A.TypeText;
    if Result <> '' then
      Result := Result + '; ';
    Result := Result + S;
  end;
  if (Entry.Args.Count > 0) or (Entry.Kind = ekMethod) then
    Result := '(' + Result + ')';
  if Entry.TypeText <> '' then
    Result := Result + ': ' + Entry.TypeText;
end;

{ TGroupDef }

constructor TGroupDef.Create(const AName: string; AEntry: TEntry);
begin
  inherited;
  Members := TList<TDefinition>.Create;
  Subgroups := TList<TGroupDef>.Create;
end;

destructor TGroupDef.Destroy;
begin
  Subgroups.Free;
  Members.Free;
  inherited;
end;

initialization
  Frozen := TFrozenLists.Create;
  EmptyGroups := TList<TGroupDef>.Create;
  EmptyGroups.OnNotify := Frozen.GroupChanged;
  EmptyMembers := TList<TMemberDef>.Create;
  EmptyMembers.OnNotify := Frozen.MemberChanged;

finalization
  EmptyMembers.Free;
  EmptyGroups.Free;
  Frozen.Free;

end.
