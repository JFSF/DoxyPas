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
  System.SysUtils,
  System.Generics.Collections;

// DISTRIBUTE_GROUP_DOC: the members of a //@{ group that have no documentation get that of the first member of the group.
procedure DistributeGroupDocs(AParent: TEntry);
var
  First: TDictionary<TMemberGroup, TEntry>;
  C, F: TEntry;
begin
  First := TDictionary<TMemberGroup, TEntry>.Create;
  try
    for C in AParent.Children do
      if C.MemberGroup <> nil then
        if not First.TryGetValue(C.MemberGroup, F) then
          First.Add(C.MemberGroup, C)
        else if (C.Doc = '') and (F.Doc <> '') then
        begin
          C.Doc := F.Doc;
          C.DocLine := F.DocLine;
        end;
  finally
    First.Free;
  end;
end;

procedure ScanEntry(AEntry: TEntry; const AOptions: TDocOptions; AWarnings: TStrings);
var
  Info: TCommentInfo;
  W: TStringList;
  Msg: string;
  Child: TEntry;
begin
  if AOptions.DistributeGroupDoc then
    DistributeGroupDocs(AEntry);
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
  if AEntry.BodyDoc <> '' then            // the comments in the body are more detailed description (no brief of their own)
  begin
    Info := ScanComment(AEntry.BodyDoc, False, AOptions, nil);
    if Info.Detailed <> '' then
      Info.Brief := Info.Brief + #10#10 + Info.Detailed;
    if AEntry.Detailed = '' then
      AEntry.Detailed := Info.Brief
    else
      AEntry.Detailed := AEntry.Detailed + #10#10 + Info.Brief;
  end;
  for Child in AEntry.Children do
    ScanEntry(Child, AOptions, AWarnings);
end;

procedure ScanEntryDocs(ARoot: TEntry; const AOptions: TDocOptions; AWarnings: TStrings);
begin
  ScanEntry(ARoot, AOptions, AWarnings);
end;

end.
