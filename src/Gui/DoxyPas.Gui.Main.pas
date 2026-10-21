unit DoxyPas.Gui.Main;

{ VCL front end: edit a Doxyfile (every option of config.xml, by group), run the DoxyPas command line on it and open
  the generated documentation. The form is built in code: the options are data, not hand-drawn controls. Only the
  components of the VCL are used (VCL styles, WinX controls), so that the project builds on any Delphi without extra
  packages. }

interface

uses
  System.Classes,
  System.Types,
  System.UITypes,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.ImgList,
  Vcl.ImageCollection,
  Vcl.VirtualImageList,
  Vcl.WinXCtrls,
  DoxyPas.Config;

type
  TMainForm = class(TForm)
  strict private
    FConfig: TConfig;
    FFileName: string;
    FModified: Boolean;
    FBuilding: Boolean;
    FGroups: TListBox;
    FTitle, FSubtitle: TLabel;
    FScroll: TScrollBox;
    FSearch: TSearchBox;
    FSearchTimer: TTimer;
    FTheme: TButton;
    FDarkMode: Boolean;
    FRun: TButton;
    FLog: TMemo;
    FBusy: TActivityIndicator;
    FStatus: TStatusBar;
    FIcons: TVirtualImageList;      // the icons of the buttons, from the PNG images of FImages
    FImages: TImageCollection;
    FProcess: THandle;
    FStopping: Boolean;
    FCurrentGroup: Integer;
    function Sc(AValue: Integer): Integer;
    procedure BuildUi;
    procedure BuildIcons;
    procedure ApplyTheme;
    procedure SetDarkTheme(ADark: Boolean);
    procedure ShowOptions;
    procedure AddRow(AOpt: TConfigOption);
    procedure UpdateEnabled;
    procedure UpdateCaption;
    procedure SetModified(AValue: Boolean);
    function GroupHasChanges(AGroup: Integer): Boolean;
    procedure GroupClick(Sender: TObject);
    procedure GroupDraw(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure SearchChange(Sender: TObject);
    procedure SearchTimer(Sender: TObject);
    procedure DarkClick(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure RunClick(Sender: TObject);
    procedure OpenOutputClick(Sender: TObject);
    procedure ClearLogClick(Sender: TObject);
    procedure BrowseClick(Sender: TObject);
    procedure EditorChange(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure LoadFile(const AFileName: string);
    function SaveFile(const AFileName: string): Boolean;
    function SaveAs: Boolean;
    function OutputIndex: string;
    procedure Log(const AText: string);
    procedure RunProcess(const ACommand, ADir: string);
    procedure ProcessEnded;
    function CliPath: string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    /// <summary>Opens a Doxyfile (the command line argument of the program).</summary>
    procedure Open(const AFileName: string);
    /// <summary>Does what the Run button does.</summary>
    procedure Run;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Math,
  System.StrUtils,
  System.Threading,
  System.Win.Registry,
  Winapi.Windows,
  Winapi.ShellAPI,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
  Vcl.Dialogs,
  Vcl.Themes,
  Vcl.Styles,
  DoxyPas.Core.Version,
  DoxyPas.Config.Options,
  DoxyPas.Config.Reader,
  DoxyPas.Config.Writer;

const
  // glyphs of the icon font of Windows (Segoe Fluent Icons / Segoe MDL2 Assets)
  GlyphOpen = $E8E5;
  GlyphSave = $E74E;
  GlyphRun = $E768;
  GlyphStop = $E71A;
  GlyphWeb = $E774;
  GlyphFolder = $E712;
  GlyphTheme = $E793;
  IconOpen = 0;
  IconSave = 1;
  IconRun = 2;
  IconStop = 3;
  IconWeb = 4;
  IconBrowse = 5;
  IconTheme = 6;

type
  /// <summary>One option: its name and a line of explanation on the left, the editor on the right.</summary>
  TOptionRow = class(TPanel)
  strict private
    FSplit: Integer;
  public
    NameLabel, DescLabel: TLabel;
    Editor: TWinControl;
    Browse: TButton;
    Line: TPanel;
    Depends: string;
    PPI: Integer;
    procedure Resize; override;
  end;

procedure TOptionRow.Resize;
var
  S, W: Integer;
begin
  inherited;
  if (NameLabel = nil) or (Editor = nil) then
    Exit;
  S := MulDiv(1, PPI, 96);
  FSplit := Max(MulDiv(Width, 42, 100), 220 * S);
  NameLabel.SetBounds(16 * S, 9 * S, FSplit - 28 * S, NameLabel.Height);
  DescLabel.SetBounds(16 * S, NameLabel.Top + NameLabel.Height + 2 * S, FSplit - 28 * S, DescLabel.Height);
  W := Width - FSplit - 24 * S;
  if Browse <> nil then
  begin
    Browse.SetBounds(Width - 24 * S - 36 * S, Editor.Top, 36 * S, Min(Editor.Height, 27 * S));      // not as tall as a list
    Dec(W, 42 * S);
  end;
  if Editor is TToggleSwitch then
    Editor.Left := FSplit
  else
    Editor.SetBounds(FSplit, Editor.Top, Max(W, 80 * S), Editor.Height);
end;

{ TMainForm }

constructor TMainForm.Create(AOwner: TComponent);
var
  R: TRegistry;
  Light: Boolean;
begin
  inherited CreateNew(AOwner);
  PixelsPerInch := 96;                         // the sizes below are for 96 dpi; the form is scaled at the end
  Caption := 'DoxyPas ' + DoxyPasVersion;
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  Position := poScreenCenter;
  Width := 1180;
  Height := 780;
  Constraints.MinWidth := 820;
  Constraints.MinHeight := 520;
  OnCloseQuery := FormCloseQuery;
  FConfig := TConfig.Create;
  FConfig.PostProcess;
  // light or dark like the apps of Windows
  Light := True;
  R := TRegistry.Create(KEY_READ);
  try
    R.RootKey := HKEY_CURRENT_USER;
    if R.OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize') and R.ValueExists('AppsUseLightTheme') then
      Light := R.ReadInteger('AppsUseLightTheme') <> 0;
  finally
    R.Free;
  end;
  SetDarkTheme(not Light);
  FDarkMode := not Light;
  BuildUi;
  ScaleForPPI(Screen.PixelsPerInch);
  ShowOptions;
end;

destructor TMainForm.Destroy;
begin
  FSearchTimer.Free;
  FConfig.Free;
  inherited;
end;

// The size in pixels of a size designed for 96 dpi.
function TMainForm.Sc(AValue: Integer): Integer;
begin
  Result := MulDiv(AValue, CurrentPPI, 96);
end;

procedure TMainForm.SetDarkTheme(ADark: Boolean);
var
  Name, Pick: string;
begin
  Pick := '';
  for Name in TStyleManager.StyleNames do
    if ContainsText(Name, 'Modern') and (ContainsText(Name, 'Dark') = ADark) and
       not ContainsText(Name, 'Blue') and not ContainsText(Name, 'Green') and not ContainsText(Name, 'Purple') and
       not ContainsText(Name, 'Slate') then
      Pick := Name;
  if Pick <> '' then
    TStyleManager.TrySetStyle(Pick, False);
end;

// The icons are glyphs of the icon font of Windows drawn in the colour of the text of the theme.
procedure TMainForm.BuildIcons;
const
  Codes: array[0..6] of Integer = (GlyphOpen, GlyphSave, GlyphRun, GlyphStop, GlyphWeb, GlyphFolder, GlyphTheme);
var
  I, X, Y, A, Size: Integer;
  B: TBitmap;
  Png: TPngImage;
  Stream: TMemoryStream;
  P: PByte;
  Color: TColor;
  Face: string;
begin
  Size := Sc(20);
  Color := ColorToRGB(StyleServices.GetSystemColor(clBtnText));
  if Screen.Fonts.IndexOf('Segoe Fluent Icons') >= 0 then
    Face := 'Segoe Fluent Icons'
  else
    Face := 'Segoe MDL2 Assets';
  FIcons.ImageCollection := nil;
  FImages.Images.Clear;
  for I := 0 to High(Codes) do
  begin
    B := TBitmap.Create;
    Png := TPngImage.Create;
    Stream := TMemoryStream.Create;
    try
      B.PixelFormat := pf32bit;
      B.SetSize(Size, Size);
      B.Canvas.Brush.Color := clWhite;
      B.Canvas.FillRect(Rect(0, 0, Size, Size));
      B.Canvas.Font.Name := Face;
      B.Canvas.Font.Height := -Round(Size * 0.8);
      B.Canvas.Font.Color := clBlack;
      B.Canvas.Font.Quality := fqAntialiased;
      B.Canvas.Brush.Style := bsClear;
      B.Canvas.TextOut((Size - B.Canvas.TextWidth(Char(Codes[I]))) div 2,
        (Size - B.Canvas.TextHeight(Char(Codes[I]))) div 2, Char(Codes[I]));
      // black on white -> the colour of the theme with the darkness as opacity (the alpha channel of the PNG)
      Png.Free;
      Png := TPngImage.CreateBlank(COLOR_RGBALPHA, 8, Size, Size);
      for Y := 0 to Size - 1 do
      begin
        P := B.ScanLine[Y];
        for X := 0 to Size - 1 do
        begin
          Png.Pixels[X, Y] := Color;
          Png.AlphaScanline[Y]^[X] := 255 - P[2];
          Inc(P, 4);
        end;
      end;
      Png.SaveToStream(Stream);
      Stream.Position := 0;
      FImages.Add('icon' + IntToStr(I), Stream);
    finally
      Stream.Free;
      Png.Free;
      B.Free;
    end;
  end;
  FIcons.AutoFill := True;                  // an image of the list for each one of the collection
  FIcons.SetSize(Size, Size);
  FIcons.ImageCollection := FImages;
end;
procedure TMainForm.BuildUi;
var
  Bar, Head, LogPanel, LogBar, Content: TPanel;
  Split: TSplitter;
  Clear: TButton;
  Cap: TLabel;
  I: Integer;

  function Btn(const ACaption: string; AImage: Integer; AHandler: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := Bar;
    Result.Align := alLeft;
    Result.Caption := ACaption;
    Result.Images := FIcons;
    Result.ImageIndex := AImage;
    Result.ImageAlignment := TImageAlignment.iaLeft;
    Result.Width := 120;
    Result.AlignWithMargins := True;
    Result.Margins.SetBounds(0, 8, 8, 8);
    Result.OnClick := AHandler;
  end;

begin
  FImages := TImageCollection.Create(Self);
  FIcons := TVirtualImageList.Create(Self);
  BuildIcons;

  // bottom: splitter, log, status bar (the aligned controls are placed by their Top)
  Split := TSplitter.Create(Self);
  Split.Parent := Self;
  Split.Align := alBottom;
  Split.Height := 6;
  Split.MinSize := 60;
  Split.Top := 28000;  LogPanel := TPanel.Create(Self);
  LogPanel.Parent := Self;
  LogPanel.Align := alBottom;
  LogPanel.Height := 190;
  LogPanel.BevelOuter := bvNone;
  LogPanel.ShowCaption := False;
  LogPanel.Top := 29000;
  FStatus := TStatusBar.Create(Self);
  FStatus.Parent := Self;
  FStatus.SimplePanel := True;
  FStatus.Top := 30000;
  LogBar := TPanel.Create(Self);
  LogBar.Parent := LogPanel;
  LogBar.Align := alTop;
  LogBar.Height := 34;
  LogBar.BevelOuter := bvNone;
  LogBar.ShowCaption := False;
  Cap := TLabel.Create(Self);
  Cap.Parent := LogBar;
  Cap.Caption := 'Output';
  Cap.Font.Style := [fsBold];
  Cap.SetBounds(12, 9, 60, 16);
  FBusy := TActivityIndicator.Create(Self);
  FBusy.Parent := LogBar;
  FBusy.IndicatorSize := aisSmall;
  FBusy.SetBounds(74, 5, 24, 24);
  Clear := TButton.Create(Self);
  Clear.Parent := LogBar;
  Clear.Align := alRight;
  Clear.Caption := 'Clear';
  Clear.Width := 80;
  Clear.AlignWithMargins := True;
  Clear.Margins.SetBounds(0, 4, 8, 4);
  Clear.OnClick := ClearLogClick;
  FLog := TMemo.Create(Self);
  FLog.Parent := LogPanel;
  FLog.Align := alClient;
  FLog.ReadOnly := True;
  FLog.ScrollBars := ssVertical;
  FLog.Font.Name := 'Consolas';
  FLog.Font.Size := 9;
  FLog.BorderStyle := bsNone;
  FLog.AlignWithMargins := True;
  FLog.Margins.SetBounds(12, 0, 8, 4);

  // top: the buttons, the dark theme and the search
  Bar := TPanel.Create(Self);
  Bar.Parent := Self;
  Bar.Align := alTop;
  Bar.Height := 52;
  Bar.BevelOuter := bvNone;
  Bar.ShowCaption := False;
  Bar.Padding.SetBounds(12, 0, 12, 0);
  Btn('Open...', IconOpen, OpenClick);
  Btn('Save as...', IconSave, SaveClick);
  FRun := Btn('Run', IconRun, RunClick);
  FRun.Font.Style := [fsBold];
  Btn('Open output', IconWeb, OpenOutputClick);
  FSearch := TSearchBox.Create(Self);
  FSearch.Parent := Bar;
  FSearch.Align := alRight;
  FSearch.Width := 260;
  FSearch.TextHint := 'Search the options';
  FSearch.AlignWithMargins := True;
  FSearch.Margins.SetBounds(8, 12, 0, 12);
  FSearch.OnChange := SearchChange;
  FSearchTimer := TTimer.Create(Self);
  FSearchTimer.Enabled := False;
  FSearchTimer.Interval := 250;
  FSearchTimer.OnTimer := SearchTimer;
  FTheme := TButton.Create(Self);
  FTheme.Parent := Bar;
  FTheme.Align := alRight;
  FTheme.Width := 100;
  FTheme.Images := FIcons;
  FTheme.ImageIndex := IconTheme;
  FTheme.ImageAlignment := TImageAlignment.iaLeft;
  FTheme.AlignWithMargins := True;
  FTheme.Margins.SetBounds(0, 8, 8, 8);
  FTheme.OnClick := DarkClick;
  // left: the groups of options
  FGroups := TListBox.Create(Self);
  FGroups.Parent := Self;
  FGroups.Align := alLeft;
  FGroups.Width := 210;
  FGroups.Style := lbOwnerDrawFixed;
  FGroups.ItemHeight := 34;
  FGroups.BorderStyle := bsNone;
  FGroups.AlignWithMargins := True;
  FGroups.Margins.SetBounds(8, 0, 0, 0);
  for I := 0 to ConfigGroupCount - 1 do
    FGroups.Items.Add(ConfigGroups[I].Name.Replace('_', ' '));
  FGroups.OnClick := GroupClick;
  FGroups.OnDrawItem := GroupDraw;

  // the options of the group
  Content := TPanel.Create(Self);
  Content.Parent := Self;
  Content.Align := alClient;
  Content.BevelOuter := bvNone;
  Content.ShowCaption := False;
  Head := TPanel.Create(Self);
  Head.Parent := Content;
  Head.Align := alTop;
  Head.Height := 74;
  Head.BevelOuter := bvNone;
  Head.ShowCaption := False;
  FTitle := TLabel.Create(Self);
  FTitle.Parent := Head;
  FTitle.Font.Size := 16;
  FTitle.Font.Style := [fsBold];
  FTitle.SetBounds(16, 10, 600, 30);
  FSubtitle := TLabel.Create(Self);
  FSubtitle.Parent := Head;
  FSubtitle.SetBounds(16, 44, 600, 16);
  FSubtitle.Font.Color := clGrayText;
  FScroll := TScrollBox.Create(Self);
  FScroll.Parent := Content;
  FScroll.Align := alClient;
  FScroll.BorderStyle := bsNone;
  FScroll.VertScrollBar.Tracking := True;
  FScroll.VertScrollBar.Increment := 40;
  FScroll.AutoScroll := True;
  FScroll.StyleElements := [seFont, seBorder, seClient];
  UpdateCaption;
  FTheme.Caption := IfThen(FDarkMode, 'Light', 'Dark');
end;

procedure TMainForm.ApplyTheme;
begin
  FTheme.Caption := IfThen(FDarkMode, 'Light', 'Dark');
  BuildIcons;
  FGroups.Invalidate;
  ShowOptions;
end;

procedure TMainForm.DarkClick(Sender: TObject);
begin
  FDarkMode := not FDarkMode;
  SetDarkTheme(FDarkMode);
  ApplyTheme;
end;

function TMainForm.GroupHasChanges(AGroup: Integer): Boolean;
var
  Opt: TConfigOption;
begin
  for Opt in FConfig.Options do
    if (Opt.Info.Group = AGroup) and (Opt.Info.Kind <> okObsolete) and not Opt.IsDefault then
      Exit(True);
  Result := False;
end;

procedure TMainForm.GroupDraw(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  C: TCanvas;
  R: TRect;
begin
  C := FGroups.Canvas;
  C.FillRect(Rect);
  C.Font.Style := [];
  if (odSelected in State) then
    C.Font.Style := [fsBold];
  R := Rect;
  Inc(R.Left, Sc(14));
  Dec(R.Right, Sc(26));
  DrawText(C.Handle, PChar(FGroups.Items[Index]), -1, R, DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS or DT_NOPREFIX);
  // a dot marks the groups with options that are not the default
  if GroupHasChanges(Index) then
  begin
    C.Brush.Color := StyleServices.GetSystemColor(clHotLight);
    C.Pen.Color := C.Brush.Color;
    C.Ellipse(Rect.Right - Sc(20), Rect.Top + (Rect.Bottom - Rect.Top) div 2 - Sc(3),
      Rect.Right - Sc(14), Rect.Top + (Rect.Bottom - Rect.Top) div 2 + Sc(3));
  end;
end;

procedure TMainForm.GroupClick(Sender: TObject);
begin
  if FGroups.ItemIndex < 0 then
    Exit;
  FCurrentGroup := FGroups.ItemIndex;
  FSearch.OnChange := nil;     // the search is cleared without starting another search
  FSearch.Text := '';
  FSearch.OnChange := SearchChange;
  ShowOptions;
end;

procedure TMainForm.SearchChange(Sender: TObject);
begin
  FSearchTimer.Enabled := False;
  FSearchTimer.Enabled := True;      // waits for the end of the typing
end;

procedure TMainForm.SearchTimer(Sender: TObject);
begin
  FSearchTimer.Enabled := False;
  ShowOptions;
end;

// Builds the rows: the options of the group, or the options of every group that have the search text in the name or in
// the documentation.
procedure TMainForm.ShowOptions;
var
  Opt: TConfigOption;
  Info: TOptionInfo;
  Query: string;
  Count: Integer;
begin
  Query := Trim(FSearch.Text);
  FBuilding := True;
  FScroll.DisableAlign;
  FScroll.Visible := False;
  try
    while FScroll.ControlCount > 0 do
      FScroll.Controls[0].Free;
    Count := 0;
    FScroll.VertScrollBar.Position := 0;
    if Query <> '' then
    begin
      FGroups.ItemIndex := -1;
      FTitle.Caption := 'Search';
    end
    else
    begin
      FGroups.ItemIndex := FCurrentGroup;
      FTitle.Caption := ConfigGroups[FCurrentGroup].Name.Replace('_', ' ');
    end;
    for Opt in FConfig.Options do
    begin
      Info := Opt.Info;
      if Info.Kind = okObsolete then
        Continue;
      if Query <> '' then
      begin
        if not (ContainsText(Info.Name, Query) or ContainsText(Info.Doc, Query)) then
          Continue;
      end
      else if Info.Group <> FCurrentGroup then
        Continue;
      AddRow(Opt);
      Inc(Count);
      if (Query <> '') and (Count >= 60) then
        Break;
    end;
    if Query <> '' then
      FSubtitle.Caption := Format('%d options contain "%s"%s', [Count, Query, IfThen(Count >= 60, ' (the first 60)', '')])
    else
      FSubtitle.Caption := ConfigGroups[FCurrentGroup].Docs;
    UpdateEnabled;
  finally
    FScroll.Visible := True;
    FScroll.EnableAlign;
    FBuilding := False;
  end;
end;

procedure TMainForm.AddRow(AOpt: TConfigOption);
var
  Info: TOptionInfo;
  Row: TOptionRow;
  Combo: TComboBox;
  Edit: TButtonedEdit;
  Memo: TMemo;
  Toggle: TToggleSwitch;
  Ctl: TWinControl;
  V, Brief: string;
  P: Integer;
begin
  Info := AOpt.Info;
  Row := TOptionRow.Create(FScroll);
  Row.PPI := CurrentPPI;
  Row.Parent := FScroll;
  Row.Align := alTop;
  Row.Top := 20000 + FScroll.ControlCount;       // in the order of the options (the aligned ones go by their Top)
  Row.BevelOuter := bvNone;
  Row.ShowCaption := False;
  Row.ParentBackground := True;
  Row.Height := Sc(66);
  Row.Depends := Info.Depends;
  Row.NameLabel := TLabel.Create(Row);
  Row.NameLabel.Parent := Row;
  Row.NameLabel.Caption := Info.Name;
  Row.NameLabel.Font.Style := [fsBold];
  Row.NameLabel.AutoSize := True;
  Row.NameLabel.ShowHint := True;
  Row.NameLabel.Hint := Info.Doc.Replace(#10, ' ');
  // the first sentence of the documentation is the explanation under the name
  Brief := Info.Doc.Replace(#10, ' ').Trim;
  P := Pos('. ', Brief);
  if P > 0 then
    Brief := Copy(Brief, 1, P);
  Row.DescLabel := TLabel.Create(Row);
  Row.DescLabel.Parent := Row;
  Row.DescLabel.AutoSize := False;
  Row.DescLabel.Height := Sc(16);
  Row.DescLabel.EllipsisPosition := epEndEllipsis;
  Row.DescLabel.Caption := Brief;
  Row.DescLabel.Font.Color := clGrayText;
  Row.DescLabel.ShowHint := True;
  Row.DescLabel.Hint := Info.Doc.Replace(#10, ' ');
  case Info.Kind of
    okBool:
      begin
        Toggle := TToggleSwitch.Create(Row);
        Toggle.Parent := Row;
        Toggle.ShowStateCaption := True;
        Toggle.StateCaptions.CaptionOn := 'Yes';
        Toggle.StateCaptions.CaptionOff := 'No';
        Toggle.State := TToggleSwitchState(Ord(AOpt.BoolVal));
        Toggle.OnClick := EditorChange;
        Ctl := Toggle;
      end;
    okEnum:
      begin
        Combo := TComboBox.Create(Row);
        Combo.Parent := Row;
        Combo.Style := csDropDownList;
        for V in Info.Values.Split(['|']) do
          Combo.Items.Add(V);
        if Combo.Items.IndexOf(AOpt.Str) < 0 then
          Combo.Items.Add(AOpt.Str);                 // a value from the file that the list does not know
        Combo.ItemIndex := Combo.Items.IndexOf(AOpt.Str);
        Combo.OnChange := EditorChange;
        Ctl := Combo;
      end;
    okList:
      begin
        Memo := TMemo.Create(Row);
        Memo.Parent := Row;                          // before the text and the scroll bars: they need a window
        Memo.Lines.Text := string.Join(#13#10, AOpt.List.ToArray);
        Memo.ScrollBars := ssVertical;
        Memo.WordWrap := False;
        Memo.OnChange := EditorChange;
        Row.Height := Sc(118);
        Ctl := Memo;
      end;
  else
    begin
      Edit := TButtonedEdit.Create(Row);
      Edit.Parent := Row;
      if Info.Kind = okInt then
        Edit.Text := IntToStr(AOpt.IntVal)
      else
        Edit.Text := AOpt.Str;
      Edit.OnChange := EditorChange;
      Ctl := Edit;
    end;
  end;
  Ctl.Tag := AOpt.Index + 1;
  Row.Editor := Ctl;
  if Ctl is TToggleSwitch then
    Ctl.Top := (Row.Height - Ctl.Height) div 2
  else if Ctl is TMemo then
    Ctl.SetBounds(0, Sc(10), 100, Row.Height - Sc(22))
  else
    Ctl.SetBounds(0, (Row.Height - Ctl.Height) div 2, 100, Ctl.Height);
  // a button to choose a folder or a file
  if (Info.Format = 'dir') or (Info.Format = 'file') or (Info.Format = 'filedir') or (Info.Format = 'image') then
  begin
    Row.Browse := TButton.Create(Row);
    Row.Browse.Parent := Row;
    Row.Browse.Images := FIcons;
    Row.Browse.ImageIndex := IconBrowse;
    Row.Browse.ImageAlignment := TImageAlignment.iaCenter;
    Row.Browse.Caption := '';
    Row.Browse.Hint := 'Choose...';
    Row.Browse.ShowHint := True;
    Row.Browse.Tag := Ctl.Tag;
    Row.Browse.OnClick := BrowseClick;
  end;
  Row.Line := TPanel.Create(Row);
  Row.Line.Parent := Row;
  Row.Line.Align := alBottom;
  Row.Line.Height := 1;
  Row.Line.BevelOuter := bvNone;
  Row.Line.ShowCaption := False;
  Row.Line.StyleElements := [seFont, seBorder];
  Row.Line.ParentBackground := False;
  Row.Line.Color := StyleServices.GetSystemColor(clBtnShadow);
  Row.Resize;
end;

// The options that depend on another (HTML options without GENERATE_HTML...) are disabled.
procedure TMainForm.UpdateEnabled;
var
  I: Integer;
  Row: TOptionRow;
  Dep: TConfigOption;
  Ok: Boolean;
begin
  for I := 0 to FScroll.ControlCount - 1 do
    if FScroll.Controls[I] is TOptionRow then
    begin
      Row := TOptionRow(FScroll.Controls[I]);
      Ok := True;
      if Row.Depends <> '' then
      begin
        Dep := FConfig.Find(Row.Depends);
        if (Dep <> nil) and (Dep.Info.Kind = okBool) then
          Ok := Dep.BoolVal;
      end;
      Row.Editor.Enabled := Ok;
      if Row.Browse <> nil then
        Row.Browse.Enabled := Ok;
      Row.NameLabel.Enabled := Ok;
      Row.DescLabel.Enabled := Ok;
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
    okBool: Opt.BoolVal := TToggleSwitch(Ctl).IsOn;
    okInt: if TryStrToInt(Trim(TButtonedEdit(Ctl).Text), N) then Opt.IntVal := N;
    okEnum: if TComboBox(Ctl).ItemIndex >= 0 then Opt.Str := TComboBox(Ctl).Text;
    okString: Opt.Str := TButtonedEdit(Ctl).Text;
    okList:
      begin
        Opt.List.Clear;
        for N := 0 to TMemo(Ctl).Lines.Count - 1 do
          if Trim(TMemo(Ctl).Lines[N]) <> '' then
            Opt.List.Add(Trim(TMemo(Ctl).Lines[N]));
      end;
  end;
  SetModified(True);
  if Opt.Info.Kind = okBool then
    UpdateEnabled;
  FGroups.Invalidate;
end;

procedure TMainForm.BrowseClick(Sender: TObject);
var
  Opt: TConfigOption;
  Dlg: TFileOpenDialog;
  Ctl: TWinControl;
  Row: TOptionRow;
  Folder: Boolean;
begin
  Opt := FConfig.Options[TControl(Sender).Tag - 1];
  Row := TOptionRow(TControl(Sender).Parent);
  Ctl := Row.Editor;
  Folder := (Opt.Info.Format = 'dir') or (Opt.Info.Format = 'filedir');
  Dlg := TFileOpenDialog.Create(Self);
  try
    Dlg.Title := Opt.Info.Name;
    if Folder then
      Dlg.Options := Dlg.Options + [fdoPickFolders];
    if Dlg.Execute then
    begin
      if Ctl is TMemo then
        TMemo(Ctl).Lines.Add(Dlg.FileName)             // a list: another item
      else
        TButtonedEdit(Ctl).Text := Dlg.FileName;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.SetModified(AValue: Boolean);
begin
  FModified := AValue;
  UpdateCaption;
end;

procedure TMainForm.UpdateCaption;
var
  Name: string;
begin
  if FFileName = '' then
    Name := '(new Doxyfile)'
  else
    Name := FFileName;
  Caption := 'DoxyPas ' + DoxyPasVersion + ' - ' + ExtractFileName(Name) + IfThen(FModified, ' *', '');
  if FStatus <> nil then
    FStatus.SimpleText := Name + IfThen(FModified, '  (modified)', '');
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FModified then
    case MessageDlg('Save the changes to the Doxyfile?', mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
      mrYes: CanClose := (FFileName <> '') and SaveFile(FFileName) or ((FFileName = '') and SaveAs);
      mrCancel: CanClose := False;
    end;
  if CanClose and (FProcess <> 0) then
  begin
    FStopping := True;
    TerminateProcess(FProcess, 1);
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
  FFileName := TPath.GetFullPath(AFileName);
  FModified := False;
  FSearch.OnChange := nil;
  FSearch.Text := '';
  FSearch.OnChange := SearchChange;
  FCurrentGroup := 0;
  UpdateCaption;
  FGroups.Invalidate;
  ShowOptions;
end;

procedure TMainForm.Open(const AFileName: string);
begin
  try
    LoadFile(AFileName);
  except
    on E: Exception do
      MessageDlg('Could not open ' + AFileName + ':' + sLineBreak + E.Message, mtError, [mbOK], 0);
  end;
end;

function TMainForm.SaveFile(const AFileName: string): Boolean;
begin
  try
    TFile.WriteAllText(AFileName, WriteDoxyfile(FConfig, False, False), TEncoding.UTF8);
  except
    on E: Exception do
    begin
      MessageDlg('Could not save ' + AFileName + ':' + sLineBreak + E.Message, mtError, [mbOK], 0);
      Exit(False);
    end;
  end;
  FFileName := TPath.GetFullPath(AFileName);
  SetModified(False);
  Result := True;
end;

function TMainForm.SaveAs: Boolean;
var
  Dlg: TSaveDialog;
begin
  Result := False;
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Filter := 'Doxyfile|Doxyfile|All files|*.*';
    Dlg.FileName := IfThen(FFileName <> '', ExtractFileName(FFileName), 'Doxyfile');
    if FFileName <> '' then
      Dlg.InitialDir := ExtractFilePath(FFileName);
    Dlg.Options := Dlg.Options + [ofOverwritePrompt];
    if Dlg.Execute then
      Result := SaveFile(Dlg.FileName);
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.OpenClick(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Filter := 'Doxyfile (*)|*|All files|*.*';
    Dlg.Options := Dlg.Options + [ofFileMustExist];
    if Dlg.Execute then
      Open(Dlg.FileName);
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.SaveClick(Sender: TObject);
begin
  SaveAs;
end;

function TMainForm.CliPath: string;
begin
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'DoxyPas.exe');
end;

procedure TMainForm.Log(const AText: string);
begin
  if csDestroying in ComponentState then
    Exit;
  FLog.Lines.Add(AText);
end;

procedure TMainForm.ClearLogClick(Sender: TObject);
begin
  FLog.Clear;
end;

procedure TMainForm.ProcessEnded;
begin
  if csDestroying in ComponentState then
    Exit;
  FProcess := 0;
  FBusy.Animate := False;
  FRun.Caption := 'Run';
  FRun.ImageIndex := IconRun;
  Log(IfThen(FStopping, 'Stopped.', 'Done.'));
  FStopping := False;
end;

// Runs a console program and appends its output to the log, without blocking the window.
procedure TMainForm.RunProcess(const ACommand, ADir: string);
var
  Cmd, Dir: string;
begin
  Cmd := ACommand;
  Dir := ADir;
  FStopping := False;
  FRun.Caption := 'Stop';
  FRun.ImageIndex := IconStop;
  FBusy.Animate := True;
  Log('> ' + Cmd);
  TTask.Run(
    procedure
    var
      SA: TSecurityAttributes;
      Rd, Wr: THandle;
      SI: TStartupInfo;
      PI: TProcessInformation;
      Buf: array[0..4095] of Byte;
      N: DWORD;
      Pending: TBytes;
      Line: TBytes;
      I, Start: Integer;

      procedure Flush(AUntil: Integer);
      var
        Text: string;
      begin
        Text := TEncoding.UTF8.GetString(Pending, Start, AUntil - Start).TrimRight([#13, #10]);
        Start := AUntil + 1;
        TThread.Queue(nil,
          procedure
          begin
            Log(Text);
          end);
      end;

    begin
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
      if CreateProcess(nil, PChar(Cmd), nil, nil, True, CREATE_NO_WINDOW, nil, PChar(Dir), SI, PI) then
      begin
        CloseHandle(Wr);
        CloseHandle(PI.hThread);
        TThread.Queue(nil,
          procedure
          begin
            FProcess := PI.hProcess;
          end);
        // the output is cut in lines before it is decoded: a character of UTF-8 may come in two reads
        Pending := nil;
        Start := 0;
        while ReadFile(Rd, Buf, SizeOf(Buf), N, nil) and (N > 0) do
        begin
          I := Length(Pending);
          SetLength(Pending, I + Integer(N));
          Move(Buf[0], Pending[I], N);
          I := Start;
          while I < Length(Pending) do
          begin
            if Pending[I] = 10 then
              Flush(I);
            Inc(I);
          end;
          Line := Copy(Pending, Start, Length(Pending) - Start);
          Pending := Line;
          Start := 0;
        end;
        if Length(Pending) > 0 then
          Flush(Length(Pending));
        WaitForSingleObject(PI.hProcess, INFINITE);
        CloseHandle(PI.hProcess);
      end
      else
        TThread.Queue(nil,
          procedure
          begin
            Log('Could not start ' + Cmd);
          end);
      CloseHandle(Rd);
      TThread.Queue(nil, ProcessEnded);
    end);
end;

procedure TMainForm.RunClick(Sender: TObject);
begin
  Run;
end;

procedure TMainForm.Run;
begin
  if FProcess <> 0 then              // the button is "Stop" while it runs
  begin
    FStopping := True;
    TerminateProcess(FProcess, 1);
    Exit;
  end;
  if FFileName = '' then
  begin
    if not SaveAs then
      Exit;
  end
  else if not SaveFile(FFileName) then
    Exit;
  if not TFile.Exists(CliPath) then
  begin
    MessageDlg('DoxyPas.exe was not found next to this program.', mtError, [mbOK], 0);
    Exit;
  end;
  RunProcess('"' + CliPath + '" "' + FFileName + '"', ExtractFilePath(FFileName));
end;

// The index.html of the HTML output of the Doxyfile.
function TMainForm.OutputIndex: string;
var
  Dir: string;
begin
  Dir := FConfig.GetString('OUTPUT_DIRECTORY');
  if (FFileName <> '') and ((Dir = '') or TPath.IsRelativePath(Dir)) then
    Dir := TPath.Combine(ExtractFilePath(FFileName), Dir)
  else if Dir = '' then
    Dir := TDirectory.GetCurrentDirectory;
  Result := TPath.Combine(TPath.Combine(Dir, FConfig.GetString('HTML_OUTPUT')), 'index.html');
end;

procedure TMainForm.OpenOutputClick(Sender: TObject);
var
  Index: string;
begin
  Index := OutputIndex;
  if TFile.Exists(Index) then
    ShellExecute(0, 'open', PChar(Index), nil, nil, SW_SHOWNORMAL)
  else
    MessageDlg('The documentation was not found:' + sLineBreak + Index + sLineBreak + 'Run DoxyPas first.', mtInformation,
      [mbOK], 0);
end;

end.
