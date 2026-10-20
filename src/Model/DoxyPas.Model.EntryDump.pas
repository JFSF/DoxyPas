unit DoxyPas.Model.EntryDump;

{ Plain-text rendering of an Entry tree: used by "doxypas --parse" and by the golden tests. }

interface

uses
  DoxyPas.Model.Entry;

function DumpEntry(AEntry: TEntry): string;

implementation

uses
  System.SysUtils,
  System.TypInfo;

const
  FlagNames: array[TEntryFlag] of string = ('class', 'static', 'abstract', 'final', 'sealed', 'inline', 'overload',
    'reintroduce', 'forward', 'external', 'deprecated', 'platform', 'experimental', 'library', 'default',
    'constparam', 'threadvar', 'resourcestring', 'impl', 'typedconst');

function Join(const AItems: array of string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AItems) do
    if AItems[I] <> '' then
    begin
      if Result <> '' then
        Result := Result + ' ';
      Result := Result + AItems[I];
    end;
end;

function Opt(const APrefix, AValue: string): string;
begin
  if AValue = '' then
    Result := ''
  else
    Result := APrefix + ' ' + AValue;
end;

function ArgsText(AEntry: TEntry): string;
var
  A: TArgument;
  S: string;
begin
  Result := '';
  for A in AEntry.Args do
  begin
    S := Join([A.Modifier, A.Name]);
    if A.TypeText <> '' then
      S := S + ': ' + A.TypeText;
    if A.DefaultText <> '' then
      S := S + ' = ' + A.DefaultText;
    if Result <> '' then
      Result := Result + '; ';
    Result := Result + S;
  end;
end;

function TypeParamsText(AEntry: TEntry): string;
var
  P: TTypeParam;
  S: string;
begin
  Result := '';
  for P in AEntry.TypeParams do
  begin
    S := P.Name;
    if P.Constraints <> '' then
      S := S + ': ' + P.Constraints;
    if Result <> '' then
      Result := Result + '; ';
    Result := Result + S;
  end;
  if Result <> '' then
    Result := '<' + Result + '>';
end;

function FlagsText(AEntry: TEntry): string;
var
  F: TEntryFlag;
  D: string;
begin
  Result := '';
  if AEntry.Virtualness <> vtNormal then
    Result := EnumText(TypeInfo(TVirtualness), Ord(AEntry.Virtualness));
  for F := Low(TEntryFlag) to High(TEntryFlag) do
    if F in AEntry.Flags then
      Result := Join([Result, FlagNames[F]]);
  if AEntry.CallConv <> '' then
    Result := Join([Result, AEntry.CallConv]);
  for D in AEntry.Directives do
    Result := Join([Result, D]);
  if AEntry.DeprecatedMsg <> '' then
    Result := Join([Result, 'deprecated=' + AEntry.DeprecatedMsg]);
  if Result <> '' then
    Result := ' {' + Result + '}';
end;

procedure DumpTo(SB: TStringBuilder; AEntry: TEntry; AIndent: Integer);
var
  Pad, S, A, C: string;
  Child: TEntry;
begin
  Pad := StringOfChar(' ', AIndent * 2);
  for A in AEntry.Attributes do
    SB.Append(Pad).Append('[').Append(A).Append(']').Append(#10);
  S := '';
  case AEntry.Kind of
    ekUnit:
      S := Join([AEntry.TypeText, AEntry.Name]);
    ekClass:
      begin
        S := EnumText(TypeInfo(TClassKind), Ord(AEntry.ClassKind)) + ' ' +
          AEntry.Name + TypeParamsText(AEntry);
        if AEntry.HelperFor <> '' then
          S := S + ' helper for ' + AEntry.HelperFor;
        if AEntry.Bases.Count > 0 then
          S := S + ' : ' + string.Join(', ', AEntry.Bases.ToArray);
        if AEntry.GuidText <> '' then
          S := S + ' guid ' + AEntry.GuidText;
      end;
    ekMethod:
      begin
        S := EnumText(TypeInfo(TRoutineKind), Ord(AEntry.MethodKind)) + ' ' +
          AEntry.Name + TypeParamsText(AEntry) + '(' + ArgsText(AEntry) + ')';
        if AEntry.TypeText <> '' then
          S := S + ': ' + AEntry.TypeText;
      end;
    ekField, ekConstant:
      begin
        S := EntryKindName(AEntry.Kind) + ' ' + AEntry.Name;
        if AEntry.TypeText <> '' then
          S := S + ': ' + AEntry.TypeText;
        if AEntry.InitText <> '' then
          S := S + ' = ' + AEntry.InitText;
      end;
    ekProperty:
      begin
        S := 'property ' + AEntry.Name;
        if AEntry.Args.Count > 0 then
          S := S + '[' + ArgsText(AEntry) + ']';
        if AEntry.TypeText <> '' then
          S := S + ': ' + AEntry.TypeText;
        S := Join([S, Opt('index', AEntry.IndexText), Opt('read', AEntry.ReadAccessor),
          Opt('write', AEntry.WriteAccessor), Opt('stored', AEntry.StoredText), Opt('default', AEntry.InitText)]);
      end;
    ekTypeAlias:
      S := 'type ' + AEntry.Name + TypeParamsText(AEntry) + ' = ' + AEntry.TypeText;
    ekEnum:
      S := 'enum ' + AEntry.Name;
    ekEnumValue:
      begin
        S := 'value ' + AEntry.Name;
        if AEntry.InitText <> '' then
          S := S + ' = ' + AEntry.InitText;
      end;
  end;
  C := '';
  if (AEntry.Kind in [ekMethod, ekField, ekConstant, ekProperty]) and (AEntry.Parent <> nil) and
    (AEntry.Parent.Kind in [ekClass]) then
    C := '[' + ProtectionName(AEntry.Protection) + '] ';
  SB.Append(Pad).Append(C).Append(S).Append(FlagsText(AEntry)).Append(Format('  @%d:%d', [AEntry.Line, AEntry.Col]));
  if AEntry.EndLine > 0 then
    SB.Append(Format('-%d:%d', [AEntry.EndLine, AEntry.EndCol]));
  SB.Append(#10);
  if AEntry.UsesInterface.Count > 0 then
    SB.Append(Pad).Append('  uses interface: ').Append(string.Join(', ', AEntry.UsesInterface.ToArray)).Append(#10);
  if AEntry.UsesImplementation.Count > 0 then
    SB.Append(Pad).Append('  uses implementation: ').Append(string.Join(', ', AEntry.UsesImplementation.ToArray))
      .Append(#10);
  if AEntry.Doc <> '' then
  begin
    SB.Append(Pad).Append('  doc');
    if AEntry.DocIsAfter then
      SB.Append('<');
    SB.Append(': ').Append(AEntry.Doc.Replace(#10, ' | ')).Append(#10);
  end;
  for Child in AEntry.Children do
    DumpTo(SB, Child, AIndent + 1);
end;

function DumpEntry(AEntry: TEntry): string;
var
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    DumpTo(SB, AEntry, 0);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

end.
