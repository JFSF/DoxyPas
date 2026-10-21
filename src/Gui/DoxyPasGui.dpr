program DoxyPasGui;

uses
  System.SysUtils,
  Vcl.Forms,
  Vcl.Themes,
  Vcl.Styles,
  DoxyPas.Core.Version in '..\Core\DoxyPas.Core.Version.pas',
  DoxyPas.Core.Log in '..\Core\DoxyPas.Core.Log.pas',
  DoxyPas.Config.Options in '..\Config\DoxyPas.Config.Options.pas',
  DoxyPas.Config in '..\Config\DoxyPas.Config.pas',
  DoxyPas.Config.Reader in '..\Config\DoxyPas.Config.Reader.pas',
  DoxyPas.Config.Writer in '..\Config\DoxyPas.Config.Writer.pas',
  DoxyPas.Gui.Main in 'DoxyPas.Gui.Main.pas';

// the manifest (common controls 6, per-monitor DPI) and the VCL styles of the program (WindowsModern, WindowsModernDark):
// built from Styles.rc by build.bat
{$R Styles.RES}

var
  Main: TMainForm;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, Main);
  if ParamCount > 0 then
    Main.Open(ParamStr(1));              // DoxyPasGui.exe Doxyfile [/run]
  if (ParamCount > 1) and SameText(ParamStr(2), '/run') then
    Main.Run;
  Application.Run;
end.