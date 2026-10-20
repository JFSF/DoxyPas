unit DoxyPas.Tests.Doc;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework;

type
  [TestFixture]
  TDocParserTests = class
  public
    [Test] procedure GoldenFiles;
    [Test] procedure TextNodesMergeAndTrim;
    [Test] procedure ParamsGroupAndEndAtBlankLine;
    [Test] procedure ParagraphAfterSectionIsOutsideIt;
    [Test] procedure GenericTypesStayLiteral;
    [Test] procedure UnknownCommandWarns;
  end;

  [TestFixture]
  TMarkdownTests = class
  public
    [Test] procedure EmphasisRules;
    [Test] procedure CodeSpansAreEscaped;
    [Test] procedure CodeBlocksAreUntouched;
    [Test] procedure NestedLists;
    [Test] procedure TableAlignment;
  end;

  [TestFixture]
  TScannerTests = class
  public
    [Test] procedure BriefCommandEndsAtBlankLine;
    [Test] procedure BriefEndsAtBlockCommand;
    [Test] procedure JavadocAutobrief;
    [Test] procedure QtAutobrief;
    [Test] procedure AfterCommentIsBrief;
    [Test] procedure AliasesWithAndWithoutArguments;
    [Test] procedure ConditionalSections;
    [Test] procedure EntryCommandsAreExtracted;
    [Test] procedure InternalTextIsRemovedUnlessEnabled;
  end;

  [TestFixture]
  TXmlDocTests = class
  public
    [Test] procedure SummaryParamReturns;
    [Test] procedure SeeAndParamRef;
    [Test] procedure Lists;
    [Test] procedure PlainHtmlIsNotXmlDoc;
    [Test] procedure XmlDocEndToEnd;
    [Test] procedure EntryDocsFromPascalSource;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  DoxyPas.Doc.Nodes,
  DoxyPas.Doc.Dump,
  DoxyPas.Doc.Markdown,
  DoxyPas.Doc.Parser,
  DoxyPas.Comments.XmlDoc,
  DoxyPas.Comments.Scanner,
  DoxyPas.Comments.EntryDocs,
  DoxyPas.Model.Entry,
  DoxyPas.Lang.Pascal.Parser;

function Dump(const AText: string; AWarnings: TStrings = nil): string;
var
  Root: TDocNode;
begin
  Root := ParseDoc(AText, AWarnings);
  try
    Result := DumpDoc(Root);
  finally
    Root.Free;
  end;
end;

function Render(const AText: string): string;
var
  Md: string;
  W: TStringList;
begin
  Md := MarkdownToDoxygen(AText);
  W := TStringList.Create;
  try
    Result := '--- markdown'#10 + Md + #10'--- parsed'#10 + Dump(Md, W);
    if W.Count > 0 then
      Result := Result + #10'--- warnings'#10 + W.Text.Replace(#13#10, #10).TrimRight([#10]);
  finally
    W.Free;
  end;
  Result := Result + #10;
end;

{ TDocParserTests }

procedure TDocParserTests.GoldenFiles;
var
  Dir, F, Expected: string;
  Update: Boolean;
  Actual: string;
begin
  Dir := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\tests\golden\docs'));
  Assert.IsTrue(TDirectory.Exists(Dir), 'golden directory not found: ' + Dir);
  Update := GetEnvironmentVariable('DOXYPAS_UPDATE_GOLDEN') = '1';
  for F in TDirectory.GetFiles(Dir, '*.in.txt') do
  begin
    Expected := F.Replace('.in.txt', '.expected.txt');
    Actual := Render(TFile.ReadAllText(F, TEncoding.UTF8).Replace(#13#10, #10));
    if Update then
      TFile.WriteAllText(Expected, Actual, TUTF8Encoding.Create(False))
    else
      Assert.AreEqual(TFile.ReadAllText(Expected, TEncoding.UTF8).Replace(#13#10, #10), Actual, ExtractFileName(F));
  end;
end;

procedure TDocParserTests.TextNodesMergeAndTrim;
begin
  Assert.AreEqual('<doc><p>a b <b>c</b> d</p></doc>'.Replace('<doc>', '<doc>'#10'  ').Replace('</doc>', #10'</doc>'),
    Dump('  a   b'#10' <b>c</b>  d  '));
end;

procedure TDocParserTests.ParamsGroupAndEndAtBlankLine;
var
  D: string;
begin
  D := Dump('\param a first'#10'\param b second'#10#10'tail');
  Assert.IsTrue(D.Contains('<params name="param">'));
  Assert.IsTrue(D.Contains('<param text="a"><p>first</p></param>'));
  Assert.IsTrue(D.Contains('<param text="b"><p>second</p></param>'));
  // the blank line ends the paragraph that holds the parameters: "tail" is a separate paragraph
  Assert.IsTrue(D.Contains('</params></p>'#10'  <p>tail</p>'));
end;

procedure TDocParserTests.ParagraphAfterSectionIsOutsideIt;
var
  D: string;
begin
  D := Dump('\return value'#10#10'after');
  Assert.IsTrue(D.Contains('<sect name="return"><p>value</p></sect></p>'));
  Assert.IsTrue(D.Contains('<p>after</p>'));
end;

procedure TDocParserTests.GenericTypesStayLiteral;
begin
  Assert.IsTrue(Dump('Uses TList<T> and TDictionary<K, V>.').Contains('TList&lt;T&gt; and TDictionary&lt;K, V&gt;.'));
end;

procedure TDocParserTests.UnknownCommandWarns;
var
  W: TStringList;
begin
  W := TStringList.Create;
  try
    Dump('text \nosuchcommand more', W);
    Assert.AreEqual<Integer>(1, W.Count);
    Assert.IsTrue(W[0].Contains('nosuchcommand'));
  finally
    W.Free;
  end;
end;

{ TMarkdownTests }

procedure TMarkdownTests.EmphasisRules;
begin
  Assert.AreEqual('<em>a</em> <strong>b</strong>', MarkdownToDoxygen('*a* **b**'));
  Assert.AreEqual('snake_case_name', MarkdownToDoxygen('snake_case_name'));
  Assert.AreEqual('a * b * c', MarkdownToDoxygen('a * b * c'));
  Assert.AreEqual('<em>word</em>', MarkdownToDoxygen('_word_'));
end;

procedure TMarkdownTests.CodeSpansAreEscaped;
begin
  Assert.AreEqual('<code>a &lt; b &amp;&amp; \\c</code>', MarkdownToDoxygen('`a < b && \c`'));
end;

procedure TMarkdownTests.CodeBlocksAreUntouched;
var
  S: string;
begin
  S := '\code'#10'*not* emphasis'#10'- not a list'#10'\endcode';
  Assert.AreEqual(S, MarkdownToDoxygen(S));
  Assert.AreEqual('\code{.pas}'#10'x *y*'#10'\endcode', MarkdownToDoxygen('```pas'#10'x *y*'#10'```'));
end;

procedure TMarkdownTests.NestedLists;
begin
  Assert.AreEqual('<ul>'#10'<li>a'#10'<ul>'#10'<li>b</li>'#10'</ul></li>'#10'<li>c</li>'#10'</ul>',
    MarkdownToDoxygen('- a'#10'  - b'#10'- c'));
  Assert.AreEqual('<ol>'#10'<li>x</li>'#10'<li>y</li>'#10'</ol>', MarkdownToDoxygen('1. x'#10'2. y'));
end;

procedure TMarkdownTests.TableAlignment;
var
  S: string;
begin
  S := MarkdownToDoxygen('| A | B |'#10'|:-:|--:|'#10'| 1 | 2 |');
  Assert.IsTrue(S.Contains('<th align="center">A</th>'));
  Assert.IsTrue(S.Contains('<td align="right">2</td>'));
end;

{ TScannerTests }

function Scan(const AText: string; AIsAfter: Boolean = False): TCommentInfo; overload;
begin
  Result := ScanComment(AText, AIsAfter, TDocOptions.Default);
end;

procedure TScannerTests.BriefCommandEndsAtBlankLine;
var
  I: TCommentInfo;
begin
  I := Scan('Before.'#10'\brief Short text'#10'on two lines.'#10#10'Long text.');
  Assert.AreEqual('Short text'#10'on two lines.', I.Brief);
  Assert.AreEqual('Before.'#10#10'Long text.', I.Detailed);
end;

procedure TScannerTests.BriefEndsAtBlockCommand;
var
  I: TCommentInfo;
begin
  I := Scan('\brief Short'#10'\param a value');
  Assert.AreEqual('Short', I.Brief);
  Assert.AreEqual('\param a value', I.Detailed);
end;

procedure TScannerTests.JavadocAutobrief;
var
  O: TDocOptions;
  I: TCommentInfo;
begin
  O := TDocOptions.Default;
  O.JavadocAutobrief := True;
  I := ScanComment('First sentence. Second sentence.'#10'More.', False, O);
  Assert.AreEqual('First sentence.', I.Brief);
  Assert.AreEqual('Second sentence.'#10'More.', I.Detailed);
  Assert.AreEqual('', Scan('No brief here. Just detail.').Brief);
end;

procedure TScannerTests.QtAutobrief;
var
  O: TDocOptions;
  I: TCommentInfo;
begin
  O := TDocOptions.Default;
  O.QtAutobrief := True;
  I := ScanComment('First line'#10'second line.', False, O);
  Assert.AreEqual('First line', I.Brief);
  Assert.AreEqual('second line.', I.Detailed);
end;

procedure TScannerTests.AfterCommentIsBrief;
var
  I: TCommentInfo;
begin
  I := Scan('the x coordinate', True);
  Assert.AreEqual('the x coordinate', I.Brief);
  Assert.AreEqual('', I.Detailed);
end;

procedure TScannerTests.AliasesWithAndWithoutArguments;
begin
  Assert.AreEqual('The Result: x', ExpandAliases('\res x', ['res=The Result:']).Replace('The Result: x', 'The Result: x'));
  Assert.AreEqual('<b>hello</b> and <b>w</b>',
    ExpandAliases('\bold{hello} and @bold{w}', ['bold{1}=<b>\1</b>']));
  Assert.AreEqual('a-b', ExpandAliases('\two{a,b}', ['two{2}=\1-\2']));
  // an alias with arguments used without them is left alone
  Assert.AreEqual('\bold alone', ExpandAliases('\bold alone', ['bold{1}=<b>\1</b>']));
end;

procedure TScannerTests.ConditionalSections;
var
  E: TArray<string>;
begin
  E := ['WINDOWS'];
  Assert.AreEqual('a'#10'c', ApplyConditionals('a'#10'\cond LINUX'#10'b'#10'\endcond'#10'c', E));
  Assert.AreEqual('a'#10'b'#10'c', ApplyConditionals('a'#10'\cond WINDOWS'#10'b'#10'\endcond'#10'c', E));
  Assert.AreEqual('x', ApplyConditionals('\if LINUX'#10'l'#10'\elseif WINDOWS'#10'x'#10'\else'#10'e'#10'\endif', E));
  Assert.AreEqual('l', ApplyConditionals('\ifnot WINDOWS'#10'w'#10'\else'#10'l'#10'\endif', E));
  Assert.AreEqual('y', ApplyConditionals('\if WINDOWS && !LINUX'#10'y'#10'\endif', E));
end;

procedure TScannerTests.EntryCommandsAreExtracted;
var
  I: TCommentInfo;
begin
  I := Scan('Text.'#10'\ingroup core util'#10'\public'#10'\hideinitializer');
  Assert.AreEqual<Integer>(2, Length(I.Groups));
  Assert.AreEqual('util', I.Groups[1]);
  Assert.AreEqual('public', I.ProtectionOverride);
  Assert.IsTrue(I.HideInitializer);
  Assert.AreEqual('Text.', I.Detailed);
end;

procedure TScannerTests.InternalTextIsRemovedUnlessEnabled;
var
  O: TDocOptions;
  I: TCommentInfo;
begin
  I := Scan('Public.'#10'\internal'#10'Secret.');
  Assert.IsTrue(I.IsInternal);
  Assert.AreEqual('Public.', I.Detailed);
  O := TDocOptions.Default;
  O.InternalDocs := True;
  I := ScanComment('Public.'#10'\internal'#10'Secret.', False, O);
  Assert.IsTrue(I.Detailed.Contains('Secret.'));
end;

{ TXmlDocTests }

procedure TXmlDocTests.SummaryParamReturns;
var
  S: string;
begin
  S := ConvertXmlDoc('<summary>Does it.</summary><param name="A">first</param><returns>the sum</returns>');
  Assert.IsTrue(S.Contains('\brief Does it.'));
  Assert.IsTrue(S.Contains('\param A first'));
  Assert.IsTrue(S.Contains('\return the sum'));
end;

procedure TXmlDocTests.SeeAndParamRef;
var
  S: string;
begin
  S := ConvertXmlDoc('<summary>See <see cref="T:Unit1.TFoo"/> and <paramref name="X"/>.</summary>');
  Assert.IsTrue(S.Contains('\ref Unit1.TFoo '));
  Assert.IsTrue(S.Contains('\p X '));
end;

procedure TXmlDocTests.Lists;
var
  S: string;
begin
  S := ConvertXmlDoc('<summary>x</summary><list type="bullet"><item><description>one</description></item>' +
    '<item><description>two</description></item></list>');
  Assert.IsTrue(S.Contains('<ul>'));
  Assert.IsTrue(S.Contains('<li>one</li>'));
  Assert.IsTrue(S.Contains('</ul>'));
end;

procedure TXmlDocTests.PlainHtmlIsNotXmlDoc;
begin
  Assert.IsFalse(HasXmlDoc('A <b>bold</b> <code>x</code> and TList<T>.'));
  Assert.AreEqual('A <b>bold</b>', ConvertXmlDoc('A <b>bold</b>'));
  Assert.IsTrue(HasXmlDoc('<summary>x</summary>'));
end;

procedure TXmlDocTests.XmlDocEndToEnd;
var
  I: TCommentInfo;
begin
  I := Scan('<summary>Adds numbers.</summary>'#10'<param name="A">first</param>'#10'<returns>sum</returns>');
  Assert.AreEqual('Adds numbers.', I.Brief);
  Assert.IsTrue(I.Detailed.Contains('\param A first'));
  Assert.IsTrue(I.Detailed.Contains('\return sum'));
end;

procedure TXmlDocTests.EntryDocsFromPascalSource;
var
  R: TPascalParseResult;
  M: TEntry;
begin
  R := ParsePascalText('unit U; interface'#10 +
    '/// <summary>Adds.</summary>'#10'/// <param name="A">x</param>'#10'function Add(A: Integer): Integer;'#10 +
    'var'#10'  X: Integer; ///< the x value'#10'implementation end.', '', TPascalParseOptions.Default);
  try
    ScanEntryDocs(R.Root, TDocOptions.Default);
    M := R.Root.Children[0];
    Assert.AreEqual('Adds.', M.Brief);
    Assert.IsTrue(M.Detailed.Contains('\param A x'));
    Assert.AreEqual('the x value', R.Root.Children[1].Brief);
  finally
    R.Root.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDocParserTests);
  TDUnitX.RegisterTestFixture(TMarkdownTests);
  TDUnitX.RegisterTestFixture(TScannerTests);
  TDUnitX.RegisterTestFixture(TXmlDocTests);

end.
