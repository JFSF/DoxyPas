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
  System.Generics.Collections;

type
  TDocBlock = record
    Text: string;
    FirstTok, LastTok: Integer;
    Line, Col: Integer;
    EndLine, EndCol: Integer;
    IsAfter: Boolean;
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

procedure CollectBlocks(ASource: TPasSource; ABlocks: TList<TDocBlock>);
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
          ABlocks.Add(Blk);
          I := J;
        finally
          Lines.Free;
        end;
      end;
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
        ABlocks.Add(Blk);
      end;
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
function AddStandalone(ARoot: TEntry; const B: TDocBlock; const AFileName: string): Boolean;
var
  M: TMatch;
  E: TEntry;
  Cmd, LineRest, Rest, Id: string;
  P: Integer;
begin
  M := TRegEx.Match(B.Text, '^[\\@](page|mainpage|defgroup|addtogroup|weakgroup|file)\b[ \t]*([^\n]*)(?:\n(.*))?$',
    [roSingleLine]);
  Result := M.Success;
  if not Result then
    Exit;
  Cmd := M.Groups[1].Value;
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

procedure AttachDocComments(ASource: TPasSource; ARoot: TEntry; const AFileName: string);
var
  Blocks: TList<TDocBlock>;
  B: TDocBlock;
  Target: TEntry;
begin
  Blocks := TList<TDocBlock>.Create;
  try
    CollectBlocks(ASource, Blocks);
    for B in Blocks do
    begin
      if B.Text = '' then
        Continue;
      if (not B.IsAfter) and AddStandalone(ARoot, B, AFileName) then
        Continue;
      if B.IsAfter then
        Target := FindPrev(ARoot, B, AFileName)
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
  finally
    Blocks.Free;
  end;
end;

end.
