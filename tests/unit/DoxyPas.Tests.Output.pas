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
    [Test] procedure EscapesLatex;
  end;

  [TestFixture]
  TDelphiExtrasTests = class
  public
    [Test] procedure FormBecomesComponentTreePage;
    [Test] procedure BinaryFormIsRejected;
    [Test] procedure DprojGivesSourcesAndDefines;
  end;

  [TestFixture]
  TTagFileTests = class
  public
    [Test] procedure RoundTripResolvesExternalReferences;
    [Test] procedure ReadsDoxygenStyleTagFile;
  end;

implementation

uses
  DoxyPas.Output.HtmlCode,
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

procedure THtmlTemplateTests.EscapesLatex;
begin
  Assert.AreEqual('a\_b \& 50\%', LatexEscape('a_b & 50%'));
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

initialization
  TDUnitX.RegisterTestFixture(TXmlOutputTests);
  TDUnitX.RegisterTestFixture(TTagFileTests);
  TDUnitX.RegisterTestFixture(THtmlTemplateTests);
  TDUnitX.RegisterTestFixture(TDelphiExtrasTests);

end.
