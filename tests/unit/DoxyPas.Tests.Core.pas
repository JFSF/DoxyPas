unit DoxyPas.Tests.Core;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TCoreTests = class
  public
    [Test]
    procedure VersionIsSemVer;
    [Test]
    procedure FormatMessageWithLocation;
    [Test]
    procedure FormatMessageWithoutLocation;
    [Test]
    procedure InputEncodings;
  end;

implementation

uses
  System.SysUtils,
  System.RegularExpressions,
  DoxyPas.Core.Version,
  DoxyPas.Core.Log,
  DoxyPas.Core.SourceText;

procedure TCoreTests.VersionIsSemVer;
begin
  Assert.IsTrue(TRegEx.IsMatch(DoxyPasVersion, '^\d+\.\d+\.\d+(-[0-9A-Za-z.]+)?$'));
end;

procedure TCoreTests.FormatMessageWithLocation;
begin
  Assert.AreEqual('a.pas:12: warning: oops', FormatMessage(mkWarning, 'a.pas', 12, 'oops'));
end;

procedure TCoreTests.FormatMessageWithoutLocation;
begin
  Assert.AreEqual('error: bad', FormatMessage(mkError, '', 0, 'bad'));
end;

procedure TCoreTests.InputEncodings;
var
  Latin, Utf8, Bom: TBytes;
begin
  Latin := [$63, $E9];                 // "cé" in ISO-8859-1
  Utf8 := [$63, $C3, $A9];            // "cé" in UTF-8
  Bom := [$EF, $BB, $BF, $63, $C3, $A9];
  try
    SetInputEncoding('UTF-8', []);
    Assert.AreEqual('c'#$E9, DecodeSourceBytes(Utf8, 'a.pas'));
    Assert.AreEqual('c'#$E9, DecodeSourceBytes(Bom, 'a.pas'));          // the byte order mark is dropped
    SetInputEncoding('ISO-8859-1', []);
    Assert.AreEqual('c'#$E9, DecodeSourceBytes(Latin, 'a.pas'));
    Assert.AreEqual('c'#$E9, DecodeSourceBytes(Bom, 'a.pas'));           // the byte order mark wins
    // a pattern of INPUT_FILE_ENCODING wins over INPUT_ENCODING
    SetInputEncoding('UTF-8', ['*.pas=ISO-8859-1']);
    Assert.AreEqual('c'#$E9, DecodeSourceBytes(Latin, 'dir\a.pas'));
    Assert.AreEqual('c'#$C3#$A9, DecodeSourceBytes(Utf8, 'dir\a.pas'));
    Assert.AreEqual('c'#$E9, DecodeSourceBytes(Utf8, 'dir\a.inc'));
  finally
    SetInputEncoding('UTF-8', []);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCoreTests);

end.
