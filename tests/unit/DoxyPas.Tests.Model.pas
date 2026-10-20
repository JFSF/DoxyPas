unit DoxyPas.Tests.Model;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework;

type
  [TestFixture]
  TModelTests = class
  public
    [Test] procedure GoldenModels;
    [Test] procedure ParallelAndSequentialBuildsAreIdentical;
    [Test] procedure DiskNamesFollowDoxygenEscaping;
    [Test] procedure PlainNameRemovesGenericsAndArguments;
    [Test] procedure WildcardMatching;
    [Test] procedure InputFilesRespectPatternsRecursionAndExcludes;
    [Test] procedure UnitScopeNamesAreTried;
    [Test] procedure QualifiedAndNestedLookup;
    [Test] procedure UndocumentedIsHiddenUnlessExtractAll;
    [Test] procedure PrivateNeedsExtractPrivate;
    [Test] procedure ImplementationOnlyNeedsExtractStatic;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  DoxyPas.Config,
  DoxyPas.Config.Reader,
  DoxyPas.Model.Entry,
  DoxyPas.Model.Defs,
  DoxyPas.Model.Project,
  DoxyPas.Model.ProjectDump,
  DoxyPas.Build.Passes,
  DoxyPas.Build.Pipeline;

function MakeConfig(const ACaseCfg, AInput: string): TConfig;
begin
  Result := TConfig.Create;
  if ACaseCfg <> '' then
    ReadDoxyfileText(Result, ACaseCfg, 'case.cfg');
  Result.Find('INPUT').List.Clear;
  Result.Find('INPUT').List.Add(AInput);
  Result.PostProcess;
end;

function BuildFromDir(const ADir, ACaseCfg: string; AParallel: Boolean): TProject;
var
  C: TConfig;
begin
  C := MakeConfig(ACaseCfg, ADir);
  try
    Result := BuildProject(C, CollectInputFiles(C), AParallel);
  finally
    C.Free;
  end;
end;

{ Writes the given files into a fresh temp folder and builds a project from them. }
function BuildFromSources(const ANames, ATexts: array of string; const ACaseCfg: string): TProject;
var
  Dir: string;
  I: Integer;
begin
  Dir := TPath.Combine(TPath.GetTempPath, 'doxypas_model_' + TGuid.NewGuid.ToString.Substring(1, 8));
  TDirectory.CreateDirectory(Dir);
  try
    for I := 0 to High(ANames) do
      TFile.WriteAllText(TPath.Combine(Dir, ANames[I]), ATexts[I], TEncoding.UTF8);
    Result := BuildFromDir(Dir, ACaseCfg, False);
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TModelTests.GoldenModels;
var
  Root, Dir, Cfg, Expected, Actual: string;
  P: TProject;
  Update: Boolean;
begin
  Root := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\tests\golden\model'));
  Assert.IsTrue(TDirectory.Exists(Root), 'golden directory not found: ' + Root);
  Update := GetEnvironmentVariable('DOXYPAS_UPDATE_GOLDEN') = '1';
  for Dir in TDirectory.GetDirectories(Root) do
  begin
    Cfg := '';
    if TFile.Exists(TPath.Combine(Dir, 'case.cfg')) then
      Cfg := TFile.ReadAllText(TPath.Combine(Dir, 'case.cfg'));
    P := BuildFromDir(Dir, Cfg, False);
    try
      Actual := DumpProject(P);
    finally
      P.Free;
    end;
    Expected := TPath.Combine(Dir, 'expected.txt');
    if Update then
      TFile.WriteAllText(Expected, Actual, TUTF8Encoding.Create(False))
    else
      Assert.AreEqual(TFile.ReadAllText(Expected, TEncoding.UTF8).Replace(#13#10, #10), Actual, ExtractFileName(Dir));
  end;
end;

procedure TModelTests.ParallelAndSequentialBuildsAreIdentical;
var
  Dir: string;
  A, B: TProject;
begin
  Dir := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\tests\golden\model\inherit'));
  A := BuildFromDir(Dir, '', False);
  B := BuildFromDir(Dir, '', True);
  try
    Assert.AreEqual(DumpProject(A), DumpProject(B));
  finally
    B.Free;
    A.Free;
  end;
end;

procedure TModelTests.DiskNamesFollowDoxygenEscaping;
begin
  Assert.AreEqual('class_t_foo', ConvertNameToFile('classTFoo', False));
  Assert.AreEqual('classTFoo', ConvertNameToFile('classTFoo', True));
  Assert.AreEqual('class_unit_1_1_t_foo', ConvertNameToFile('classUnit::TFoo', False));
  Assert.AreEqual('a__b_8c', ConvertNameToFile('a_b.c', True));
  Assert.AreEqual('a_b.c', ConvertNameToFile('a_b.c', True, True, True));
  Assert.AreEqual('x_3T_4', ConvertNameToFile('x<T>', True));
  Assert.AreEqual(128, Length(ConvertNameToFile(StringOfChar('x', 300), True)));
end;

procedure TModelTests.PlainNameRemovesGenericsAndArguments;
begin
  Assert.AreEqual('TList.Add', PlainName('TList<T>.Add(X: Integer)'));
  Assert.AreEqual('Foo', PlainName(' Foo '));
  Assert.AreEqual('A.B.C', PlainName('A.B<X<Y>>.C()'));
end;

procedure TModelTests.WildcardMatching;
begin
  Assert.IsTrue(MatchWildcard('*.pas', 'Foo.PAS'));
  Assert.IsTrue(MatchWildcard('*/test/*', 'C:\proj\test\a.pas'));
  Assert.IsTrue(MatchWildcard('Fo?.pas', 'foo.pas'));
  Assert.IsFalse(MatchWildcard('*.dpr', 'a.pas'));
  Assert.IsTrue(MatchWildcard('*', ''));
end;

procedure TModelTests.InputFilesRespectPatternsRecursionAndExcludes;
var
  Dir: string;
  C: TConfig;
  Files: TArray<string>;
begin
  Dir := TPath.Combine(TPath.GetTempPath, 'doxypas_input_' + TGuid.NewGuid.ToString.Substring(1, 8));
  TDirectory.CreateDirectory(TPath.Combine(Dir, 'sub'));
  TDirectory.CreateDirectory(TPath.Combine(Dir, 'tests'));
  try
    TFile.WriteAllText(TPath.Combine(Dir, 'a.pas'), 'unit a; interface implementation end.');
    TFile.WriteAllText(TPath.Combine(Dir, 'b.txt'), 'x');
    TFile.WriteAllText(TPath.Combine(Dir, 'sub\c.pas'), 'unit c; interface implementation end.');
    TFile.WriteAllText(TPath.Combine(Dir, 'tests\t.pas'), 'unit t; interface implementation end.');
    C := MakeConfig('', Dir);
    try
      // default FILE_PATTERNS is Doxygen's C list: Pascal patterns are used instead; no recursion by default
      Files := CollectInputFiles(C);
      Assert.AreEqual<Integer>(1, Length(Files));
      C.Find('RECURSIVE').Raw := 'YES';
      C.PostProcess;
      Assert.AreEqual<Integer>(3, Length(CollectInputFiles(C)));
      C.Find('EXCLUDE_PATTERNS').List.Add('*/tests/*');
      Assert.AreEqual<Integer>(2, Length(CollectInputFiles(C)));
      C.Find('EXCLUDE').List.Add(TPath.Combine(Dir, 'sub'));
      Assert.AreEqual<Integer>(1, Length(CollectInputFiles(C)));
    finally
      C.Free;
    end;
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TModelTests.UnitScopeNamesAreTried;
var
  P: TProject;
begin
  P := BuildFromSources(['System.Classes.pas', 'User.pas'],
    ['unit System.Classes; interface type TList = class end; implementation end.',
     'unit User; interface uses Classes; type TMine = class(TList) end; implementation end.'], '');
  try
    Assert.IsNotNull(P.FindUnit('Classes'));
    Assert.IsNotNull(P.FindUnit('system.classes'));
    Assert.AreEqual('System.Classes', P.FindUnit('Classes').Name);
    Assert.AreEqual<Integer>(1, P.FindUnit('User').UsesInterface.Count);
    Assert.IsNotNull(P.Classes[1].Bases[0].ClassDef);
    Assert.AreEqual('TList', P.Classes[1].Bases[0].ClassDef.Name);
  finally
    P.Free;
  end;
end;

procedure TModelTests.QualifiedAndNestedLookup;
var
  P: TProject;
  D: TDefinition;
begin
  P := BuildFromSources(['U.pas'],
    ['unit U; interface type TOuter = class public type TInner = class procedure Go; end; procedure Do1; ' +
     'end; TColor = (clRed, clBlue); implementation end.'], '');
  try
    D := P.Lookup('U.TOuter.TInner.Go', nil);
    Assert.IsNotNull(D);
    Assert.AreEqual('Go', D.Name);
    Assert.AreEqual('U.TOuter.TInner.Go', D.QualifiedName);
    Assert.IsNotNull(P.Lookup('tinner', P.Lookup('TOuter', nil)));          // case-insensitive, nested type
    Assert.IsNotNull(P.Lookup('TOuter::Do1()', nil));                     // C++ style separator and call syntax
    Assert.IsNotNull(P.Lookup('clBlue', nil));                             // enumeration values live in the unit scope
    Assert.IsNotNull(P.Lookup('TColor.clRed', nil));
    Assert.IsNull(P.Lookup('NoSuchThing', nil));
  finally
    P.Free;
  end;
end;

procedure TModelTests.UndocumentedIsHiddenUnlessExtractAll;
var
  P: TProject;
begin
  P := BuildFromSources(['U.pas'], ['unit U; interface type TA = class procedure M; end; implementation end.'], '');
  try
    Assert.IsFalse(P.IsVisible(P.Classes[0]));
    Assert.IsFalse(P.IsVisible(P.FindUnit('U')));
  finally
    P.Free;
  end;
  P := BuildFromSources(['U.pas'], ['unit U; interface type TA = class procedure M; end; implementation end.'],
    'EXTRACT_ALL = YES');
  try
    Assert.IsTrue(P.IsVisible(P.Classes[0]));
    Assert.IsTrue(P.IsVisible(P.Members[0]));
  finally
    P.Free;
  end;
  // an undocumented member of a documented class is listed unless HIDE_UNDOC_MEMBERS
  P := BuildFromSources(['U.pas'], ['unit U; interface /// doc'#10'type TA = class procedure M; end; implementation end.'],
    '');
  try
    Assert.IsTrue(P.IsVisible(P.Members[0]));
  finally
    P.Free;
  end;
  P := BuildFromSources(['U.pas'], ['unit U; interface /// doc'#10'type TA = class procedure M; end; implementation end.'],
    'HIDE_UNDOC_MEMBERS = YES');
  try
    Assert.IsFalse(P.IsVisible(P.Members[0]));
  finally
    P.Free;
  end;
end;

procedure TModelTests.PrivateNeedsExtractPrivate;
const
  Src = 'unit U; interface /// c'#10'type TA = class private /// f'#10'FX: Integer; public /// m'#10'procedure M; end; ' +
    'implementation end.';
var
  P: TProject;
begin
  P := BuildFromSources(['U.pas'], [Src], '');
  try
    Assert.IsFalse(P.IsVisible(P.Members[0]));
    Assert.IsTrue(P.IsVisible(P.Members[1]));
  finally
    P.Free;
  end;
  P := BuildFromSources(['U.pas'], [Src], 'EXTRACT_PRIVATE = YES');
  try
    Assert.IsTrue(P.IsVisible(P.Members[0]));
  finally
    P.Free;
  end;
end;

procedure TModelTests.ImplementationOnlyNeedsExtractStatic;
const
  Src = 'unit U; interface /// u'#10'procedure A; implementation /// helper'#10'procedure H; begin end; ' +
    'procedure A; begin end; end.';
var
  P: TProject;
  H: TMemberDef;
  M: TMemberDef;
begin
  P := BuildFromSources(['U.pas'], [Src], '');
  try
    H := nil;
    for M in P.Members do
      if M.Name = 'H' then
        H := M;
    Assert.IsNotNull(H);
    Assert.IsTrue(H.ImplementationOnly);
    Assert.IsFalse(P.IsVisible(H));
  finally
    P.Free;
  end;
  P := BuildFromSources(['U.pas'], [Src], 'EXTRACT_STATIC = YES');
  try
    for M in P.Members do
      if M.Name = 'H' then
        H := M;
    Assert.IsTrue(P.IsVisible(H));
  finally
    P.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TModelTests);

end.
