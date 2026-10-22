unit DoxyPas.Lang.Pascal.DocBlocks;

// Finds documentation comments and attaches them to declarations (Doxygen's comment/declaration pairing).
//
// Recognised as documentation:  /// ...   //! ...   {** ... }   {! ... }   (** ... *)   (*! ... *)
// A '<' right after the marker (///<  //!<  {**<  {!<  (**<  (*!<) documents the *previous* declaration;
// otherwise the comment documents the *next* one. Consecutive /// or //! lines form one block.

interface

uses
  DoxyPas.Model.Entry,
  DoxyPas.Lang.Pascal.Source;

/// <summary>Attaches the documentation comments of ASource to the entries below ARoot (sets Entry.Doc).
/// Only entries whose FileName is AFileName are considered (entries from {$I} files are skipped).</summary>
procedure AttachDocComments(ASource: TPasSource; ARoot: TEntry; const AFileName: string);

implementation

uses
  System.SysUtils,
  System.Classes,
  System.RegularExpressions,
  System.Generics.Collections,
  System.Generics.Defaults;

type
  TDocBlock = record
    Text: string;
    FirstTok, LastTok: Integer;
    Line, Col: Integer;
    EndLine, EndCol: Integer;
    IsAfter: Boolean;
  end;

type
  // @{ or @} (also \{ \}), at the end of a documentation block or alone in a comment
  TMarker = record
    Line, Col: Integer;
    Open: Boolean;
  end;

// A "@{" or "@}" ending the text of a block is removed from it and noted in AMarkers (at the end of the block).
procedure TakeMarker(var AText: string; ALine, ACol: Integer; AMarkers: TList<TMarker>);
var
  M: TMatch;
  Mk: TMarker;
begin
  M := TRegEx.Match(AText, '(?:^|\s)[@\\]([{}])\s*$');
  if not M.Success then
    Exit;
  Mk.Line := ALine;
  Mk.Col := ACol;
  Mk.Open := M.Groups[1].Value = '{';
  AMarkers.Add(Mk);
  AText := Copy(AText, 1, M.Index - 1).TrimRight;
end;

// A plain comment that is only "@{" or "@}": //@{   (*@{*)   {@{}
procedure PlainMarker(const AInner: string; ALine, ACol: Integer; AMarkers: TList<TMarker>);
var
  S: string;
  Mk: TMarker;
begin
  S := Trim(AInner);
  if (Length(S) <> 2) or not CharInSet(S[1], ['@', '\']) or not CharInSet(S[2], ['{', '}']) then
    Exit;
  Mk.Line := ALine;
  Mk.Col := ACol;
  Mk.Open := S[2] = '{';
  AMarkers.Add(Mk);
end;

function CleanBlockText(const AInner: string): string;
var
  Lines: TArray<string>;
  I: Integer;
  S: string;
  SL: TStringList;
begin
  Lines := AInner.Replace(#13#10, #10).Replace(#13, #10).Split([#10]);
  SL := TStringList.Create;
  try
    for I := 0 to High(Lines) do
    begin
      S := Lines[I].TrimRight;
      if I > 0 then
      begin
        S := S.TrimLeft;
        if S.StartsWith('*') then
          S := Copy(S, 2, MaxInt);
        if S.StartsWith(' ') then
          S := Copy(S, 2, MaxInt);
      end
      else if S.StartsWith(' ') then
        S := Copy(S, 2, MaxInt);
      SL.Add(S);
    end;
    while (SL.Count > 0) and (Trim(SL[0]) = '') do
      SL.Delete(0);
    while (SL.Count > 0) and (Trim(SL[SL.Count - 1]) = '') do
      SL.Delete(SL.Count - 1);
    Result := SL.Text.TrimRight([#13, #10]).Replace(#13#10, #10);
  finally
    SL.Free;
  end;
end;

{ Returns the marker length (including '<') if the line comment is a doc comment. }
function LineMarker(const AText: string; out AIsAfter: Boolean): Integer;
begin
  Result := 0;
  AIsAfter := False;
  if (AText.StartsWith('///') and not AText.StartsWith('////')) or AText.StartsWith('//!') then
  begin
    Result := 3;
    if (Length(AText) > 3) and (AText[4] = '<') then
    begin
      Inc(Result);
      AIsAfter := True;
    end;
  end;
end;

procedure CollectBlocks(ASource: TPasSource; ABlocks: TList<TDocBlock>; AMarkers: TList<TMarker>);
var
  I, J, M, OpenLen, CloseLen: Integer;
  T: TPasToken;
  Txt, Inner: string;
  Blk: TDocBlock;
  IsAfter, NextAfter: Boolean;
  Lines: TStringList;
begin
  I := 0;
  while I < ASource.Count do
  begin
    T := ASource.Token(I);
    if T.Kind = tkLineComment then
    begin
      Txt := ASource.TokenText(I);
      M := LineMarker(Txt, IsAfter);
      if M > 0 then
      begin
        Lines := TStringList.Create;
        try
          Blk.FirstTok := I;
          Lines.Add(Copy(Txt, M + 1, MaxInt));
          J := I;
          while (J + 1 < ASource.Count) and (ASource.Token(J + 1).Kind = tkLineComment) and
            (ASource.Token(J + 1).Line = ASource.Token(J).Line + 1) and
            (LineMarker(ASource.TokenText(J + 1), NextAfter) > 0) and (NextAfter = IsAfter) do
          begin
            Inc(J);
            Lines.Add(Copy(ASource.TokenText(J), LineMarker(ASource.TokenText(J), NextAfter) + 1, MaxInt));
          end;
          Blk.LastTok := J;
          Blk.Text := CleanBlockText(Lines.Text.TrimRight([#13, #10]));
          Blk.Line := T.Line;
          Blk.Col := T.Col;
          Blk.EndLine := ASource.Token(J).EndLine;
          Blk.EndCol := ASource.Token(J).EndCol;
          Blk.IsAfter := IsAfter;
          TakeMarker(Blk.Text, Blk.EndLine, Blk.EndCol, AMarkers);
          ABlocks.Add(Blk);
          I := J;
        finally
          Lines.Free;
        end;
      end
      else
        PlainMarker(Copy(Txt, 3, MaxInt), T.Line, T.Col, AMarkers);
    end
    else if T.Kind = tkBlockComment then
    begin
      Txt := ASource.TokenText(I);
      if Txt.StartsWith('{') then
      begin
        OpenLen := 1;
        CloseLen := 1;
      end
      else
      begin
        OpenLen := 2;
        CloseLen := 2;
      end;
      if Txt.EndsWith('}') or Txt.EndsWith('*)') then
        Inner := Copy(Txt, OpenLen + 1, Length(Txt) - OpenLen - CloseLen)
      else
        Inner := Copy(Txt, OpenLen + 1, MaxInt);
      // doc marker right after the opening delimiter: {** {! (** (*!   (the "(*" already contains one star)
      M := 0;
      if Txt.StartsWith('{') and Inner.StartsWith('**') then
        M := 2
      else if Txt.StartsWith('(*') and Inner.StartsWith('*') then
        M := 1
      else if Inner.StartsWith('!') then
        M := 1;
      if M > 0 then
      begin
        IsAfter := (Length(Inner) > M) and (Inner[M + 1] = '<');
        if IsAfter then
          Inc(M);
        Blk.FirstTok := I;
        Blk.LastTok := I;
        Blk.Text := CleanBlockText(Copy(Inner, M + 1, MaxInt));
        Blk.Line := T.Line;
        Blk.Col := T.Col;
        Blk.EndLine := T.EndLine;
        Blk.EndCol := T.EndCol;
        Blk.IsAfter := IsAfter;
        TakeMarker(Blk.Text, Blk.EndLine, Blk.EndCol, AMarkers);
        ABlocks.Add(Blk);
      end
      else
        PlainMarker(Inner, T.Line, T.Col, AMarkers);
    end;
    Inc(I);
  end;
end;

function Before(ALine1, ACol1, ALine2, ACol2: Integer): Boolean; inline;
begin
  Result := (ALine1 < ALine2) or ((ALine1 = ALine2) and (ACol1 < ACol2));
end;

function Encloses(AEntry: TEntry; ALine, ACol: Integer): Boolean;
begin
  Result := (AEntry.EndLine > 0) and Before(AEntry.Line, AEntry.Col, ALine, ACol) and
    Before(ALine, ACol, AEntry.EndLine, AEntry.EndCol) and (AEntry.Children.Count > 0);
end;

function FindNext(AParent: TEntry; const ABlock: TDocBlock; const AFileName: string): TEntry;
var
  C, Best, R: TEntry;
begin
  Best := nil;
  for C in AParent.Children do
  begin
    if (C.Line = 0) or not SameText(C.FileName, AFileName) then
      Continue;
    if Before(C.Line, C.Col, ABlock.Line, ABlock.Col) then
    begin
      if Encloses(C, ABlock.Line, ABlock.Col) then
      begin
        R := FindNext(C, ABlock, AFileName);
        Exit(R); // inside a container: the next member, or nothing if the block is at its end
      end;
    end
    else if (Best = nil) or Before(C.Line, C.Col, Best.Line, Best.Col) then
      Best := C;
  end;
  Result := Best;
end;

function FindPrev(AParent: TEntry; const ABlock: TDocBlock; const AFileName: string): TEntry;
var
  C, Best, R: TEntry;
begin
  Best := nil;
  for C in AParent.Children do
  begin
    if (C.Line = 0) or not SameText(C.FileName, AFileName) then
      Continue;
    if Before(C.Line, C.Col, ABlock.Line, ABlock.Col) then
    begin
      if Encloses(C, ABlock.Line, ABlock.Col) then
      begin
        R := FindPrev(C, ABlock, AFileName);
        if R <> nil then
          Exit(R);
        Exit(C); // right after the header of a container: documents the container itself
      end;
      Best := C;
    end;
  end;
  Result := Best;
end;

{ Only comments, compiler directives, attributes and section keywords may lie between a documentation
  comment and the declaration it documents. }
function GapIsClear(ASource: TPasSource; AFromTok: Integer; AEntry: TEntry): Boolean;
var
  ToTok, I, Depth: Integer;
  W: string;
begin
  Result := True;
  ToTok := ASource.IndexAt(AEntry.Line, AEntry.Col);
  Depth := 0;
  for I := AFromTok to ToTok - 1 do
  begin
    if ASource.IsComment(I) then
      Continue;
    if ASource.IsSymbol(I, '[') then
      Inc(Depth)
    else if ASource.IsSymbol(I, ']') then
      Dec(Depth)
    else if Depth > 0 then
      Continue
    else
    begin
      W := LowerCase(ASource.TokenText(I));
      if not ((W = 'type') or (W = 'var') or (W = 'const') or (W = 'resourcestring') or (W = 'threadvar')) then
        Exit(False);
    end;
  end;
end;

{ Blocks that start with \page, \mainpage, \defgroup, \addtogroup or \file are not attached to a declaration:
  they become page/group entries below the unit (\file documents the unit itself). }
function AddStandalone(ARoot: TEntry; const B: TDocBlock; const AFileName: string; out ACmd, AId: string): Boolean;
var
  M: TMatch;
  E: TEntry;
  Cmd, LineRest, Rest, Id: string;
  P: Integer;
begin
  M := TRegEx.Match(B.Text, '^[\\@](page|mainpage|defgroup|addtogroup|weakgroup|file)\b[ \t]*([^\n]*)(?:\n(.*))?$',
    [roSingleLine]);
  Result := M.Success;
  ACmd := '';
  AId := '';
  if not Result then
    Exit;
  Cmd := M.Groups[1].Value;
  ACmd := Cmd;
  LineRest := Trim(M.Groups[2].Value);
  if M.Groups.Count > 3 then
    Rest := Trim(M.Groups[3].Value)
  else
    Rest := '';
  if Cmd = 'file' then
  begin
    if ARoot.Doc = '' then
    begin
      ARoot.Doc := Rest;
      ARoot.DocLine := B.Line;
    end
    else
      ARoot.Doc := ARoot.Doc + #10#10 + Rest;
    Exit;
  end;
  if Cmd = 'mainpage' then
    Id := 'mainpage'
  else
  begin
    P := Pos(' ', LineRest);
    if P = 0 then
    begin
      Id := LineRest;
      LineRest := '';
    end
    else
    begin
      Id := Copy(LineRest, 1, P - 1);
      LineRest := Trim(Copy(LineRest, P + 1, MaxInt));
    end;
  end;
  if (Cmd = 'page') or (Cmd = 'mainpage') then
    E := TEntry.Create(ekPage, Id)
  else
    E := TEntry.Create(ekGroup, Id);
  AId := Id;
  E.TypeText := LineRest;
  E.Doc := Rest;
  E.DocLine := B.Line;
  E.FileName := AFileName;
  E.Line := B.Line;
  E.Col := B.Col;
  E.EndLine := B.EndLine;
  E.EndCol := B.EndCol;
  ARoot.Add(E);
end;

type
  TGroupEventKind = (geCmd, geOpen, geClose);

  // What the @{ ... @} ranges are made of, in the order of the file: the \defgroup/\name before a @{, the @{ and the @}.
  TGroupEvent = record
    Kind: TGroupEventKind;
    Line, Col: Integer;
    IsName: Boolean;            // geCmd: \name (a member group) and not \defgroup, \addtogroup or \weakgroup
    Id, Title, Doc: string;
  end;

// "\name Title" and the text under it: the heading of a member group, not the documentation of a declaration.
function IsNameBlock(const B: TDocBlock; out ATitle, ADoc: string): Boolean;
var
  M: TMatch;
begin
  M := TRegEx.Match(B.Text, '^[\\@]name\b[ \t]*([^\n]*)(?:\n(.*))?$', [roSingleLine]);
  Result := M.Success;
  ATitle := '';
  ADoc := '';
  if not Result then
    Exit;
  ATitle := Trim(M.Groups[1].Value);
  if M.Groups.Count > 2 then
    ADoc := Trim(M.Groups[2].Value);
end;

// The @{ ... @} ranges: the declarations inside a \defgroup/\addtogroup range are in that group; those inside a \name (or
// unnamed) range in a class or unit are a member group.
procedure ApplyRanges(ARoot: TEntry; const AFileName: string; AEvents: TList<TGroupEvent>);
type
  TOpenRange = record
    Line, Col: Integer;
    HasCmd: Boolean;
    Cmd: TGroupEvent;
  end;
var
  Stack: TStack<TOpenRange>;
  Pending: TGroupEvent;
  HasPending: Boolean;
  E: TGroupEvent;
  O: TOpenRange;
  Probe: TDocBlock;
  Next: TEntry;

  procedure Apply(const ARange: TOpenRange; AEndLine, AEndCol: Integer);
  var
    G: TMemberGroup;

    function Inside(C: TEntry): Boolean;
    begin
      Result := Before(ARange.Line, ARange.Col, C.Line, C.Col) and Before(C.Line, C.Col, AEndLine, AEndCol);
    end;

    procedure Walk(AParent: TEntry);
    var
      C: TEntry;
    begin
      for C in AParent.Children do
      begin
        if (C.Line = 0) or not SameText(C.FileName, AFileName) then
          Continue;
        if Inside(C) then
        begin
          if ARange.HasCmd and not ARange.Cmd.IsName then
          begin
            // an explicit \ingroup of the declaration wins
            if (not TRegEx.IsMatch(C.Doc, '[\\@]ingroup\b')) and (not C.Groups.Contains(ARange.Cmd.Id)) then
              C.WriteGroups.Add(ARange.Cmd.Id);
          end
          else if C.MemberGroup = nil then
          begin
            if G = nil then
              if ARange.HasCmd then
                G := ARoot.NewMemberGroup(ARange.Cmd.Title, ARange.Cmd.Doc)
              else
                G := ARoot.NewMemberGroup('', '');
            C.MemberGroup := G;
          end;
        end
        else if (C.EndLine > 0) and Encloses(C, ARange.Line, ARange.Col) then
          Walk(C);
      end;
    end;

  begin
    G := nil;
    Walk(ARoot);
  end;

begin
  Stack := TStack<TOpenRange>.Create;
  try
    HasPending := False;
    for E in AEvents do
      case E.Kind of
        geCmd:
          begin
            Pending := E;
            HasPending := True;
          end;
        geOpen:
          begin
            O.Line := E.Line;
            O.Col := E.Col;
            O.HasCmd := False;
            O.Cmd := Default(TGroupEvent);
            if HasPending then
            begin
              // the command belongs to this @{ only when no declaration lies between them
              Probe := Default(TDocBlock);
              Probe.Line := Pending.Line;
              Probe.Col := Pending.Col + 1;      // after the entry that \defgroup itself made at that position
              Next := FindNext(ARoot, Probe, AFileName);
              if (Next = nil) or not Before(Next.Line, Next.Col, E.Line, E.Col) then
              begin
                O.HasCmd := True;
                O.Cmd := Pending;
              end;
            end;
            HasPending := False;
            Stack.Push(O);
          end;
        geClose:
          if Stack.Count > 0 then
            Apply(Stack.Pop, E.Line, E.Col);
      end;
    while Stack.Count > 0 do
      Apply(Stack.Pop, MaxInt, 0);       // not closed: up to the end of the file
  finally
    Stack.Free;
  end;
end;

procedure AttachDocComments(ASource: TPasSource; ARoot: TEntry; const AFileName: string);
var
  Blocks: TList<TDocBlock>;
  Markers: TList<TMarker>;
  Events: TList<TGroupEvent>;
  B: TDocBlock;
  Mk: TMarker;
  Ev: TGroupEvent;
  Target: TEntry;
  Cmd, Id, Title, Doc: string;
begin
  Blocks := TList<TDocBlock>.Create;
  Markers := TList<TMarker>.Create;
  Events := TList<TGroupEvent>.Create;
  try
    CollectBlocks(ASource, Blocks, Markers);
    for B in Blocks do
    begin
      if B.Text = '' then
        Continue;
      Ev := Default(TGroupEvent);
      Ev.Kind := geCmd;
      Ev.Line := B.Line;
      Ev.Col := B.Col;
      if (not B.IsAfter) and IsNameBlock(B, Title, Doc) then
      begin
        Ev.IsName := True;
        Ev.Title := Title;
        Ev.Doc := Doc;
        Events.Add(Ev);
        Continue;
      end;
      if (not B.IsAfter) and AddStandalone(ARoot, B, AFileName, Cmd, Id) then
      begin
        if (Cmd = 'defgroup') or (Cmd = 'addtogroup') or (Cmd = 'weakgroup') then
        begin
          Ev.Id := Id;
          Events.Add(Ev);
        end;
        Continue;
      end;
      if B.IsAfter then
        Target := FindPrev(ARoot, B, AFileName)
      else if (ARoot.Line > 0) and SameText(ARoot.FileName, AFileName) and Before(B.Line, B.Col, ARoot.Line, ARoot.Col) then
        Target := ARoot             // before the unit, program, library or package keyword: the documentation of the unit
      else
      begin
        Target := FindNext(ARoot, B, AFileName);
        if (Target <> nil) and not GapIsClear(ASource, B.LastTok + 1, Target) then
          Target := nil;
      end;
      if Target = nil then
        Continue;
      if Target.Doc = '' then
      begin
        Target.Doc := B.Text;
        Target.DocLine := B.Line;
        Target.DocIsAfter := B.IsAfter;
      end
      else
        Target.Doc := Target.Doc + #10 + #10 + B.Text;
    end;
    for Mk in Markers do
    begin
      Ev := Default(TGroupEvent);
      if Mk.Open then Ev.Kind := geOpen else Ev.Kind := geClose;
      Ev.Line := Mk.Line;
      Ev.Col := Mk.Col;
      Events.Add(Ev);
    end;
    if Markers.Count > 0 then
    begin
      Events.Sort(TComparer<TGroupEvent>.Construct(
        function(const L, R: TGroupEvent): Integer
        begin
          if L.Line <> R.Line then
            Result := L.Line - R.Line
          else
            Result := L.Col - R.Col;
        end));
      ApplyRanges(ARoot, AFileName, Events);
    end;
  finally
    Events.Free;
    Markers.Free;
    Blocks.Free;
  end;
end;

end.
