unit DoxyPas.Tests.Config;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DoxyPas.Config;

type
  [TestFixture]
  TConfigTests = class
  strict private
    FConfig: TConfig;
    FWarnings: TList<string>;
    procedure Load(const AText: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test] procedure DefaultsComeFromConfigXml;
    [Test] procedure ImplementedOptionsAreOptions;
    [Test] procedure AssignmentsAndComments;
    [Test] procedure QuotedStringsAndEscapes;
    [Test] procedure ListAssignAndAppend;
    [Test] procedure ListQuotingAndCommas;
    [Test] procedure PredefinedIsNotSplitOnCommas;
    [Test] procedure LineContinuation;
    [Test] procedure BoolIntEnumConversion;
    [Test] procedure InvalidValuesWarnAndKeepDefault;
    [Test] procedure UnknownAndObsoleteTagsWarn;
    [Test] procedure EnvironmentVariables;
    [Test] procedure EmptyValueGetsDefault;
    [Test] procedure IncludeFile;
    [Test] procedure TemplateRoundTripHasNoDifferences;
    [Test] procedure UpdateKeepsValuesAndUserComments;
    [Test] procedure DiffListsOnlyChangedOptions;
  end;

implementation

uses
  System.IOUtils,
  DoxyPas.Core.Log,
  DoxyPas.Config.Options,
  DoxyPas.Config.Implemented,
  DoxyPas.Config.Reader,
  DoxyPas.Config.Writer;

procedure TConfigTests.Setup;
begin
  FConfig := TConfig.Create;
  FWarnings := TList<string>.Create;
  LogSink := procedure(const AText: string)
    begin
      FWarnings.Add(AText);
    end;
end;

procedure TConfigTests.TearDown;
begin
  LogSink := nil;
  FWarnings.Free;
  FConfig.Free;
end;

procedure TConfigTests.Load(const AText: string);
begin
  ReadDoxyfileText(FConfig, AText, 'test.cfg');
  FConfig.PostProcess;
end;

procedure TConfigTests.DefaultsComeFromConfigXml;
begin
  Assert.AreEqual<Integer>(ConfigOptionCount, FConfig.Options.Count);
  Assert.AreEqual('My Project', FConfig.GetString('PROJECT_NAME'));
  Assert.IsTrue(FConfig.GetBool('GENERATE_HTML'));
  Assert.IsTrue(FConfig.GetBool('GENERATE_LATEX'));
  Assert.IsFalse(FConfig.GetBool('GENERATE_XML'));
  Assert.AreEqual('English', FConfig.GetString('OUTPUT_LANGUAGE'));
  Assert.AreEqual('Delphi', FConfig.GetString('PASCAL_DIALECT'));
  Assert.AreEqual<Integer>(11, Integer(Length(FConfig.GetList('ABBREVIATE_BRIEF'))));
end;

procedure TConfigTests.ImplementedOptionsAreOptions;
var
  Names: TArray<string>;
  I: Integer;
  Opt: TConfigOption;
begin
  Names := ImplementedOptions;
  for I := 0 to High(Names) do
  begin
    Opt := FConfig.Find(Names[I]);
    Assert.IsNotNull(Opt, Names[I] + ' is not an option');
    Assert.IsTrue(Opt.Info.Kind <> okObsolete, Names[I] + ' is obsolete');
    if I > 0 then
      Assert.IsTrue(CompareStr(Names[I - 1], Names[I]) < 0, Names[I] + ' is not in order');
  end;
  Assert.IsTrue(IsImplemented('PROJECT_NAME'));
  Assert.IsFalse(IsImplemented('NO_SUCH_OPTION'));
end;

procedure TConfigTests.AssignmentsAndComments;
begin
  Load('# a comment'#10'PROJECT_NAME = Foo # trailing'#10'  PROJECT_NUMBER=1.2'#10);
  Assert.AreEqual('Foo', FConfig.GetString('PROJECT_NAME'));
  Assert.AreEqual('1.2', FConfig.GetString('PROJECT_NUMBER'));
  Assert.AreEqual<Integer>(0, FWarnings.Count);
end;

procedure TConfigTests.QuotedStringsAndEscapes;
begin
  Load('PROJECT_NAME = "My \"best\" project" # c'#10'PROJECT_BRIEF = "a # not a comment"'#10);
  Assert.AreEqual('My "best" project', FConfig.GetString('PROJECT_NAME'));
  Assert.AreEqual('a # not a comment', FConfig.GetString('PROJECT_BRIEF'));
end;

procedure TConfigTests.ListAssignAndAppend;
var
  L: TArray<string>;
begin
  Load('INPUT = a b'#10'INPUT += c'#10);
  L := FConfig.GetList('INPUT');
  Assert.AreEqual<Integer>(3, Integer(Length(L)));
  Assert.AreEqual('c', L[2]);
  Load('INPUT = x'#10);
  Assert.AreEqual<Integer>(1, Integer(Length(FConfig.GetList('INPUT'))));
end;

procedure TConfigTests.ListQuotingAndCommas;
var
  L: TArray<string>;
begin
  Load('INPUT = "dir with space", other,third'#10);
  L := FConfig.GetList('INPUT');
  Assert.AreEqual<Integer>(3, Integer(Length(L)));
  Assert.AreEqual('dir with space', L[0]);
  Assert.AreEqual('third', L[2]);
end;

procedure TConfigTests.PredefinedIsNotSplitOnCommas;
var
  L: TArray<string>;
begin
  Load('PREDEFINED = A=1,2 B'#10);
  L := FConfig.GetList('PREDEFINED');
  Assert.AreEqual<Integer>(2, Integer(Length(L)));
  Assert.AreEqual('A=1,2', L[0]);
end;

procedure TConfigTests.LineContinuation;
var
  L: TArray<string>;
begin
  Load('INPUT = a \'#10'        b \  '#10'        c'#10'PROJECT_NAME = X'#10);
  L := FConfig.GetList('INPUT');
  Assert.AreEqual<Integer>(3, Integer(Length(L)));
  Assert.AreEqual('X', FConfig.GetString('PROJECT_NAME'));
end;

procedure TConfigTests.BoolIntEnumConversion;
begin
  Load('GENERATE_HTML = no'#10'GENERATE_LATEX = TRUE'#10'TAB_SIZE = 8'#10'OUTPUT_LANGUAGE = portuguese'#10);
  Assert.IsFalse(FConfig.GetBool('GENERATE_HTML'));
  Assert.IsTrue(FConfig.GetBool('GENERATE_LATEX'));
  Assert.AreEqual<Integer>(8, FConfig.GetInt('TAB_SIZE'));
  Assert.AreEqual('Portuguese', FConfig.GetString('OUTPUT_LANGUAGE'));
  Assert.AreEqual<Integer>(0, FWarnings.Count);
end;

procedure TConfigTests.InvalidValuesWarnAndKeepDefault;
begin
  Load('GENERATE_HTML = maybe'#10'TAB_SIZE = 99999'#10'OUTPUT_LANGUAGE = Klingon'#10);
  Assert.IsTrue(FConfig.GetBool('GENERATE_HTML'));
  Assert.AreEqual<Integer>(4, FConfig.GetInt('TAB_SIZE'));
  Assert.AreEqual('English', FConfig.GetString('OUTPUT_LANGUAGE'));
  Assert.AreEqual<Integer>(3, FWarnings.Count);
end;

procedure TConfigTests.UnknownAndObsoleteTagsWarn;
begin
  Load('NOT_A_TAG = 1'#10'USE_WINDOWS_ENCODING = YES'#10'GENERATE_HTML += YES'#10);
  Assert.AreEqual<Integer>(3, FWarnings.Count);
  Assert.IsTrue(FWarnings[0].Contains('NOT_A_TAG'));
  Assert.IsTrue(FWarnings[1].Contains('obsolete'));
  Assert.IsTrue(FWarnings[2].Contains('+='));
end;

procedure TConfigTests.EnvironmentVariables;
var
  Path: string;
begin
  Path := GetEnvironmentVariable('PATH');
  Assert.IsNotEmpty(Path);
  Load('PROJECT_NAME = $(PATH)'#10'INPUT = $(DOXYPAS_SURELY_UNSET) keep'#10);
  Assert.AreEqual(Trim(Path), FConfig.GetString('PROJECT_NAME'));
  Assert.AreEqual<Integer>(1, Integer(Length(FConfig.GetList('INPUT'))));
  Assert.AreEqual('keep', FConfig.GetList('INPUT')[0]);
end;

procedure TConfigTests.EmptyValueGetsDefault;
begin
  Load('INPUT_ENCODING ='#10);
  Assert.AreEqual('UTF-8', FConfig.GetString('INPUT_ENCODING'));
end;

procedure TConfigTests.IncludeFile;
var
  Dir, Inc: string;
begin
  Dir := TPath.Combine(TPath.GetTempPath, 'doxypas_test_inc');
  TDirectory.CreateDirectory(Dir);
  Inc := TPath.Combine(Dir, 'inc.cfg');
  try
    TFile.WriteAllText(Inc, 'PROJECT_NAME = FromInclude'#10);
    Load('@INCLUDE = "' + Inc + '"'#10'PROJECT_NUMBER = 2'#10);
    Assert.AreEqual('FromInclude', FConfig.GetString('PROJECT_NAME'));
    Assert.AreEqual('2', FConfig.GetString('PROJECT_NUMBER'));
    Assert.WillRaise(
      procedure
      begin
        Load('@INCLUDE = no_such_file.cfg'#10);
      end, EConfigError);
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TConfigTests.TemplateRoundTripHasNoDifferences;
var
  Template: string;
  Other: TConfig;
begin
  Template := WriteDoxyfile(FConfig, False, False);
  Assert.IsTrue(Template.StartsWith('# Doxyfile '));
  Other := TConfig.Create;
  try
    ReadDoxyfileText(Other, Template, 'template');
    Other.PostProcess;
    Assert.AreEqual<Integer>(0, FWarnings.Count);
    Assert.AreEqual(WriteDoxyfileDiff(FConfig), WriteDoxyfileDiff(Other));
    Assert.AreEqual<Integer>(1, Length(WriteDoxyfileDiff(Other).Split([#10], TStringSplitOptions.ExcludeEmpty)));
  finally
    Other.Free;
  end;
end;

procedure TConfigTests.UpdateKeepsValuesAndUserComments;
var
  Text, Updated: string;
begin
  Text := '## keep me'#10'PROJECT_NAME = "Some Name"'#10'GENERATE_HTML = yes'#10'INPUT = a "b c"'#10;
  ReadDoxyfileText(FConfig, Text, 'x');
  Updated := WriteDoxyfile(FConfig, True, True);
  Assert.IsTrue(Updated.Contains('## keep me'#10'PROJECT_NAME           = "Some Name"'#10));
  Assert.IsTrue(Updated.Contains('GENERATE_HTML          = yes'#10));
  Assert.IsTrue(Updated.Contains('INPUT                  = a \'#10 + StringOfChar(' ', 25) + '"b c"'#10));
end;

procedure TConfigTests.DiffListsOnlyChangedOptions;
var
  Diff: string;
begin
  Load('PROJECT_NAME = Foo'#10'GENERATE_HTML = YES'#10);
  Diff := WriteDoxyfileDiff(FConfig);
  Assert.IsTrue(Diff.Contains('PROJECT_NAME           = Foo'));
  Assert.IsFalse(Diff.Contains('GENERATE_HTML'));
end;

initialization
  TDUnitX.RegisterTestFixture(TConfigTests);

end.
