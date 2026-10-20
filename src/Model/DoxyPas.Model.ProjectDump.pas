unit DoxyPas.Model.ProjectDump;

{ Plain-text rendering of the semantic model: "doxypas --model" and the golden tests. }

interface

uses
  DoxyPas.Model.Project;

function DumpProject(AProject: TProject; AWithWarnings: Boolean = True): string;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Character,
  System.Generics.Collections,
  System.Generics.Defaults,
  DoxyPas.Model.Entry,
  DoxyPas.Model.Defs;

function DocFlags(ADef: TDefinition): string;
begin
  Result := '';
  if ADef.Brief <> '' then
    Result := Result + ' brief';
  if ADef.Detailed <> '' then
    Result := Result + ' detailed';
  if ADef.DocInherited then
    Result := Result + ' inherited';
  if ADef.ImplementationOnly then
    Result := Result + ' impl-only';
  if Result <> '' then
    Result := ' {' + Trim(Result) + '}';
end;

{ Warnings start with "path:line: ": keep only the file name so that dumps do not depend on the machine. }
function StripPath(const S: string): string;
var
  P: Integer;
begin
  P := Pos(':', S, 3);
  while (P > 0) and ((P = Length(S)) or not S[P + 1].IsDigit) do
    P := Pos(':', S, P + 1);
  if P > 0 then
    Result := ExtractFileName(Copy(S, 1, P - 1)) + Copy(S, P, MaxInt)
  else
    Result := S;
end;

function Text1(const S: string): string;
begin
  Result := S.Replace(#10, ' | ');
end;

procedure DumpMember(SB: TStringBuilder; AProject: TProject; M: TMemberDef; const APad: string);
var
  S: string;
  V: TMemberDef;
begin
  S := APad + MemberKindName(M.Kind) + ' ' + M.Name + M.Signature;
  if M.Kind = memTypedef then
    S := S + ' = ' + M.Entry.TypeText
  else if (M.Kind = memConstant) and (M.Entry.InitText <> '') then
    S := S + ' = ' + M.Entry.InitText;
  S := S + ' [' + ProtectionName(M.Protection) + ']' + DocFlags(M);
  if not AProject.IsVisible(M) then
    S := S + ' hidden';
  SB.Append(S).Append(#10);
  if M.Impl <> nil then
    SB.Append(APad).Append('  impl: ').Append(ExtractFileName(M.Impl.FileName)).Append(':').Append(M.Impl.Line).Append(#10);
  if M.Reimplements <> nil then
    SB.Append(APad).Append('  reimplements: ').Append(M.Reimplements.QualifiedName).Append(#10);
  if M.ReimplementedBy.Count > 0 then
  begin
    SB.Append(APad).Append('  reimplemented by: ');
    for V in M.ReimplementedBy do
      SB.Append(V.QualifiedName).Append(' ');
    SB.Length := SB.Length - 1;
    SB.Append(#10);
  end;
  if M.ReadMember <> nil then
    SB.Append(APad).Append('  read: ').Append(M.ReadMember.Name).Append(#10);
  if M.WriteMember <> nil then
    SB.Append(APad).Append('  write: ').Append(M.WriteMember.Name).Append(#10);
  for V in M.EnumValues do
    SB.Append(APad).Append('  value ').Append(V.Name).Append(#10);
  if M.Brief <> '' then
    SB.Append(APad).Append('  brief: ').Append(Text1(M.Brief)).Append(#10);
  if M.Detailed <> '' then
    SB.Append(APad).Append('  detailed: ').Append(Text1(M.Detailed)).Append(#10);
end;

procedure DumpClass(SB: TStringBuilder; AProject: TProject; C: TClassDef; AIndent: Integer);
var
  Pad: string;
  B: TBaseRef;
  D: TClassDef;
  M: TMemberDef;
  IM: TInheritedMember;
  First: Boolean;
begin
  Pad := StringOfChar(' ', AIndent * 2);
  SB.Append(Pad).Append('class ').Append(C.Name).Append(' (').Append(EnumText(TypeInfo(TClassKind), Ord(C.ClassKind)))
    .Append(')');
  if C.Bases.Count > 0 then
  begin
    SB.Append(' : ');
    First := True;
    for B in C.Bases do
    begin
      if not First then
        SB.Append(', ');
      First := False;
      SB.Append(B.Text);
      if B.ClassDef = nil then
        SB.Append('*')
      else if B.IsInterface then
        SB.Append('(i)');
    end;
  end;
  SB.Append(DocFlags(C));
  if not AProject.IsVisible(C) then
    SB.Append(' hidden');
  SB.Append(' -> ').Append(C.DiskName).Append(#10);
  if C.Derived.Count > 0 then
  begin
    SB.Append(Pad).Append('  derived: ');
    for D in C.Derived do
      SB.Append(D.QualifiedName).Append(' ');
    SB.Length := SB.Length - 1;
    SB.Append(#10);
  end;
  if C.Brief <> '' then
    SB.Append(Pad).Append('  brief: ').Append(Text1(C.Brief)).Append(#10);
  if C.Detailed <> '' then
    SB.Append(Pad).Append('  detailed: ').Append(Text1(C.Detailed)).Append(#10);
  for M in C.Members do
    if M.Kind <> memEnumValue then
      DumpMember(SB, AProject, M, Pad + '  ');
  for D in C.NestedClasses do
    DumpClass(SB, AProject, D, AIndent + 1);
  if C.AllMembers.Count > C.Members.Count then
  begin
    SB.Append(Pad).Append('  all members:');
    for IM in C.AllMembers do
      SB.Append(' ').Append(IM.From.Name).Append('.').Append(IM.Member.Name);
    SB.Append(#10);
  end;
end;

function DumpProject(AProject: TProject; AWithWarnings: Boolean): string;
var
  SB: TStringBuilder;
  Units: TList<TUnitDef>;
  U, T: TUnitDef;
  C: TClassDef;
  M: TMemberDef;
  G: TGroupDef;
  P: TPageDef;
  D: TDefinition;
  S: string;
begin
  SB := TStringBuilder.Create;
  Units := TList<TUnitDef>.Create(AProject.Units);
  try
    Units.Sort(TComparer<TUnitDef>.Construct(
      function(const A, B: TUnitDef): Integer
      begin
        Result := CompareText(A.Name, B.Name);
      end));
    for U in Units do
    begin
      SB.Append(U.UnitKind).Append(' ').Append(U.Name).Append(DocFlags(U));
      if not AProject.IsVisible(U) then
        SB.Append(' hidden');
      SB.Append(' -> ').Append(U.DiskName).Append(#10);
      if U.UsesInterfaceNames.Count > 0 then
      begin
        S := '';
        for T in U.UsesInterface do
          S := S + ' ' + T.Name;
        SB.Append('  uses (project):').Append(S).Append(#10);
      end;
      if U.UsedBy.Count > 0 then
      begin
        S := '';
        for T in U.UsedBy do
          S := S + ' ' + T.Name;
        SB.Append('  used by:').Append(S).Append(#10);
      end;
      if U.Brief <> '' then
        SB.Append('  brief: ').Append(Text1(U.Brief)).Append(#10);
      if U.Detailed <> '' then
        SB.Append('  detailed: ').Append(Text1(U.Detailed)).Append(#10);
      for C in U.Classes do
        DumpClass(SB, AProject, C, 1);
      for M in U.Members do
        if M.Kind <> memEnumValue then
          DumpMember(SB, AProject, M, '  ');
    end;
    for G in AProject.Groups do
    begin
      SB.Append('group ').Append(G.Name).Append(' "').Append(G.Title).Append('"');
      if G.Parent <> nil then
        SB.Append(' in ').Append(G.Parent.Name);
      SB.Append(' -> ').Append(G.DiskName).Append(#10);
      for D in G.Members do
        SB.Append('  member ').Append(D.QualifiedName).Append(#10);
    end;
    for P in AProject.Pages do
      SB.Append('page ').Append(P.Name).Append(' "').Append(P.Title).Append('" -> ').Append(P.DiskName).Append(#10);
    if AWithWarnings and (AProject.Warnings.Count > 0) then
    begin
      SB.Append('warnings:').Append(#10);
      for S in AProject.Warnings do
        SB.Append('  ').Append(StripPath(S).Replace(#10, ' ')).Append(#10);
    end;
    Result := SB.ToString;
  finally
    Units.Free;
    SB.Free;
  end;
end;

end.
