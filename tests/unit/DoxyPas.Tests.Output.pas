unit DoxyPas.Tests.Output;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework;

type
  [TestFixture]
  TXmlOutputTests = class
  public
    [Test] procedure GoldenXml;
    [Test] procedure GeneratedFilesAreWellFormed;
    [Test] procedure WriterEscapesTextAndAttributes;
    [Test] procedure LanguageCodes;
    [Test] procedure SchemasAreBundledWithPascalLanguage;
    [Test] procedure RefsAreAutolinkedCaseSensitively;
  end;

  [TestFixture]
  THtmlTemplateTests = class
  public
    [Test] procedure SelectsBlocks;
    [Test] procedure SubstitutesLongestKeyword;
    [Test] procedure ReplacesColorMarkers;
    [Test] procedure HighlightsPascalKeywords;
    [Test] procedure NumbersAndLinksSourceLines;
    [Test] procedure ParsesLayoutFiles;
    [Test] procedure StripsDocComments;
    [Test] procedure FindsBodyEnds;
    [Test] procedure EscapesLatex;
    [Test] procedure QuotesSql;
    [Test] procedure TranslatesTexts;
    [Test] procedure TableOfContentsListsSectionsAndHeadings;
  end;

  [TestFixture]
  TDelphiExtrasTests = class
  public
    [Test] procedure FormBecomesComponentTreePage;
    [Test] procedure BinaryFormIsRejected;
    [Test] procedure ListsThePropertyValues;
    [Test] procedure CollectionItemsAreComponents;
    [Test] procedure BinaryFormGivesTheSamePageAsTheTextForm;
    [Test] procedure DprojGivesSourcesAndDefines;
    [Test] procedure GroupProjIsTheUnionOfItsProjects;
    [Test] procedure LazarusProjectGivesSourcesDefinesAndPaths;
  end;

  [TestFixture]
  TTagFileTests = class
  public
    [Test] procedure RoundTripResolvesExternalReferences;
    [Test] procedure ReadsDoxygenStyleTagFile;
  end;

implementation

uses
  DoxyPas.Output.Translator,
  DoxyPas.Output.SqliteGen,
  DoxyPas.Output.HtmlCode,
  DoxyPas.Output.HtmlDoc,
  DoxyPas.Output.LatexGen,
  DoxyPas.Model.Entry,
  DoxyPas.Lang.Pascal.Dfm,
  DoxyPas.Lang.Project,
  System.Generics.Collections,
  DoxyPas.Output.HtmlTemplate,
  System.Classes,
  System.IOUtils,
  Xml.XMLIntf,
  Xml.XMLDoc,
  Xml.xmldom,
  Xml.omnixmldom,
  DoxyPas.Config,
  DoxyPas.Config.Reader,
  DoxyPas.Model.Defs,
  DoxyPas.Model.Project,
  DoxyPas.Model.Links,
  DoxyPas.Model.Calls,
  DoxyPas.Config.Layout,
  DoxyPas.Build.Pipeline,
  DoxyPas.Output.XmlWriter,
  DoxyPas.Output.XmlGen,
  DoxyPas.Output.TagFile,
  DoxyPas.Resources.Xml;

function GoldenRoot: string;
begin
  Result := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\tests\golden'));
end;

function BuildAt(const ADir, ACaseCfg: string; AStrip: string): TProject;
var
  C: TConfig;
begin
  C := TConfig.Create;
  try
    if ACaseCfg <> '' then
      ReadDoxyfileText(C, ACaseCfg, 'case.cfg');
    C.Find('INPUT').List.Clear;
    C.Find('INPUT').List.Add(ADir);
    if AStrip <> '' then
    begin
      C.Find('STRIP_FROM_PATH').List.Clear;
      C.Find('STRIP_FROM_PATH').List.Add(AStrip);
    end;
    C.PostProcess;
    Result := BuildProject(C, CollectInputFiles(C), False);
  finally
    C.Free;
  end;
end;

function ConfigFor(const ACaseCfg: string): TConfig;
begin
  Result := TConfig.Create;
  if ACaseCfg <> '' then
    ReadDoxyfileText(Result, ACaseCfg, 'case.cfg');
  Result.PostProcess;
end;

{ Generates the XML of the model case ACase into a fresh temp directory (returned). }
function GenerateCase(const ACase: string; out AOut: string): string;
var
  Root, Dir, Cfg: string;
  P: TProject;
  C: TConfig;
begin
  Root := TPath.Combine(GoldenRoot, 'model');
  Dir := TPath.Combine(Root, ACase);
  Cfg := '';
  if TFile.Exists(TPath.Combine(Dir, 'case.cfg')) then
    Cfg := TFile.ReadAllText(TPath.Combine(Dir, 'case.cfg'));
  P := BuildAt(Dir, Cfg, Root);
  C := ConfigFor(Cfg);
  try
    AOut := TPath.Combine(TPath.GetTempPath, 'doxypas_xml_' + ACase + '_' + TGuid.NewGuid.ToString.Substring(1, 8));
    GenerateXml(P, C, AOut);
    Result := AOut;
  finally
    C.Free;
    P.Free;
  end;
end;

{ TXmlOutputTests }

procedure TXmlOutputTests.GoldenXml;
var
  Case_, OutDir, F, Expected: string;
  Update: Boolean;
  Actual: string;
begin
  Update := GetEnvironmentVariable('DOXYPAS_UPDATE_GOLDEN') = '1';
  for Case_ in ['inherit', 'impl', 'docs'] do
  begin
    GenerateCase(Case_, OutDir);
    try
      for F in TDirectory.GetFiles(OutDir, '*.xml') do
      begin
        Expected := TPath.Combine(TPath.Combine(TPath.Combine(GoldenRoot, 'xml'), Case_), ExtractFileName(F));
        Actual := TFile.ReadAllText(F, TEncoding.UTF8).Replace(#13#10, #10);
        if Update then
        begin
          TDirectory.CreateDirectory(ExtractFilePath(Expected));
          TFile.WriteAllText(Expected, Actual, TUTF8Encoding.Create(False));
        end
        else
          Assert.AreEqual(TFile.ReadAllText(Expected, TEncoding.UTF8).Replace(#13#10, #10), Actual,
            Case_ + '/' + ExtractFileName(F));
      end;
    finally
      TDirectory.Delete(OutDir, True);
    end;
  end;
end;

procedure TXmlOutputTests.GeneratedFilesAreWellFormed;
var
  OutDir, F: string;
  Doc: IXMLDocument;
  Count: Integer;
begin
  DefaultDOMVendor := sOmniXmlVendor;
  GenerateCase('docs', OutDir);
  try
    Count := 0;
    for F in TDirectory.GetFiles(OutDir, '*.xml') do
    begin
      Doc := NewXMLDocument;
      Doc.LoadFromFile(F); // raises on malformed XML
      Assert.IsNotNull(Doc.DocumentElement);
      Inc(Count);
    end;
    Assert.IsTrue(Count >= 5);
    Assert.IsTrue(TFile.Exists(TPath.Combine(OutDir, 'index.xml')));
    Assert.IsTrue(TFile.Exists(TPath.Combine(OutDir, 'compound.xsd')));
  finally
    TDirectory.Delete(OutDir, True);
  end;
end;

procedure TXmlOutputTests.WriterEscapesTextAndAttributes;
var
  W: TXmlWriter;
begin
  W := TXmlWriter.Create;
  try
    W.Open('a', ['x', 'say "hi" & <go>']);
    W.Text('1 < 2 & 3 > 2');
    W.Empty('b', ['k', 'v']);
    W.Close('a');
    Assert.AreEqual('<a x="say &quot;hi&quot; &amp; &lt;go&gt;">1 &lt; 2 &amp; 3 &gt; 2<b k="v"/></a>', W.ToString);
  finally
    W.Free;
  end;
  Assert.AreEqual('yes', YesNo(True));
  Assert.AreEqual('ab', XmlEscape('a'#1'b')); // control characters are not allowed in XML
end;

procedure TXmlOutputTests.LanguageCodes;
begin
  Assert.AreEqual('en-US', XmlLanguageCode('English'));
  Assert.AreEqual('pt-PT', XmlLanguageCode('portuguese'));
  Assert.AreEqual('en-US', XmlLanguageCode('Klingon'));
end;

procedure TXmlOutputTests.SchemasAreBundledWithPascalLanguage;
begin
  Assert.IsTrue(XmlResource('compound.xsd').Contains('<xsd:enumeration value="Pascal" />'));
  Assert.IsTrue(XmlResource('index.xsd').Contains('doxygenindex'));
  Assert.IsTrue(XmlResource('xml.xsd').Length > 100);
end;

procedure TXmlOutputTests.RefsAreAutolinkedCaseSensitively;
var
  Dir: string;
  S: string;
begin
  GenerateCase('docs', Dir);
  try
    S := TFile.ReadAllText(TPath.Combine(Dir, 'class_docs_1_1_t_base.xml'), TEncoding.UTF8);
    // "Base with docs." must not link the unit "Docs"
    Assert.IsTrue(S.Contains('Base with docs.'));
    S := TFile.ReadAllText(TPath.Combine(Dir, 'indexpage.xml'), TEncoding.UTF8);
    Assert.IsTrue(S.Contains('<ref refid="class_docs_1_1_t_base" kindref="compound">TBase</ref>'));
    Assert.IsTrue(S.Contains('<ref refid="group__core" kindref="compound">core</ref>'));
  finally
    TDirectory.Delete(Dir, True);
  end;
end;

{ TTagFileTests }

procedure TTagFileTests.RoundTripResolvesExternalReferences;
var
  Root, Dir, Tag: string;
  P, Other: TProject;
  Links: TLinkResolver;
  T: TLinkTarget;
begin
  Root := TPath.Combine(GoldenRoot, 'model');
  Dir := TPath.Combine(Root, 'inherit');
  P := BuildAt(Dir, TFile.ReadAllText(TPath.Combine(Dir, 'case.cfg')), Root);
  Tag := TPath.Combine(TPath.GetTempPath, 'doxypas_' + TGuid.NewGuid.ToString.Substring(1, 8) + '.tag');
  try
    WriteTagFile(P, Tag);
    Assert.IsTrue(TFile.ReadAllText(Tag).Contains('<compound kind="class">'));
    Assert.IsTrue(TFile.ReadAllText(Tag).Contains('<name>Circles.TCircle</name>'));
    // a project that only has the tag file
    Other := BuildAt(TPath.Combine(Root, 'docs'), TFile.ReadAllText(TPath.Combine(Root, 'docs\case.cfg')), Root);
    try
      ReadTagFile(Other, Tag, 'http://example.org/doc');
      Links := TLinkResolver.Create(Other);
      try
        T := Links.Resolve('Shapes.TShape', nil);
        Assert.IsTrue(T.Resolved);
        Assert.IsTrue(T.External);
        Assert.AreEqual('http://example.org/doc/class_shapes_1_1_t_shape.html', T.Url);
        T := Links.Resolve('TShape', nil); // by its short name too
        Assert.IsTrue(T.External);
        T := Links.Resolve('TCircle.Area', nil);
        Assert.IsTrue(T.External);
        Assert.IsTrue(T.Url.Contains('#a'));
        Assert.IsFalse(Links.Resolve('NoSuchThing', nil).Resolved);
      finally
        Links.Free;
      end;
    finally
      Other.Free;
    end;
  finally
    if TFile.Exists(Tag) then
      TFile.Delete(Tag);
    P.Free;
  end;
end;

procedure TTagFileTests.ReadsDoxygenStyleTagFile;
const
  TagText = '<?xml version=''1.0'' encoding=''UTF-8'' standalone=''yes'' ?>'#10 +
    '<tagfile doxygen_version="1.9.8">'#10 +
    '  <compound kind="class"><name>ns::Foo</name><filename>classns_1_1Foo.html</filename>'#10 +
    '    <member kind="function"><type>int</type><name>bar</name><anchorfile>classns_1_1Foo.html</anchorfile>'#10 +
    '      <anchor>abc</anchor><arglist>(int)</arglist></member></compound>'#10 +
    '  <compound kind="page"><name>intro</name><title>Intro</title><filename>intro</filename>'#10 +
    '    <docanchor file="intro.html">lbl</docanchor></compound>'#10 +
    '</tagfile>';
var
  P: TProject;
  Tag: string;
  Links: TLinkResolver;
  Count: Integer;
begin
  Tag := TPath.Combine(TPath.GetTempPath, 'doxypas_' + TGuid.NewGuid.ToString.Substring(1, 8) + '.tag');
  TFile.WriteAllText(Tag, TagText, TEncoding.UTF8);
  P := TProject.Create(TProjectOptions.Default);
  try
    Count := ReadTagFile(P, Tag, '../other');
    Assert.AreEqual<Integer>(4, Count);
    Links := TLinkResolver.Create(P);
    try
      Assert.AreEqual('../other/classns_1_1Foo.html', Links.Resolve('ns::Foo', nil).Url);
      Assert.AreEqual('../other/classns_1_1Foo.html#abc', Links.Resolve('Foo::bar()', nil).Url);
      Assert.AreEqual('../other/intro.html', Links.Resolve('intro', nil).Url);
      Assert.AreEqual('../other/intro.html#lbl', Links.Resolve('lbl', nil).Url);
    finally
      Links.Free;
    end;
  finally
    P.Free;
    TFile.Delete(Tag);
  end;
end;

{ THtmlTemplateTests }

procedure THtmlTemplateTests.SelectsBlocks;
var
  B: TDictionary<string, Boolean>;
begin
  B := TDictionary<string, Boolean>.Create;
  try
    B.Add('A', True);
    B.Add('B', False);
    Assert.AreEqual('1 3 4',
      SelectBlocks('1<!--BEGIN A--> 3<!--END A--><!--BEGIN B-->X<!--END B--><!--BEGIN !B--> 4<!--END !B-->', B));
  finally
    B.Free;
  end;
end;

procedure THtmlTemplateTests.SubstitutesLongestKeyword;
var
  K: TDictionary<string, string>;
begin
  K := TDictionary<string, string>.Create;
  try
    K.Add('$search', 'S');
    K.Add('$searchbox', 'SB');
    Assert.AreEqual('SB S', SubstituteKeywords('$searchbox $search', K));
  finally
    K.Free;
  end;
end;

procedure THtmlTemplateTests.ReplacesColorMarkers;
var
  C: THtmlColors;
begin
  C := THtmlColors.Parse('LIGHT', 220, 100, 80);
  Assert.AreEqual('color:#ffffff;', ReplaceColorMarkers('color:##FF;', C));
end;

procedure THtmlTemplateTests.HighlightsPascalKeywords;
begin
  Assert.AreEqual('<div class="line"><span class="keywordflow">if</span> X <span class="keywordflow">then</span> ' +
    '<span class="stringliteral">''a''</span> <span class="comment">// c</span></div>',
    HighlightPascal('if X then ''a'' // c'));
end;

procedure THtmlTemplateTests.NumbersAndLinksSourceLines;
var
  Html: string;
begin
  Html := HighlightSource('A'#10'if B', True,
    function(const AWord: string): string
    begin
      if AWord = 'B' then
        Result := 'b.html'
      else
        Result := '';
    end);
  Assert.Contains(Html, '<a id="l00002" name="l00002"></a><span class="lineno">&#160;&#160;&#160;&#160;2</span>');
  Assert.Contains(Html, '<a class="code" href="b.html">B</a>');
  Assert.IsFalse(Html.Contains('href="b.html">A<'));
end;

procedure THtmlTemplateTests.ParsesLayoutFiles;
var
  Root: TLayoutEntry;
begin
  Root := ParseLayoutText('<?xml version="1.0"?><!-- c --><doxygenlayout version="2.0"><navindex>' +
    '<tab type="classes" title="T&#231;&amp;"><tab type="classlist" visible="no"/></tab></navindex>' +
    '<class><memberdecl><publicmethods title="M"/></memberdecl></class></doxygenlayout>');
  try
    Assert.AreEqual('doxygenlayout', Root.Name);
    Assert.AreEqual('classes', Root.Child('navindex').Children[0].Attr('type'));
    Assert.AreEqual('T'#231'&', Root.Child('navindex').Children[0].Attr('title'));
    Assert.AreEqual('no', Root.Child('navindex').Children[0].Children[0].Attr('visible'));
    Assert.AreEqual('M', Root.Child('class').Child('memberdecl').Child('publicmethods').Attr('title'));
    Assert.IsNull(Root.Child('file'));
  finally
    Root.Free;
  end;
end;

procedure THtmlTemplateTests.StripsDocComments;
var
  Html: string;
begin
  Html := HighlightSource('/// doc'#10'X; // keep'#10'{** a'#10'b *}'#10'Y', True, nil, 1, True);
  Assert.IsFalse(Html.Contains('doc'));
  Assert.IsFalse(Html.Contains('{**'));
  Assert.Contains(Html, '// keep');
  Assert.Contains(Html, 'lineno">&#160;&#160;&#160;&#160;5');
end;

procedure THtmlTemplateTests.FindsBodyEnds;
var
  Src: TArray<string>;
begin
  Src := ['procedure A;', 'var R: record X: Integer; end;', 'procedure Local;', 'begin', '  X;', 'end;', 'begin',
    '  try', '    Y(''end'');  // end', '  finally', '    Z;', '  end;', 'end;', 'procedure B;', 'begin', 'end;'];
  Assert.AreEqual(13, FindBodyEnd(Src, 1, 13), 'local routine, record, try/finally, string and comment');
  Assert.AreEqual(16, FindBodyEnd(Src, 14, 16));
  Assert.AreEqual(-1, FindBodyEnd(['function F: Integer; external ''x.dll'';'], 1, 1), 'external');
end;
procedure THtmlTemplateTests.EscapesLatex;
begin
  Assert.AreEqual('a\_b \& 50\%', LatexEscape('a_b & 50%'));
end;

procedure THtmlTemplateTests.QuotesSql;
begin
  Assert.AreEqual('NULL', SqlText(''));
  Assert.AreEqual('''it''''s''', SqlText('it''s'));
end;

procedure THtmlTemplateTests.TableOfContentsListsSectionsAndHeadings;
var
  P: TProject;
  L: TLinkResolver;
  W: THtmlDocWriter;
  H: string;
begin
  P := TProject.Create(TProjectOptions.Default);
  L := TLinkResolver.Create(P);
  W := THtmlDocWriter.Create(L, '.html');
  try
    W.TocHeadings := 2;
    H := W.Render('\tableofcontents'#10#10'<h1>One</h1>'#10'<h3>Deep</h3>'#10'\section s1 Sec'#10'text', nil);
    Assert.Contains(H, '<div class="toc">');
    Assert.Contains(H, '<a href="#autotoc_md0">One</a>');
    Assert.Contains(H, '<a href="#s1">Sec</a>');
    Assert.IsFalse(H.Contains('>Deep</a></li>'), 'the headings deeper than TOC_INCLUDE_HEADINGS are not listed');
    Assert.IsFalse(W.Render('<h1>One</h1>', nil).Contains('class="toc"'));
    W.GithubIds := True;
    H := W.Render('\tableofcontents'#10#10'<h1>Hello, World!</h1>'#10'<h2>Hello, World!</h2>', nil);
    Assert.Contains(H, 'href="#hello-world"');
    Assert.Contains(H, 'href="#hello-world-1"');
  finally
    W.Free;
    L.Free;
    P.Free;
  end;
end;

procedure THtmlTemplateTests.TranslatesTexts;
begin
  SetOutputLanguage('English');
  Assert.AreEqual('Public Methods', TrSection('Public', 'Methods'));
  Assert.AreEqual('Strict Private Class Fields', TrSection('Strict Private', 'Class Fields'));
  SetOutputLanguage('Portuguese');
  try
    Assert.AreEqual('Página Principal', Tr('Main Page'));
    Assert.AreEqual('Campos (visibilidade privada)', TrSection('Private', 'Fields'));
    Assert.AreEqual('untranslated text', Tr('untranslated text'));
    Assert.AreEqual('pt', LanguageIso);
  finally
    SetOutputLanguage('English');
  end;
  // the languages that come from resources\lang
  SetOutputLanguage('Russian');
  try
    Assert.AreEqual('Главная страница', Tr('Main Page'));
    Assert.AreEqual('Определение в строке 3 файла a.pas.', Format(Tr('Definition at line %d of file %s.'), [3, 'a.pas']));
    Assert.AreEqual('ru', LanguageIso);
  finally
    SetOutputLanguage('English');
  end;
end;

{ TDelphiExtrasTests }

procedure TDelphiExtrasTests.FormBecomesComponentTreePage;
var
  F, Err: string;
  E: TEntry;
begin
  F := TPath.Combine(TPath.GetTempPath, 'dp_t1.dfm');
  TFile.WriteAllText(F, 'object F: TF'#13#10'  Caption = ''Hi'''#13#10'  object B: TButton'#13#10 +
    '    OnClick = BClick'#13#10'    Items = ('#13#10'      ''a'')'#13#10'  end'#13#10'end'#13#10);
  try
    E := ParseDfmFile(F, Err);
    try
      Assert.IsNotNull(E, Err);
      Assert.AreEqual('form_dp_t1', E.Name);
      Assert.IsTrue(E.Doc.Contains('<b>B</b>: TButton'));
      Assert.IsTrue(E.Doc.Contains('OnClick = BClick'));
    finally
      E.Free;
    end;
  finally
    TFile.Delete(F);
  end;
end;

procedure TDelphiExtrasTests.ListsThePropertyValues;
var
  F, Err: string;
  E: TEntry;
begin
  F := TPath.Combine(TPath.GetTempPath, 'dp_t5.dfm');
  TFile.WriteAllText(F, 'object F: TF'#13#10'  Caption = ''Main '' +'#13#10'    ''window'''#13#10'  Left = 8'#13#10 +
    '  object M: TMemo'#13#10'    Lines.Strings = ('#13#10'      ''one'''#13#10'      ''it''#39''s'')'#13#10'    Data = {'#13#10'      0A0B}'#13#10 +
    '    Cols = <'#13#10'      item'#13#10'      end'#13#10'      item'#13#10'      end>'#13#10'  end'#13#10'end'#13#10);
  try
    E := ParseDfmFile(F, True, Err);
    try
      Assert.IsNotNull(E, Err);
      Assert.Contains(E.Doc, 'Left = 8');
      Assert.Contains(E.Doc, 'TF "Main window"', 'caption of the form, string continued on the next line');
      Assert.Contains(E.Doc, 'Lines.Strings = ''[one / it''s]''');
      Assert.Contains(E.Doc, 'Data = (binary data)');
      Assert.Contains(E.Doc, '<b>Cols</b>: collection');
      Assert.Contains(E.Doc, '<b>Cols[1]</b>: item');
    finally
      E.Free;
    end;
    E := ParseDfmFile(F, False, Err);
    try
      Assert.IsFalse(E.Doc.Contains('Left = 8'), 'without PASCAL_DFM_PROPERTIES');
      Assert.Contains(E.Doc, 'Main window');
    finally
      E.Free;
    end;
  finally
    TFile.Delete(F);
  end;
end;
procedure TDelphiExtrasTests.CollectionItemsAreComponents;
var
  F, Err: string;
  E: TEntry;
begin
  F := TPath.Combine(TPath.GetTempPath, 'dp_t6.dfm');
  TFile.WriteAllText(F, 'object F: TF'#13#10'  object G: TGrid'#13#10'    Columns = <'#13#10'      item'#13#10'        Title.Caption = ''A'''#13#10 +
    '        Width = 50'#13#10'      end'#13#10'      item'#13#10'        Title.Caption = ''B'''#13#10'      end>'#13#10'    OnClick = GClick'#13#10 +
    '  end'#13#10'end'#13#10);
  try
    E := ParseDfmFile(F, True, Err);
    try
      Assert.IsNotNull(E, Err);
      Assert.Contains(E.Doc, '<b>G.Columns</b>'.Replace('G.', ''));
      Assert.Contains(E.Doc, '<b>Columns[0]</b>: item');
      Assert.Contains(E.Doc, 'Width = 50');
      Assert.Contains(E.Doc, '<b>Columns[1]</b>: item "B"'.Replace(' "B"', ''));
      Assert.Contains(E.Doc, 'OnClick = GClick');
    finally
      E.Free;
    end;
  finally
    TFile.Delete(F);
  end;
end;

procedure TDelphiExtrasTests.BinaryFormGivesTheSamePageAsTheTextForm;
var
  Txt, Bin: string;
  Src, Dst: TFileStream;
  A, B: TEntry;
  Err: string;
begin
  Txt := TPath.Combine(TPath.GetTempPath, 'dp_t7.dfm');
  Bin := TPath.Combine(TPath.GetTempPath, 'dp_t7b.dfm');
  TFile.WriteAllText(Txt, 'object F: TF'#13#10'  Left = 0'#13#10'  Caption = ''Hi '' +'#13#10'    ''there'''#13#10'  Scale = 1.5'#13#10 +
    '  Font.Style = [fsBold, fsItalic]'#13#10'  Big = 123456789012'#13#10'  Lines.Strings = ('#13#10'    ''a'''#13#10'    ''b'')'#13#10 +
    '  Data = {'#13#10'    0A0B}'#13#10'  OnCreate = FCreate'#13#10'  Flag = True'#13#10'  object B: TB'#13#10'    Caption = ''caf''#233'#13#10 +
    '    Items = <'#13#10'      item'#13#10'        Text = ''x'''#13#10'      end>'#13#10'  end'#13#10'end'#13#10);
  Src := TFileStream.Create(Txt, fmOpenRead);
  Dst := TFileStream.Create(Bin, fmCreate);
  try
    ObjectTextToBinary(Src, Dst);
  finally
    Dst.Free;
    Src.Free;
  end;
  try
    A := ParseDfmFile(Txt, True, Err);
    B := ParseDfmFile(Bin, True, Err);
    try
      Assert.IsNotNull(A);
      Assert.IsNotNull(B, Err);
      Assert.AreEqual(A.Doc.Replace('dp_t7.dfm', ''), B.Doc.Replace('dp_t7b.dfm', ''));
    finally
      B.Free;
      A.Free;
    end;
  finally
    TFile.Delete(Bin);
    TFile.Delete(Txt);
  end;
end;
procedure TDelphiExtrasTests.BinaryFormIsRejected;
var
  F, Err: string;
begin
  F := TPath.Combine(TPath.GetTempPath, 'dp_t2.dfm');
  TFile.WriteAllText(F, 'TPF0'#0'junk');
  try
    Assert.IsNull(ParseDfmFile(F, Err));
    Assert.AreNotEqual('', Err);
  finally
    TFile.Delete(F);
  end;
end;

procedure TDelphiExtrasTests.DprojGivesSourcesAndDefines;
var
  F: string;
  P: TDelphiProject;
begin
  F := TPath.Combine(TPath.GetTempPath, 'dp_t3.dproj');
  TFile.WriteAllText(F, '<Project><PropertyGroup Condition="''$(Base)''!=''''"><DCC_Define>FOO;$(DCC_Define)</DCC_Define>' +
    '</PropertyGroup><PropertyGroup Condition="''$(Cfg_1)''!=''''"><DCC_Define>DEBUGONLY</DCC_Define></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="a.pas"/><DCCReference Include="b.res"/></ItemGroup></Project>');
  try
    P := ReadDelphiProject(F);
    Assert.AreEqual(1, Integer(Length(P.Sources)));
    Assert.AreEqual(1, Integer(Length(P.Defines)));
    Assert.AreEqual('FOO', P.Defines[0]);
  finally
    TFile.Delete(F);
  end;
end;

procedure TDelphiExtrasTests.GroupProjIsTheUnionOfItsProjects;
var
  D: string;
  P: TDelphiProject;
begin
  D := TPath.Combine(TPath.GetTempPath, 'dp_group');
  TDirectory.CreateDirectory(D);
  TFile.WriteAllText(TPath.Combine(D, 'a.dproj'), '<Project><PropertyGroup><DCC_Define>AAA</DCC_Define></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="a.pas"/></ItemGroup></Project>');
  TFile.WriteAllText(TPath.Combine(D, 'b.dproj'), '<Project><PropertyGroup><DCC_Define>BBB;AAA</DCC_Define></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="a.pas"/><DCCReference Include="b.pas"/></ItemGroup></Project>');
  TFile.WriteAllText(TPath.Combine(D, 'g.groupproj'), '<Project><ItemGroup><Projects Include="a.dproj"><Dependencies/></Projects>' +
    '<Projects Include="b.dproj"/></ItemGroup></Project>');
  try
    P := ReadDelphiProject(TPath.Combine(D, 'g.groupproj'));
    Assert.AreEqual(2, Integer(Length(P.Sources)), 'a.pas is listed once');
    Assert.AreEqual(2, Integer(Length(P.Defines)), 'AAA is listed once');
  finally
    TDirectory.Delete(D, True);
  end;
end;

procedure TDelphiExtrasTests.LazarusProjectGivesSourcesDefinesAndPaths;
var
  F: string;
  P: TDelphiProject;
begin
  F := TPath.Combine(TPath.GetTempPath, 'dp_t4.lpi');
  TFile.WriteAllText(F, '<CONFIG><ProjectOptions><Units Count="3"><Unit0><Filename Value="p.lpr"/><IsPartOfProject Value="True"/></Unit0>' +
    '<Unit1><Filename Value="u1.pas"/><IsPartOfProject Value="True"/></Unit1><Unit2><Filename Value="u2.pas"/></Unit2></Units>' +
    '</ProjectOptions><CompilerOptions><SearchPaths><OtherUnitFiles Value="lib;$(LazarusDir)/x"/></SearchPaths>' +
    '<Other><CustomOptions Value="-dFOO -O2 -dBAR"/></Other></CompilerOptions></CONFIG>');
  try
    P := ReadDelphiProject(F);
    Assert.AreEqual(3, Integer(Length(P.Sources)));
    Assert.AreEqual(2, Integer(Length(P.Defines)));
    Assert.AreEqual('FOO', P.Defines[0]);
    Assert.AreEqual(1, Integer(Length(P.SearchPaths)), 'macros are skipped');
  finally
    TFile.Delete(F);
  end;
end;
initialization
  TDUnitX.RegisterTestFixture(TXmlOutputTests);
  TDUnitX.RegisterTestFixture(TTagFileTests);
  TDUnitX.RegisterTestFixture(THtmlTemplateTests);
  TDUnitX.RegisterTestFixture(TDelphiExtrasTests);

end.
