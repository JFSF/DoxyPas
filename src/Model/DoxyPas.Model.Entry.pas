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

  TEntry = class
  strict private
    FParent: TEntry;
    FChildren: TObjectList<TEntry>;
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
    Args: TList<TArgument>;    // method / procedural type / property index parameters
    TypeParams: TList<TTypeParam>;
    Bases: TList<string>;      // ancestor and implemented interfaces, in declaration order
    HelperFor: string;         // helpers: the extended type
    Attributes: TList<string>; // custom attributes, e.g. "MyAttr(1)"
    Directives: TList<string>; // remaining directives as written, e.g. "stdcall", "message 1"
    CallConv: string;
    DeprecatedMsg: string;
    ReadAccessor: string;      // property
    WriteAccessor: string;
    StoredText: string;
    IndexText: string;
    GuidText: string;          // interfaces
    ExternalText: string;      // text after "external"
    UsesInterface: TList<string>;       // units only
    UsesImplementation: TList<string>;  // units only
    FileName: string;
    Line, Col: Integer;        // start of the declaration
    EndLine, EndCol: Integer;  // position just after the declaration (0 if unknown)
    Doc: string;               // documentation comment text, markers removed (empty if none)
    DocLine: Integer;
    DocIsAfter: Boolean;       // documented by a trailing comment (//<, {!< })
    Brief: string;             // set by DoxyPas.Comments.EntryDocs: brief description (Doxygen markup, HTML)
    Detailed: string;          // detailed description (parsed by DoxyPas.Doc.Parser when needed)
    Groups: TList<string>;     // \ingroup
    constructor Create(AKind: TEntryKind; const AName: string);
    destructor Destroy; override;
    function Add(AChild: TEntry): TEntry;
    property Parent: TEntry read FParent;
    property Children: TObjectList<TEntry> read FChildren;
    function QualifiedName: string;
  end;

function ProtectionName(AValue: TProtection): string;
function EntryKindName(AValue: TEntryKind): string;
/// <summary>Lower-case name of an enum value without its 2-letter prefix (ckClass -> class).</summary>
function EnumText(ATypeInfo: PTypeInfo; AOrdinal: Integer): string;

implementation

uses
  System.SysUtils;

constructor TEntry.Create(AKind: TEntryKind; const AName: string);
begin
  inherited Create;
  Kind := AKind;
  Name := AName;
  FChildren := TObjectList<TEntry>.Create(True);
  Args := TList<TArgument>.Create;
  TypeParams := TList<TTypeParam>.Create;
  Bases := TList<string>.Create;
  Attributes := TList<string>.Create;
  Directives := TList<string>.Create;
  UsesInterface := TList<string>.Create;
  UsesImplementation := TList<string>.Create;
  Groups := TList<string>.Create;
end;

destructor TEntry.Destroy;
begin
  Groups.Free;
  UsesImplementation.Free;
  UsesInterface.Free;
  Directives.Free;
  Attributes.Free;
  Bases.Free;
  TypeParams.Free;
  Args.Free;
  FChildren.Free;
  inherited;
end;

function TEntry.Add(AChild: TEntry): TEntry;
begin
  AChild.FParent := Self;
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

end.
