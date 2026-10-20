unit DoxyPas.Gui.Main;

{ VCL front end: edit a Doxyfile (every option of config.xml, by group), run the DoxyPas command line on it and open
  the generated documentation. The form is built in code: the options are data, not hand-drawn controls. }

interface

uses
  System.Classes,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Controls,
  DoxyPas.Config;

type
  TMainForm = class(TForm)
  strict private
    FConfig: TConfig;
    FFileName: string;
    FGroups: TListBox;
    FPanel: TScrollBox;
    FLog: TMemo;
    FRun: TButton;
    FBuilding: Boolean;
    procedure BuildUi;
    procedure ShowGroup(AGroup: Integer);
    procedure GroupClick(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure RunClick(Sender: TObject);
    procedure OpenOutputClick(Sender: TObject);
    procedure EditorChange(Sender: TObject);
    procedure LoadFile(const AFileName: string);
    procedure SaveFile(const AFileName: string);
    procedure RunProcess(const ACommand, ADir: string);
    function CliPath: string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Threading,
  Winapi.Windows,
  Winapi.ShellAPI,
  Vcl.Dialogs,
  DoxyPas.Core.Version,
  DoxyPas.Config.Options,
  DoxyPas.Config.Reader,
  DoxyPas.Config.Writer;

constructor TMainForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'DoxyPas ' + DoxyPasVersion;
  Width := 1100;
  Height := 720;
  Position := poScreenCenter;
  FConfig := TConfig.Create;
  FConfig.PostProcess;
  BuildUi;
  ShowGroup(0);
end;

destructor TMainForm.Destroy;
begin
  FConfig.Free;
  inherited;
end;

procedure TMainForm.BuildUi;
var
  Bar: TPanel;
  Split: TSplitter;
  I: Integer;

  function Btn(const ACaption: string; AHandler: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := Bar;
    Result.Caption := ACaption;
    Result.Align := alLeft;
    Result.Width := 120;
    Result.OnClick := AHandler;
    Result.AlignWithMargins := True;
  end;

begin
  Bar := TPanel.Create(Self);
  Bar.Parent := Self;
  Bar.Align := alTop;
  Bar.Height := 40;
  Bar.BevelOuter := bvNone;
  // buttons are added right to left because of alLeft
  Btn('Open output', OpenOutputClick);
  FRun := Btn('Run', RunClick);
  Btn('Save as...', SaveClick);
  Btn('Open...', OpenClick);
  FLog := TMemo.Create(Self);
  FLog.Parent := Self;
  FLog.Align := alBottom;
  FLog.Height := 180;
  FLog.ReadOnly := True;
  FLog.ScrollBars := ssVertical;
  Split := TSplitter.Create(Self);
  Split.Parent := Self;
  Split.Align := alBottom;
  Split.Height := 5;
  FGroups := TListBox.Create(Self);
  FGroups.Parent := Self;
  FGroups.Align := alLeft;
  FGroups.Width := 200;
  for I := 0 to ConfigGroupCount - 1 do
    FGroups.Items.Add(ConfigGroups[I].Name.Replace('_', ' '));
  FGroups.OnClick := GroupClick;
  FPanel := TScrollBox.Create(Self);
  FPanel.Parent := Self;
  FPanel.Align := alClient;
  FPanel.BorderStyle := bsNone;
  FPanel.VertScrollBar.Tracking := True;
end;

procedure TMainForm.GroupClick(Sender: TObject);
begin
  if FGroups.ItemIndex >= 0 then
    ShowGroup(FGroups.ItemIndex);
end;

procedure TMainForm.ShowGroup(AGroup: Integer);
var
  Opt: TConfigOption;
  Info: TOptionInfo;
  Row: TPanel;
  Lbl: TLabel;
  Ctl: TControl;
  Values: TArray<string>;
  V: string;
  Combo: TComboBox;
begin
  FBuilding := True;
  try
    FGroups.ItemIndex := AGroup;
    while FPanel.ControlCount > 0 do
      FPanel.Controls[0].Free;
    for Opt in FConfig.Options do
    begin
      Info := Opt.Info;
      if (Info.Group <> AGroup) or (Info.Kind = okObsolete) then
        Continue;
      Row := TPanel.Create(FPanel);
      Row.Parent := FPanel;
      Row.Align := alTop;
      Row.BevelOuter := bvNone;
      Row.Height := 30;
      Row.ShowHint := True;
      Row.Hint := Info.Doc.Replace(#10, ' ');
      Row.Top := 100000;
      Lbl := TLabel.Create(Row);
      Lbl.Parent := Row;
      Lbl.SetBounds(8, 7, 260, 16);
      Lbl.Caption := Info.Name;
      Lbl.Hint := Row.Hint;
      Lbl.ShowHint := True;
      case Info.Kind of
        okBool:
          begin
            Ctl := TCheckBox.Create(Row);
            TCheckBox(Ctl).Caption := '';
            TCheckBox(Ctl).Checked := Opt.BoolVal;
            TCheckBox(Ctl).OnClick := EditorChange;
          end;
        okEnum:
          begin
            Combo := TComboBox.Create(Row);
            Combo.Parent := Row;
            Combo.Style := csDropDownList;
            Values := Info.Values.Split(['|']);
            for V in Values do
              Combo.Items.Add(V);
            Combo.ItemIndex := Combo.Items.IndexOf(Opt.Str);
            Combo.OnChange := EditorChange;
            Ctl := Combo;
          end;
        okList:
          begin
            Ctl := TMemo.Create(Row);
            TMemo(Ctl).Lines.Text := string.Join(#13#10, Opt.List.ToArray);
            TMemo(Ctl).ScrollBars := ssVertical;
            TMemo(Ctl).OnChange := EditorChange;
            Row.Height := 72;
          end;
      else
        begin
          Ctl := TEdit.Create(Row);
          if Info.Kind = okInt then
            TEdit(Ctl).Text := IntToStr(Opt.IntVal)
          else
            TEdit(Ctl).Text := Opt.Str;
          TEdit(Ctl).OnChange := EditorChange;
        end;
      end;
      Ctl.Parent := Row;
      Ctl.Tag := Opt.Index + 1;
      Ctl.SetBounds(280, 3, 520, Row.Height - 6);
      if Ctl is TCheckBox then
        Ctl.Width := 24;
      Ctl.Anchors := [akLeft, akTop, akRight];
    end;
  finally
    FBuilding := False;
  end;
end;

procedure TMainForm.EditorChange(Sender: TObject);
var
  Opt: TConfigOption;
  N: Integer;
  Ctl: TControl;
begin
  if FBuilding then
    Exit;
  Ctl := Sender as TControl;
  Opt := FConfig.Options[Ctl.Tag - 1];
  Opt.Raw := '';
  case Opt.Info.Kind of
    okBool: Opt.BoolVal := TCheckBox(Ctl).Checked;
    okInt: if TryStrToInt(Trim(TEdit(Ctl).Text), N) then Opt.IntVal := N;
    okEnum: if TComboBox(Ctl).ItemIndex >= 0 then Opt.Str := TComboBox(Ctl).Text;
    okString: Opt.Str := TEdit(Ctl).Text;
    okList:
      begin
        Opt.List.Clear;
        for N := 0 to TMemo(Ctl).Lines.Count - 1 do
          if Trim(TMemo(Ctl).Lines[N]) <> '' then
            Opt.List.Add(Trim(TMemo(Ctl).Lines[N]));
      end;
  end;
end;

procedure TMainForm.LoadFile(const AFileName: string);
var
  C: TConfig;
begin
  C := TConfig.Create;
  try
    ReadDoxyfile(C, AFileName);
    C.PostProcess;
  except
    C.Free;
    raise;
  end;
  FConfig.Free;
  FConfig := C;
  FFileName := AFileName;
  Caption := 'DoxyPas ' + DoxyPasVersion + ' - ' + AFileName;
  ShowGroup(0);
end;

procedure TMainForm.SaveFile(const AFileName: string);
begin
  TFile.WriteAllText(AFileName, WriteDoxyfile(FConfig, False, False), TEncoding.UTF8);
  FFileName := AFileName;
  Caption := 'DoxyPas ' + DoxyPasVersion + ' - ' + AFileName;
end;

procedure TMainForm.OpenClick(Sender: TObject);
begin
  with TOpenDialog.Create(Self) do
  try
    Filter := 'Doxyfile|*|All files|*.*';
    if Execute then
      LoadFile(FileName);
  finally
    Free;
  end;
end;

procedure TMainForm.SaveClick(Sender: TObject);
begin
  with TSaveDialog.Create(Self) do
  try
    FileName := FFileName;
    if Execute then
      SaveFile(FileName);
  finally
    Free;
  end;
end;

function TMainForm.CliPath: string;
begin
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'DoxyPas.exe');
end;

// Runs a console program and appends its output to the log, without blocking the window.
procedure TMainForm.RunProcess(const ACommand, ADir: string);
begin
  FRun.Enabled := False;
  FLog.Lines.Add('> ' + ACommand);
  TTask.Run(
    procedure
    var
      SA: TSecurityAttributes;
      Rd, Wr: THandle;
      SI: TStartupInfo;
      PI: TProcessInformation;
      Buf: array[0..4095] of AnsiChar;
      N: DWORD;
      Text: string;
      Cmd: string;
    begin
      Cmd := ACommand;
      SA.nLength := SizeOf(SA);
      SA.bInheritHandle := True;
      SA.lpSecurityDescriptor := nil;
      CreatePipe(Rd, Wr, @SA, 0);
      SetHandleInformation(Rd, HANDLE_FLAG_INHERIT, 0);
      ZeroMemory(@SI, SizeOf(SI));
      SI.cb := SizeOf(SI);
      SI.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
      SI.wShowWindow := SW_HIDE;
      SI.hStdOutput := Wr;
      SI.hStdError := Wr;
      if CreateProcess(nil, PChar(Cmd), nil, nil, True, CREATE_NO_WINDOW, nil, PChar(ADir), SI, PI) then
      begin
        CloseHandle(Wr);
        while ReadFile(Rd, Buf, SizeOf(Buf) - 1, N, nil) and (N > 0) do
        begin
          Buf[N] := #0;
          Text := string(UTF8String(Buf));
          TThread.Queue(nil,
            procedure
            begin
              FLog.Lines.Add(Text.TrimRight);
            end);
        end;
        WaitForSingleObject(PI.hProcess, INFINITE);
        CloseHandle(PI.hProcess);
        CloseHandle(PI.hThread);
      end
      else
        TThread.Queue(nil,
          procedure
          begin
            FLog.Lines.Add('Could not start ' + Cmd);
          end);
      CloseHandle(Rd);
      TThread.Queue(nil,
        procedure
        begin
          FLog.Lines.Add('Done.');
          FRun.Enabled := True;
        end);
    end);
end;

procedure TMainForm.RunClick(Sender: TObject);
begin
  if FFileName = '' then
  begin
    SaveClick(Sender);
    if FFileName = '' then
      Exit;
  end
  else
    SaveFile(FFileName);
  if not TFile.Exists(CliPath) then
  begin
    ShowMessage('DoxyPas.exe was not found next to this program.');
    Exit;
  end;
  RunProcess('"' + CliPath + '" "' + FFileName + '"', ExtractFilePath(TPath.GetFullPath(FFileName)));
end;

procedure TMainForm.OpenOutputClick(Sender: TObject);
var
  Dir, Index: string;
begin
  Dir := FConfig.GetString('OUTPUT_DIRECTORY');
  if (Dir = '') or TPath.IsRelativePath(Dir) then
    Dir := TPath.Combine(ExtractFilePath(TPath.GetFullPath(FFileName)), Dir);
  Index := TPath.Combine(TPath.Combine(Dir, FConfig.GetString('HTML_OUTPUT')), 'index.html');
  if TFile.Exists(Index) then
    ShellExecute(0, 'open', PChar(Index), nil, nil, SW_SHOWNORMAL)
  else
    ShowMessage('Not found: ' + Index);
end;

end.
