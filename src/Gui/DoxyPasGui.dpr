program DoxyPasGui;

uses
  Vcl.Forms,
  DoxyPas.Core.Version in '..\Core\DoxyPas.Core.Version.pas',
  DoxyPas.Core.Log in '..\Core\DoxyPas.Core.Log.pas',
  DoxyPas.Config.Options in '..\Config\DoxyPas.Config.Options.pas',
  DoxyPas.Config in '..\Config\DoxyPas.Config.pas',
  DoxyPas.Config.Reader in '..\Config\DoxyPas.Config.Reader.pas',
  DoxyPas.Config.Writer in '..\Config\DoxyPas.Config.Writer.pas',
  DoxyPas.Gui.Main in 'DoxyPas.Gui.Main.pas';

var
  Main: TMainForm;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, Main);
  Application.Run;
end.
