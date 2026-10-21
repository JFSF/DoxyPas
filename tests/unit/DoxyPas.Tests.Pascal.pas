unit DoxyPas.Tests.Pascal;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework;

type
  [TestFixture]
  TPascalSourceTests = class
  public
    [Test] procedure TokenKindsAndPositions;
    [Test] procedure StringsNumbersAndSymbols;
    [Test] procedure CommentsAndDirectives;
    [Test] procedure MultiLineString;
    [Test] procedure ScanToRespectsNesting;
    [Test] procedure SliceDropsCommentsAndKeepsSpacing;
  end;

  [TestFixture]
  TPascalParserTests = class
  public
    [Test] procedure GoldenFiles;
    [Test] procedure DefinesSelectConditionalCode;
    [Test] procedure InterfaceOnlyIgnoresImplementation;
    [Test] procedure SyntaxErrorReturnsPartialTree;
    [Test] procedure Utf8AndAnsiSourcesAreDecoded;
    [Test] procedure ClassMembersKeepVisibilityAndFlags;
    [Test] procedure ClassConstantsAndNestedTypes;
    [Test] procedure PropertyDetails;
    [Test] procedure DocCommentStyles;
    [Test] procedure PlainCommentsAreNotDocumentation;
    [Test] procedure CommentAfterClassEndDocumentsTheClass;
    [Test] procedure OptionsFromConfig;
  end;

implementation

uses
  System.IOUtils,
  System.Generics.Collections,
  DoxyPas.Model.Entry,
  DoxyPas.Model.EntryDump,
  DoxyPas.Lang.Pascal.Source,
  DoxyPas.Lang.Pascal.Parser,
  DoxyPas.Lang.Pascal.Options,
  DoxyPas.Config,
  DoxyPas.Config.Reader;

{ TPascalSourceTests }

procedure TPascalSourceTests.TokenKindsAndPositions;
var
  S: TPasSource;
begin
  S := TPasSource.Create('unit A;'#13#10'  var X: Integer;');
  try
    Assert.AreEqual<Integer>(9, S.Count); // unit A ; var X : Integer ; EOF
    Assert.IsTrue(S.IsWord(0, 'UNIT'));
    Assert.AreEqual<Integer>(1, S.Token(0).Line);
    Assert.AreEqual<Integer>(1, S.Token(0).Col);
    Assert.AreEqual<Integer>(2, S.Token(3).Line);
    Assert.AreEqual<Integer>(3, S.Token(3).Col);
    Assert.AreEqual<Integer>(3, S.IndexAt(2, 1)); // first token at/after (2,1) is "var"
    Assert.IsTrue(S.IsSymbol(2, ';'));
  finally
    S.Free;
  end;
end;

procedure TPascalSourceTests.StringsNumbersAndSymbols;
var
  S: TPasSource;
begin
  S := TPasSource.Create('X := ''it''''s'' + #13#10 + $FF + 1.5e-3 + 1..2;');
  try
    Assert.IsTrue(S.Token(2).Kind = tkString);
    Assert.AreEqual('''it''''s''', S.TokenText(2));
    Assert.IsTrue(S.IsSymbol(1, ':='));
    Assert.IsTrue(S.Token(4).Kind = tkString); // #13#10 chain starts with #13
    Assert.AreEqual('$FF', S.TokenText(S.IndexAt(1, 25)));
    // "1..2" is number, '..', number - not a float
    Assert.AreEqual('1.5e-3', S.TokenText(S.IndexAt(1, 31)));
    Assert.IsTrue(S.IsSymbol(S.Count - 4, '..'));
  finally
    S.Free;
  end;
end;

procedure TPascalSourceTests.CommentsAndDirectives;
var
  S: TPasSource;
begin
  S := TPasSource.Create('// line'#10'{ block } (* old *) {$IFDEF X} (*$DEFINE Y*) a');
  try
    Assert.IsTrue(S.Token(0).Kind = tkLineComment);
    Assert.IsTrue(S.Token(1).Kind = tkBlockComment);
    Assert.IsTrue(S.Token(2).Kind = tkBlockComment);
    Assert.IsTrue(S.Token(3).Kind = tkDirective);
    Assert.IsTrue(S.Token(4).Kind = tkDirective);
    Assert.AreEqual<Integer>(5, S.NextCode(-1));
    Assert.AreEqual('a', S.TokenText(5));
  finally
    S.Free;
  end;
end;

procedure TPascalSourceTests.MultiLineString;
var
  S: TPasSource;
begin
  S := TPasSource.Create('X := '''''''#10'  line 1'#10'  '''''';'#10'Y');
  try
    Assert.IsTrue(S.Token(2).Kind = tkString);
    Assert.AreEqual<Integer>(3, S.Token(2).EndLine);
    Assert.IsTrue(S.IsSymbol(3, ';'));
    Assert.AreEqual('Y', S.TokenText(4));
  finally
    S.Free;
  end;
end;

procedure TPascalSourceTests.ScanToRespectsNesting;
var
  S: TPasSource;
  E: Integer;
begin
  S := TPasSource.Create('A: TFoo<Integer, string>; B: record X: Integer; end; C');
  try
    // angle brackets and record bodies hide their ';' and ','
    E := S.ScanTo(2, ';', [], True);
    Assert.AreEqual('TFoo<Integer, string>', S.Slice(2, E));
    E := S.ScanTo(S.IndexAt(1, 30), ';', [], True);
    Assert.AreEqual('record X: Integer; end', S.Slice(S.IndexAt(1, 30), E));
    // stop words
    E := S.ScanTo(0, '', ['record'], False);
    Assert.IsTrue(S.IsWord(E, 'record'));
  finally
    S.Free;
  end;
end;

procedure TPascalSourceTests.SliceDropsCommentsAndKeepsSpacing;
var
  S: TPasSource;
begin
  S := TPasSource.Create('array[0..9]   of { c } Integer //x'#10);
  try
    Assert.AreEqual('array[0..9] of Integer', S.Slice(0, S.Count - 1));
  finally
    S.Free;
  end;
end;

{ TPascalParserTests }

function ParseText(const AText: string; const AOptions: TPascalParseOptions; out AError: string): TEntry; overload;
var
  R: TPascalParseResult;
begin
  R := ParsePascalText(AText, '', AOptions);
  AError := R.ErrorMessage;
  Result := R.Root;
end;

procedure TPascalParserTests.GoldenFiles;
var
  Dir, F, Expected, Actual: string;
  R: TPascalParseResult;
  Opts: TPascalParseOptions;
  Update: Boolean;
begin
  Dir := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\tests\golden\pascal'));
  Assert.IsTrue(TDirectory.Exists(Dir), 'golden directory not found: ' + Dir);
  Update := GetEnvironmentVariable('DOXYPAS_UPDATE_GOLDEN') = '1';
  Opts := TPascalParseOptions.Default;
  for F in TDirectory.GetFiles(Dir, '*.expected.txt') do
  begin
    // types.expected.txt -> types.pas / prog.dpr
    Expected := F.Replace('.expected.txt', '.pas');
    if not TFile.Exists(Expected) then
      Expected := F.Replace('.expected.txt', '.dpr');
    R := ParsePascalFile(Expected, Opts);
    try
      Assert.AreEqual('', R.ErrorMessage, ExtractFileName(Expected));
      Actual := DumpEntry(R.Root);
    finally
      R.Root.Free;
    end;
    if Update then
      TFile.WriteAllText(F, Actual, TUTF8Encoding.Create(False))
    else
      Assert.AreEqual(TFile.ReadAllText(F, TEncoding.UTF8).Replace(#13#10, #10), Actual, ExtractFileName(F));
  end;
end;

procedure TPascalParserTests.DefinesSelectConditionalCode;
const
  Src = 'unit U; interface'#10'{$IFDEF MSWINDOWS}procedure Win;{$ENDIF}'#10'{$IFDEF LINUX}procedure Lin;{$ENDIF}'#10 +
    '{$IFDEF MYDEF}procedure My;{$ENDIF}'#10'implementation end.';
var
  Opts: TPascalParseOptions;
  Err: string;
  Root: TEntry;
begin
  Root := ParseText(Src, TPascalParseOptions.Default, Err);
  try
    Assert.AreEqual<Integer>(1, Root.Children.Count);
    Assert.AreEqual('Win', Root.Children[0].Name);
  finally
    Root.Free;
  end;
  Opts := TPascalParseOptions.Default;
  Opts.Defines := DefaultPascalDefines('Delphi', 'Linux64') + ['MYDEF'];
  Root := ParseText(Src, Opts, Err);
  try
    Assert.AreEqual<Integer>(2, Root.Children.Count);
    Assert.AreEqual('Lin', Root.Children[0].Name);
    Assert.AreEqual('My', Root.Children[1].Name);
  finally
    Root.Free;
  end;
end;

procedure TPascalParserTests.InterfaceOnlyIgnoresImplementation;
const
  Src = 'unit U; interface procedure A; implementation procedure B; begin end; procedure A; begin end; end.';
var
  Opts: TPascalParseOptions;
  Err: string;
  Root: TEntry;
begin
  Opts := TPascalParseOptions.Default;
  Root := ParseText(Src, Opts, Err);
  try
    Assert.AreEqual<Integer>(3, Root.Children.Count); // A, B (impl), A (impl)
  finally
    Root.Free;
  end;
  Opts.InterfaceOnly := True;
  Root := ParseText(Src, Opts, Err);
  try
    Assert.AreEqual<Integer>(1, Root.Children.Count);
  finally
    Root.Free;
  end;
end;

procedure TPascalParserTests.SyntaxErrorReturnsPartialTree;
var
  Err: string;
  Root: TEntry;
begin
  Root := ParseText('unit U; interface procedure Good; type T = class procedure ) end; implementation end.',
    TPascalParseOptions.Default, Err);
  try
    Assert.IsTrue(Err <> '');
    Assert.IsNotNull(Root);
    Assert.AreEqual('Good', Root.Children[0].Name);
  finally
    Root.Free;
  end;
end;

procedure TPascalParserTests.Utf8AndAnsiSourcesAreDecoded;
var
  Dir, F: string;
  R: TPascalParseResult;
begin
  Dir := TPath.Combine(TPath.GetTempPath, 'doxypas_test_enc');
  TDirectory.CreateDirectory(Dir);
  try
    F := TPath.Combine(Dir, 'u8.pas');
    TFile.WriteAllText(F, 'unit U8; interface /// Ação é útil'#10'procedure Ok; implementation end.',
      TUTF8Encoding.Create(False));
    R := ParsePascalFile(F, TPascalParseOptions.Default);
    try
      Assert.AreEqual('', R.ErrorMessage);
      Assert.AreEqual('Ação é útil', R.Root.Children[0].Doc);
    finally
      R.Root.Free;
    end;
    F := TPath.Combine(Dir, 'ansi.pas');
    TFile.WriteAllBytes(F, TEncoding.GetEncoding(1252).GetBytes('unit A; interface /// caf' + #$E9 + #10 +
      'procedure Ok; implementation end.'));
    R := ParsePascalFile(F, TPascalParseOptions.Default);
    try
      Assert.AreEqual('', R.ErrorMessage);
      Assert.AreEqual('caf' + #$E9, R.Root.Children[0].Doc);
    finally
      R.Root.Free;
    end;
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

procedure TPascalParserTests.ClassMembersKeepVisibilityAndFlags;
var
  Err: string;
  Root, C: TEntry;
begin
  Root := ParseText('unit U; interface type TA = class(TObject, IFoo) strict private FX: Integer; protected ' +
    'procedure P; virtual; abstract; public class function Make: TA; static; published property Y: Integer ' +
    'read FX; end; implementation end.', TPascalParseOptions.Default, Err);
  try
    C := Root.Children[0];
    Assert.IsTrue(C.Kind = ekClass);
    Assert.AreEqual<Integer>(2, C.Bases.Count);
    Assert.IsTrue(C.Children[0].Protection = prStrictPrivate);
    Assert.IsTrue(C.Children[1].Protection = prProtected);
    Assert.IsTrue(C.Children[1].Virtualness = vtVirtual);
    Assert.IsTrue(efAbstract in C.Children[1].Flags);
    Assert.IsTrue([efClassMember, efStatic] <= C.Children[2].Flags);
    Assert.IsTrue(C.Children[2].MethodKind = rkFunction);
    Assert.AreEqual('TA', C.Children[2].TypeText);
    Assert.IsTrue(C.Children[3].Protection = prPublished);
  finally
    Root.Free;
  end;
end;

procedure TPascalParserTests.ClassConstantsAndNestedTypes;
var
  Err: string;
  Root, C: TEntry;
begin
  Root := ParseText('unit U; interface type TA = class strict private const Hidden = 1; protected type TInner = Integer; ' +
    'public const Limit = 5; Name = ''x''; procedure P; end; implementation end.', TPascalParseOptions.Default, Err);
  try
    C := Root.Children[0];
    Assert.AreEqual<Integer>(5, C.Children.Count);
    Assert.IsTrue(C.Children[0].Kind = ekConstant);
    Assert.IsTrue(C.Children[0].Protection = prStrictPrivate);
    Assert.IsTrue(C.Children[1].Kind = ekTypeAlias);
    Assert.IsTrue(C.Children[1].Protection = prProtected);          // a type has the visibility of its section
    Assert.AreEqual('Limit', C.Children[2].Name);
    Assert.IsTrue(C.Children[2].Kind = ekConstant);
    Assert.IsTrue(C.Children[2].Protection = prPublic);
    Assert.AreEqual('5', C.Children[2].InitText);
  finally
    Root.Free;
  end;
end;

procedure TPascalParserTests.PropertyDetails;
var
  Err: string;
  Root, P: TEntry;
begin
  Root := ParseText('unit U; interface type TA = class property Items[I: Integer]: string index 2 read GetI ' +
    'write SetI stored False; default; end; implementation end.', TPascalParseOptions.Default, Err);
  try
    Assert.AreEqual('', Err);
    P := Root.Children[0].Children[0];
    Assert.IsTrue(P.Kind = ekProperty);
    Assert.AreEqual('string', P.TypeText);
    Assert.AreEqual('GetI', P.ReadAccessor);
    Assert.AreEqual('SetI', P.WriteAccessor);
    Assert.AreEqual('2', P.IndexText);
    Assert.AreEqual('False', P.StoredText);
    Assert.AreEqual<Integer>(1, P.Args.Count);
    Assert.AreEqual('Integer', P.Args[0].TypeText);
    Assert.IsTrue(efDefaultProperty in P.Flags);
  finally
    Root.Free;
  end;
end;

procedure TPascalParserTests.DocCommentStyles;
var
  Err: string;
  Root: TEntry;
begin
  Root := ParseText('unit U; interface'#10 +
    '/// one'#10'/// two'#10'procedure A;'#10 +
    '{** three }'#10'procedure B;'#10 +
    '(** four'#10'  * more *)'#10'procedure C;'#10 +
    'procedure D; //!< five'#10 +
    'procedure E; {!< six }'#10 +
    'implementation end.', TPascalParseOptions.Default, Err);
  try
    Assert.AreEqual('', Err);
    Assert.AreEqual('one'#10'two', Root.Children[0].Doc);
    Assert.AreEqual('three', Root.Children[1].Doc);
    Assert.AreEqual('four'#10'more', Root.Children[2].Doc);
    Assert.AreEqual('five', Root.Children[3].Doc);
    Assert.IsTrue(Root.Children[3].DocIsAfter);
    Assert.AreEqual('six', Root.Children[4].Doc);
  finally
    Root.Free;
  end;
end;

procedure TPascalParserTests.PlainCommentsAreNotDocumentation;
var
  Err: string;
  Root: TEntry;
begin
  Root := ParseText('unit U; interface'#10'// plain'#10'{ block }'#10'(* old *)'#10'//// four slashes'#10 +
    'procedure A;'#10'implementation end.', TPascalParseOptions.Default, Err);
  try
    Assert.AreEqual('', Root.Children[0].Doc);
  finally
    Root.Free;
  end;
end;

procedure TPascalParserTests.CommentAfterClassEndDocumentsTheClass;
var
  Err: string;
  Root: TEntry;
begin
  Root := ParseText('unit U; interface type TA = class procedure M; end; ///< after the class'#10 +
    'implementation end.', TPascalParseOptions.Default, Err);
  try
    Assert.AreEqual('after the class', Root.Children[0].Doc);
    Assert.AreEqual('', Root.Children[0].Children[0].Doc);
  finally
    Root.Free;
  end;
end;

procedure TPascalParserTests.OptionsFromConfig;
var
  C: TConfig;
  Opts: TPascalParseOptions;
begin
  C := TConfig.Create;
  try
    ReadDoxyfileText(C, 'PASCAL_PLATFORM = Linux64'#10'PREDEFINED = MYDEF DEBUG=1'#10'INCLUDE_PATH = inc'#10, 'x');
    C.PostProcess;
    Opts := PascalOptionsFromConfig(C);
    Assert.IsTrue(TArray.IndexOf<string>(Opts.Defines, 'LINUX') >= 0);
    Assert.IsTrue(TArray.IndexOf<string>(Opts.Defines, 'MYDEF') >= 0);
    Assert.IsTrue(TArray.IndexOf<string>(Opts.Defines, 'DEBUG') >= 0);
    Assert.IsTrue(TArray.IndexOf<string>(Opts.Defines, 'MSWINDOWS') < 0);
    Assert.AreEqual<Integer>(1, Length(Opts.IncludePaths));
  finally
    C.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPascalSourceTests);
  TDUnitX.RegisterTestFixture(TPascalParserTests);

end.
