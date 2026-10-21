unit DoxyPas.Comments.EntryDocs;

{ Runs the comment scanner over every documented entry of a tree: fills Entry.Brief, Entry.Detailed, Entry.Groups
  and the documentation flags. }

interface

uses
  System.Classes,
  DoxyPas.Model.Entry,
  DoxyPas.Comments.Scanner;

procedure ScanEntryDocs(ARoot: TEntry; const AOptions: TDocOptions; AWarnings: TStrings = nil);

implementation

uses
  System.SysUtils;

procedure ScanEntry(AEntry: TEntry; const AOptions: TDocOptions; AWarnings: TStrings);
var
  Info: TCommentInfo;
  W: TStringList;
  Msg: string;
  Child: TEntry;
begin
  if AEntry.Doc <> '' then
  begin
    W := TStringList.Create;
    try
      Info := ScanComment(AEntry.Doc, AEntry.DocIsAfter, AOptions, W);
      if AWarnings <> nil then
        for Msg in W do
          AWarnings.Add(Format('%s:%d: %s', [AEntry.FileName, AEntry.DocLine, Msg]));
    finally
      W.Free;
    end;
    AEntry.Brief := Info.Brief;
    AEntry.Detailed := Info.Detailed;
    if Length(Info.Groups) > 0 then
      AEntry.WriteGroups.AddRange(Info.Groups);
    if Info.IsInternal then Include(AEntry.Flags, efInternal);
    if Info.HideInitializer then Include(AEntry.Flags, efHideInitializer);
    if Info.ShowInitializer then Include(AEntry.Flags, efShowInitializer);
    if Info.IsOverload then Include(AEntry.Flags, efOverload);
    if Info.IsStatic then Include(AEntry.Flags, efStatic);
    if Info.ProtectionOverride = 'public' then AEntry.Protection := prPublic
    else if Info.ProtectionOverride = 'protected' then AEntry.Protection := prProtected
    else if Info.ProtectionOverride = 'private' then AEntry.Protection := prPrivate;
  end;
  for Child in AEntry.Children do
    ScanEntry(Child, AOptions, AWarnings);
end;

procedure ScanEntryDocs(ARoot: TEntry; const AOptions: TDocOptions; AWarnings: TStrings);
begin
  ScanEntry(ARoot, AOptions, AWarnings);
end;

end.
