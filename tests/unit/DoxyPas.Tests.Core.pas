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
  end;

implementation

uses
  System.SysUtils,
  System.RegularExpressions,
  DoxyPas.Core.Version,
  DoxyPas.Core.Log;

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

initialization
  TDUnitX.RegisterTestFixture(TCoreTests);

end.
