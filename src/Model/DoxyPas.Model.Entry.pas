unit DoxyPas.Model.Entry;

{ Parser output: a tree of declarations (Doxygen's Entry). The semantic model (Definition, MemberDef, ...)
  is built from it in a later step (M4). Texts (types, default values) are source text, whitespace-normalised. }

interface

uses
  System.TypInfo,
  System.Generics.Collections;

type
  TEntryKind = (
    ekUnit,       // unit / program / library / package
    ekClass,      // class, record, object, interface, helper ... (see ClassKind)
    ekMethod,     // procedure, function, constructor, destructor, operator
    ekField,      // field of a class/record, or global variable
    ekConstant,   // const / resourcestring
    ekProperty,
    ekTypeAlias,  // type TFoo = <anything that is not a class-like or an enum>
    ekEnum,
    ekEnumValue,
    ekPage,       // \page / \mainpage: Name = id, TypeText = title, Doc = text
    ekGroup);     // \defgroup / ddtogroup: Name = id, TypeText = title, Doc = text

  TClassKind = (ckClass, ckRecord, ckObject, ckInterface, ckDispInterface, ckClassHelper, ckRecordHelper,
    ckTypeHelper);

  TRoutineKind = (rkProcedure, rkFunction, rkConstructor, rkDestructor, rkOperator);

  TProtection = (prPublic, prProtected, prPrivate, prPublished, prStrictPrivate, prStrictProtected);

  TVirtualness = (vtNormal, vtVirtual, vtDynamic, vtOverride);

  TEntryFlag = (
    efClassMember,    // class method / class var / class property ("static" members)
    efStatic,         // "static" directive
    efAbstract,       // abstract method or abstract class
    efFinal,
    efSealed,
    efInline,
    efOverload,
    efReintroduce,
    efForward,        // forward declaration (type TFoo = class;)
    efExternal,
    efDeprecated,
    efPlatform,
    efExperimental,
    efLibrary,
    efDefaultProperty,
    efConstParam,     // (reserved)
    efThreadVar,
    efResourceString,
    efImplementation, // declared in the implementation section
    efTypedConst,
    efInternal,       // \internal
    efHideInitializer,
    efShowInitializer);

  TEntryFlags = set of TEntryFlag;

  TArgument = record
    Name: string;
    TypeText: string;
    DefaultText: string;
    Modifier: string;       // '', const, var, out
    Attributes: string;
  end;

  TTypeParam = record
    Name: string;
    Constraints: string;    // e.g. "class, constructor" or "TFoo"
  end;

  /// <summary>A member group (//@{ ... //@}): the heading (\name) and the text below it; Title is empty when the group has none.</summary>
  TMemberGroup = class
  public
    Title, Doc: string;
  end;

  { The lists of an entry are made when something is added to them: most entries (a field, a method without arguments)
    have none, and nine empty lists per entry were a quarter of the memory of the parse. Reading a list that does not
    exist gives a list that is shared and empty; it must not be changed (it raises): use the Write... function. }
  TEntry = class
  strict private
    FParent: TEntry;
    FChildren: TObjectList<TEntry>;
    FArgs: TList<TArgument>;
    FTypeParams: TList<TTypeParam>;
    FBases: TList<string>;
    FAttributes: TList<string>;
    FDirectives: TList<string>;
    FUsesInterface: TList<string>;
    FUsesImplementation: TList<string>;
    FGroups: TList<string>;
    FOwnedMemberGroups: TObjectList<TMemberGroup>;     // the groups made by this entry (a unit makes those of its members)
    function GetChildren: TObjectList<TEntry>;
    function GetArgs: TList<TArgument>;
    function GetTypeParams: TList<TTypeParam>;
    function GetBases: TList<string>;
    function GetAttributes: TList<string>;
    function GetDirectives: TList<string>;
    function GetUsesInterface: TList<string>;
    function GetUsesImplementation: TList<string>;
    function GetGroups: TList<string>;
  public
    Kind: TEntryKind;
    Name: string;
    ClassKind: TClassKind;
    MethodKind: TRoutineKind;
    Protection: TProtection;
    Virtualness: TVirtualness;
    Flags: TEntryFlags;
    TypeText: string;          // return type, variable/field/property/constant type, alias target
    InitText: string;          // initial value, constant value, enum value expression, property default
    HelperFor: string;         // helpers: the extended type
    CallConv: string;
    DeprecatedMsg: string;
    ReadAccessor: string;      // property
    WriteAccessor: string;
    StoredText: string;
    IndexText: string;
    GuidText: string;          // interfaces
    ExternalText: string;      // text after "external"
    FileName: string;
    Line, Col: Integer;        // start of the declaration
    EndLine, EndCol: Integer;  // position just after the declaration (0 if unknown)
    BodyEndLine, BodyEndCol: Integer;   // the end of the body of a method of the implementation section (0 if unknown)
    Doc: string;               // documentation comment text, markers removed (empty if none)
    DocLine: Integer;
    BodyDoc: string;           // the documentation comments inside the body of the method (HIDE_IN_BODY_DOCS = NO)
    DocIsAfter: Boolean;       // documented by a trailing comment (//<, {!< })
    MemberGroup: TMemberGroup; // the //@{ group the declaration is in (nil: none)
    Brief: string;             // set by DoxyPas.Comments.EntryDocs: brief description (Doxygen markup, HTML)
    Detailed: string;          // detailed description (parsed by DoxyPas.Doc.Parser when needed)
    property Args: TList<TArgument> read GetArgs;          // method / procedural type / property index parameters
    property TypeParams: TList<TTypeParam> read GetTypeParams;
    property Bases: TList<string> read GetBases;           // ancestor and implemented interfaces, in declaration order
    property Attributes: TList<string> read GetAttributes;   // custom attributes, e.g. "MyAttr(1)"
    property Directives: TList<string> read GetDirectives;   // remaining directives as written, e.g. "stdcall", "message 1"
    property UsesInterface: TList<string> read GetUsesInterface;             // units only
    property UsesImplementation: TList<string> read GetUsesImplementation;   // units only
    property Groups: TList<string> read GetGroups;      // \ingroup
    /// <summary>The lists to add to: they are made if they do not exist yet.</summary>
    function WriteArgs: TList<TArgument>;
    function WriteTypeParams: TList<TTypeParam>;
    function WriteBases: TList<string>;
    function WriteAttributes: TList<string>;
    function WriteDirectives: TList<string>;
    function WriteUsesInterface: TList<string>;
    function WriteUsesImplementation: TList<string>;
    function WriteGroups: TList<string>;
    /// <summary>A member group that lives as long as this entry.</summary>
    function NewMemberGroup(const ATitle, ADoc: string): TMemberGroup;
    constructor Create(AKind: TEntryKind; const AName: string);
    destructor Destroy; override;
    function Add(AChild: TEntry): TEntry;
    property Parent: TEntry read FParent;
    property Children: TObjectList<TEntry> read GetChildren;
    function QualifiedName: string;
  end;

function ProtectionName(AValue: TProtection): string;
function EntryKindName(AValue: TEntryKind): string;
/// <summary>Lower-case name of an enum value without its 2-letter prefix (ckClass -> class).</summary>
function EnumText(ATypeInfo: PTypeInfo; AOrdinal: Integer): string;

implementation

uses
  System.SysUtils,
  System.Classes;

type
  // the empty lists that stand for the ones an entry has not made: whatever tries to change them is a mistake
  TFrozenLists = class
    procedure ArgChanged(Sender: TObject; const Item: TArgument; Action: TCollectionNotification);
    procedure TypeParamChanged(Sender: TObject; const Item: TTypeParam; Action: TCollectionNotification);
    procedure TextChanged(Sender: TObject; const Item: string; Action: TCollectionNotification);
    procedure EntryChanged(Sender: TObject; const Item: TEntry; Action: TCollectionNotification);
  end;

var
  Frozen: TFrozenLists;
  EmptyArgs: TList<TArgument>;
  EmptyTypeParams: TList<TTypeParam>;
  EmptyTexts: TList<string>;
  EmptyChildren: TObjectList<TEntry>;

procedure TFrozenLists.ArgChanged(Sender: TObject; const Item: TArgument; Action: TCollectionNotification);
begin
  raise EInvalidOperation.Create('the shared empty list of arguments was changed: use WriteArgs');
end;

procedure TFrozenLists.TypeParamChanged(Sender: TObject; const Item: TTypeParam; Action: TCollectionNotification);
begin
  raise EInvalidOperation.Create('the shared empty list of type parameters was changed: use WriteTypeParams');
end;

procedure TFrozenLists.TextChanged(Sender: TObject; const Item: string; Action: TCollectionNotification);
begin
  raise EInvalidOperation.Create('a shared empty list of an entry was changed: use the Write... function');
end;

procedure TFrozenLists.EntryChanged(Sender: TObject; const Item: TEntry; Action: TCollectionNotification);
begin
  raise EInvalidOperation.Create('the shared empty list of children was changed: use Add');
end;

constructor TEntry.Create(AKind: TEntryKind; const AName: string);
begin
  inherited Create;
  Kind := AKind;
  Name := AName;
end;

destructor TEntry.Destroy;
begin
  FOwnedMemberGroups.Free;
  FGroups.Free;
  FUsesImplementation.Free;
  FUsesInterface.Free;
  FDirectives.Free;
  FAttributes.Free;
  FBases.Free;
  FTypeParams.Free;
  FArgs.Free;
  FChildren.Free;
  inherited;
end;

function TEntry.NewMemberGroup(const ATitle, ADoc: string): TMemberGroup;
begin
  if FOwnedMemberGroups = nil then
    FOwnedMemberGroups := TObjectList<TMemberGroup>.Create(True);
  Result := TMemberGroup.Create;
  Result.Title := ATitle;
  Result.Doc := ADoc;
  FOwnedMemberGroups.Add(Result);
end;

function TEntry.GetChildren: TObjectList<TEntry>;
begin
  if FChildren <> nil then Result := FChildren else Result := EmptyChildren;
end;

function TEntry.GetArgs: TList<TArgument>;
begin
  if FArgs <> nil then Result := FArgs else Result := EmptyArgs;
end;

function TEntry.GetTypeParams: TList<TTypeParam>;
begin
  if FTypeParams <> nil then Result := FTypeParams else Result := EmptyTypeParams;
end;

function TEntry.GetBases: TList<string>;
begin
  if FBases <> nil then Result := FBases else Result := EmptyTexts;
end;

function TEntry.GetAttributes: TList<string>;
begin
  if FAttributes <> nil then Result := FAttributes else Result := EmptyTexts;
end;

function TEntry.GetDirectives: TList<string>;
begin
  if FDirectives <> nil then Result := FDirectives else Result := EmptyTexts;
end;

function TEntry.GetUsesInterface: TList<string>;
begin
  if FUsesInterface <> nil then Result := FUsesInterface else Result := EmptyTexts;
end;

function TEntry.GetUsesImplementation: TList<string>;
begin
  if FUsesImplementation <> nil then Result := FUsesImplementation else Result := EmptyTexts;
end;

function TEntry.GetGroups: TList<string>;
begin
  if FGroups <> nil then Result := FGroups else Result := EmptyTexts;
end;

function TEntry.WriteArgs: TList<TArgument>;
begin
  if FArgs = nil then FArgs := TList<TArgument>.Create;
  Result := FArgs;
end;

function TEntry.WriteTypeParams: TList<TTypeParam>;
begin
  if FTypeParams = nil then FTypeParams := TList<TTypeParam>.Create;
  Result := FTypeParams;
end;

function TEntry.WriteBases: TList<string>;
begin
  if FBases = nil then FBases := TList<string>.Create;
  Result := FBases;
end;

function TEntry.WriteAttributes: TList<string>;
begin
  if FAttributes = nil then FAttributes := TList<string>.Create;
  Result := FAttributes;
end;

function TEntry.WriteDirectives: TList<string>;
begin
  if FDirectives = nil then FDirectives := TList<string>.Create;
  Result := FDirectives;
end;

function TEntry.WriteUsesInterface: TList<string>;
begin
  if FUsesInterface = nil then FUsesInterface := TList<string>.Create;
  Result := FUsesInterface;
end;

function TEntry.WriteUsesImplementation: TList<string>;
begin
  if FUsesImplementation = nil then FUsesImplementation := TList<string>.Create;
  Result := FUsesImplementation;
end;

function TEntry.WriteGroups: TList<string>;
begin
  if FGroups = nil then FGroups := TList<string>.Create;
  Result := FGroups;
end;

function TEntry.Add(AChild: TEntry): TEntry;
begin
  AChild.FParent := Self;
  if FChildren = nil then
    FChildren := TObjectList<TEntry>.Create(True);
  FChildren.Add(AChild);
  Result := AChild;
end;
function TEntry.QualifiedName: string;
begin
  if (FParent <> nil) and (FParent.Kind <> ekUnit) then
    Result := FParent.QualifiedName + '.' + Name
  else
    Result := Name;
end;

function ProtectionName(AValue: TProtection): string;
const
  Names: array[TProtection] of string = ('public', 'protected', 'private', 'published', 'strict private',
    'strict protected');
begin
  Result := Names[AValue];
end;

function EntryKindName(AValue: TEntryKind): string;
begin
  Result := EnumText(TypeInfo(TEntryKind), Ord(AValue));
end;

function EnumText(ATypeInfo: PTypeInfo; AOrdinal: Integer): string;
begin
  Result := LowerCase(Copy(GetEnumName(ATypeInfo, AOrdinal), 3, MaxInt));
end;

initialization
  Frozen := TFrozenLists.Create;
  EmptyArgs := TList<TArgument>.Create;
  EmptyArgs.OnNotify := Frozen.ArgChanged;
  EmptyTypeParams := TList<TTypeParam>.Create;
  EmptyTypeParams.OnNotify := Frozen.TypeParamChanged;
  EmptyTexts := TList<string>.Create;
  EmptyTexts.OnNotify := Frozen.TextChanged;
  EmptyChildren := TObjectList<TEntry>.Create(False);
  EmptyChildren.OnNotify := Frozen.EntryChanged;

finalization
  EmptyChildren.Free;
  EmptyTexts.Free;
  EmptyTypeParams.Free;
  EmptyArgs.Free;
  Frozen.Free;

end.
