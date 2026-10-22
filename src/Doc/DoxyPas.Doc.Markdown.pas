unit DoxyPas.Doc.Markdown;

{ Markdown to Doxygen text (Doxygen's markdown.cpp): block and inline Markdown is turned into HTML tags and
  \code blocks that the documentation parser (DoxyPas.Doc.Parser) understands. Code blocks and verbatim-like
  commands are copied unchanged. Supported: ATX/setext headers, emphasis (* _ **, __, ~~), code spans, fenced and
  indented code, bullet/ordered lists (nested), block quotes, tables, rules, links, images, autolinks, hard breaks. }

interface

/// <summary>Converts Markdown in AText; ATabSize is Doxygen's TAB_SIZE.</summary>
/// <summary>AStrict (MARKDOWN_STRICT = NO: Doxygen's own markup): a single backtick may also be closed by a single quote.</summary>
function MarkdownToDoxygen(const AText: string; ATabSize: Integer = 4; AStrict: Boolean = True): string;

implementation

uses
  System.SysUtils,
  System.Character,
  System.Math,
  System.Classes,
  System.Generics.Collections,
  System.RegularExpressions;

var
  NativeQuotes: Boolean;               // MARKDOWN_STRICT = NO, for the conversion that is running

const
  // commands whose body must not be touched, with the command that ends them
  VerbatimStarts: array[0..14, 0..1] of string = (
    ('\code', '\endcode'), ('@code', '@endcode'), ('\verbatim', '\endverbatim'), ('@verbatim', '@endverbatim'),
    ('\htmlonly', '\endhtmlonly'), ('@htmlonly', '@endhtmlonly'), ('\latexonly', '\endlatexonly'),
    ('@latexonly', '@endlatexonly'), ('\xmlonly', '\endxmlonly'), ('\dot', '\enddot'), ('\msc', '\endmsc'),
    ('\startuml', '\enduml'), ('\iverbatim', '\endiverbatim'), ('\icode', '\endicode'), ('\f[', '\f]'));

function EscapeCode(const S: string): string;
begin
  Result := S.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('\', '\\').Replace('@', '\@');
end;

function IsSpace(C: Char): Boolean; inline;
begin
  Result := (C = ' ') or (C = #9) or (C = #10);
end;

function IsAlnum(C: Char): Boolean; inline;
begin
  Result := C.IsLetterOrDigit;
end;

{ ---------------------------------------------------------------- inline }

function ConvertInline(const S: string): string;

  function FindClosing(AFrom: Integer; const ADelim: string; AIntraword: Boolean): Integer;
  var
    J: Integer;
  begin
    // closing delimiter: not preceded by a space, and (for "_") not followed by a letter/digit
    J := AFrom;
    while J <= Length(S) - Length(ADelim) + 1 do
    begin
      if S[J] = '\' then
        Inc(J, 2)
      else if S[J] = '`' then
      begin
        // skip code spans inside emphasis
        Inc(J);
        while (J <= Length(S)) and (S[J] <> '`') do
          Inc(J);
        Inc(J);
      end
      else if (Copy(S, J, Length(ADelim)) = ADelim) and not IsSpace(S[J - 1]) and
        (AIntraword or (J + Length(ADelim) > Length(S)) or not IsAlnum(S[J + Length(ADelim)])) and
        ((Length(ADelim) > 1) or (J + 1 > Length(S)) or (S[J + 1] <> S[J])) then
        Exit(J)
      else
        Inc(J);
    end;
    Result := 0;
  end;

var
  SB: TStringBuilder;
  I, J, K, N, Q: Integer;
  C: Char;
  Delim, Inner, Url, Title, Alt: string;
  M: TMatch;
begin
  SB := TStringBuilder.Create;
  try
    I := 1;
    while I <= Length(S) do
    begin
      C := S[I];
      if C = '\' then
      begin
        // keep the escape for the documentation parser, but do not interpret the next character here
        SB.Append(C);
        if I < Length(S) then
          SB.Append(S[I + 1]);
        Inc(I, 2);
      end
      else if C = '`' then
      begin
        N := 0;
        J := I;
        while (J <= Length(S)) and (S[J] = '`') do
        begin
          Inc(N);
          Inc(J);
        end;
        Delim := StringOfChar('`', N);
        K := Pos(Delim, S, J);
        while (K > 0) and (K + N <= Length(S)) and (S[K + N] = '`') do
          K := Pos(Delim, S, K + N + 1);
        if NativeQuotes and (N = 1) then
        begin
          // `text' : the first single quote ends the text when it comes before the closing backtick
          Q := Pos('''', S, J);
          if (Q > 0) and ((K = 0) or (Q < K)) then
          begin
            SB.Append('<code>').Append(EscapeCode(Copy(S, J, Q - J).Trim)).Append('</code>');
            I := Q + 1;
            Continue;
          end;
        end;
        if K = 0 then
        begin
          SB.Append(Delim);
          I := J;
        end
        else
        begin
          Inner := Copy(S, J, K - J).Trim;
          SB.Append('<code>').Append(EscapeCode(Inner)).Append('</code>');
          I := K + N;
        end;
      end
      else if C = '<' then
      begin
        M := TRegEx.Match(Copy(S, I, MaxInt), '^<((?:https?|ftp|mailto|file):[^\s>]+|[\w.+-]+@[\w-]+(?:\.[\w-]+)+)>');
        if M.Success then
        begin
          SB.Append(M.Groups[1].Value);
          Inc(I, M.Length);
        end
        else
        begin
          // HTML tag or comment: copy through
          J := Pos('>', S, I);
          if (J > 0) and TRegEx.IsMatch(Copy(S, I, 3), '^<[A-Za-z/!]') then
          begin
            SB.Append(Copy(S, I, J - I + 1));
            I := J + 1;
          end
          else
          begin
            SB.Append(C);
            Inc(I);
          end;
        end;
      end
      else if ((C = '[') or ((C = '!') and (I < Length(S)) and (S[I + 1] = '['))) then
      begin
        K := I;
        if C = '!' then
          Inc(K);
        // [text](url "title")
        M := TRegEx.Match(Copy(S, K, MaxInt), '^\[((?:[^\[\]\\]|\\.)*)\]\(\s*<?([^\s)>]*)>?(?:\s+"([^"]*)")?\s*\)');
        if M.Success then
        begin
          Inner := M.Groups[1].Value;
          Url := M.Groups[2].Value;
          if M.Groups.Count > 3 then // an optional trailing group is missing when it did not match
            Title := M.Groups[3].Value
          else
            Title := '';
          if C = '!' then
          begin
            Alt := Inner;
            SB.Append('<img src="').Append(Url).Append('" alt="').Append(Alt).Append('"');
            if Title <> '' then
              SB.Append(' title="').Append(Title).Append('"');
            SB.Append('/>');
          end
          else
          begin
            SB.Append('<a href="').Append(Url).Append('"');
            if Title <> '' then
              SB.Append(' title="').Append(Title).Append('"');
            SB.Append('>').Append(ConvertInline(Inner)).Append('</a>');
          end;
          I := K + M.Length;
        end
        else
        begin
          SB.Append(C);
          Inc(I);
        end;
      end
      else if (C = '*') or (C = '_') or ((C = '~') and (I < Length(S)) and (S[I + 1] = '~')) then
      begin
        if (I < Length(S)) and (S[I + 1] = C) then
          Delim := C + C
        else
          Delim := C;
        J := I + Length(Delim);
        // opening delimiter: followed by a non-space; "_" must start a word
        if (J <= Length(S)) and not IsSpace(S[J]) and
          ((C <> '_') or (I = 1) or not IsAlnum(S[I - 1])) and ((C <> '~') or (Delim = '~~')) then
        begin
          K := FindClosing(J, Delim, C <> '_');
          if K > J then
          begin
            Inner := ConvertInline(Copy(S, J, K - J));
            if Delim = '~~' then
              SB.Append('<strike>').Append(Inner).Append('</strike>')
            else if Length(Delim) = 2 then
              SB.Append('<strong>').Append(Inner).Append('</strong>')
            else
              SB.Append('<em>').Append(Inner).Append('</em>');
            I := K + Length(Delim);
            Continue;
          end;
        end;
        SB.Append(Delim);
        Inc(I, Length(Delim));
      end
      else if (C = ' ') and (Copy(S, I, 3) = '  ' + #10) then
      begin
        SB.Append('<br/>').Append(#10);
        Inc(I, 3);
      end
      else
      begin
        SB.Append(C);
        Inc(I);
      end;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

{ ---------------------------------------------------------------- blocks }

type
  TLines = TArray<string>;

function Blocks(const ALines: TLines): string; forward;

function IndentOf(const S: string): Integer;
begin
  Result := 0;
  while (Result < Length(S)) and (S[Result + 1] = ' ') do
    Inc(Result);
end;

function IsBlank(const S: string): Boolean;
begin
  Result := Trim(S) = '';
end;

function IsRule(const S: string): Boolean;
begin
  Result := TRegEx.IsMatch(S, '^ {0,3}([-*_])( ?\1){2,}\s*$');
end;

function ListMarker(const S: string; out AIndent, AContentCol: Integer; out AOrdered: Boolean): Boolean;
var
  M: TMatch;
begin
  M := TRegEx.Match(S, '^( *)([-*+]|\d+[.)])( +|$)');
  Result := M.Success and not IsRule(S);
  if Result then
  begin
    AIndent := Length(M.Groups[1].Value);
    AOrdered := M.Groups[2].Value[1].IsDigit;
    AContentCol := M.Length;
    if Length(M.Groups[3].Value) > 4 then
      AContentCol := AIndent + Length(M.Groups[2].Value) + 1;
  end;
end;

function IsTableSeparator(const S: string): Boolean;
begin
  Result := (Pos('-', S) > 0) and TRegEx.IsMatch(S, '^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$') and (Pos('|', S) > 0);
end;

function SplitRow(const S: string): TArray<string>;
var
  T: string;
  Parts: TArray<string>;
  I: Integer;
begin
  T := Trim(S);
  if T.StartsWith('|') then
    T := Copy(T, 2, MaxInt);
  if T.EndsWith('|') and not T.EndsWith('\|') then
    T := Copy(T, 1, Length(T) - 1);
  Parts := T.Split(['|']);
  for I := 0 to High(Parts) do
    Parts[I] := Trim(Parts[I].Replace('\|', '|'));
  Result := Parts;
end;

function ConvertTable(const AHeader, ASep: string; const ARows: TLines): string;
var
  Heads, Seps, Cells: TArray<string>;
  SB: TStringBuilder;
  I, J: Integer;
  Al: string;
begin
  SB := TStringBuilder.Create;
  try
    Heads := SplitRow(AHeader);
    Seps := SplitRow(ASep);
    SB.Append('<table>').Append(#10).Append('<tr>');
    for I := 0 to High(Heads) do
    begin
      Al := '';
      if I <= High(Seps) then
        if Seps[I].StartsWith(':') and Seps[I].EndsWith(':') then Al := ' align="center"'
        else if Seps[I].EndsWith(':') then Al := ' align="right"'
        else if Seps[I].StartsWith(':') then Al := ' align="left"';
      SB.Append('<th').Append(Al).Append('>').Append(ConvertInline(Heads[I])).Append('</th>');
    end;
    SB.Append('</tr>').Append(#10);
    for J := 0 to High(ARows) do
    begin
      Cells := SplitRow(ARows[J]);
      SB.Append('<tr>');
      for I := 0 to High(Cells) do
      begin
        Al := '';
        if I <= High(Seps) then
          if Seps[I].StartsWith(':') and Seps[I].EndsWith(':') then Al := ' align="center"'
          else if Seps[I].EndsWith(':') then Al := ' align="right"'
          else if Seps[I].StartsWith(':') then Al := ' align="left"';
        SB.Append('<td').Append(Al).Append('>').Append(ConvertInline(Cells[I])).Append('</td>');
      end;
      SB.Append('</tr>').Append(#10);
    end;
    SB.Append('</table>').Append(#10);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function Blocks(const ALines: TLines): string;
var
  SB: TStringBuilder;
  Para: TStringList;
  I, N, J, K, Ind, ContentCol, BaseInd, L: Integer;
  Line, Trimmed, EndCmd, Lang, Fence: string;
  Ordered, ListOrdered, Found, First: Boolean;
  VerbatimStartCmd: string;
  M: TMatch;
  Item, Rows, Code: TList<string>;
  PrevBlank: Boolean;

  procedure FlushPara;
  begin
    if Para.Count > 0 then
    begin
      SB.Append(ConvertInline(string.Join(#10, Para.ToStringArray))).Append(#10);
      Para.Clear;
    end;
  end;

begin
  SB := TStringBuilder.Create;
  Para := TStringList.Create;
  N := Length(ALines);
  I := 0;
  PrevBlank := True;
  try
    while I < N do
    begin
      Line := ALines[I];
      Trimmed := Trim(Line);

      // verbatim-like commands: copy unchanged up to the matching end command
      EndCmd := '';
      for K := 0 to High(VerbatimStarts) do
        if Trimmed.StartsWith(VerbatimStarts[K, 0]) and
          ((Length(Trimmed) = Length(VerbatimStarts[K, 0])) or not Trimmed[Length(VerbatimStarts[K, 0]) + 1].IsLetter
            or (VerbatimStarts[K, 0] = '\f[')) then
        begin
          EndCmd := VerbatimStarts[K, 1];
          Break;
        end;
      if EndCmd <> '' then
      begin
        FlushPara;
        First := True;
        repeat
          SB.Append(ALines[I]).Append(#10);
          if First then
            Found := Pos(EndCmd, Trimmed, Length(VerbatimStartCmd) + 1) > 0
          else
            Found := Pos(EndCmd, ALines[I]) > 0;
          First := False;
          Inc(I);
        until Found or (I >= N);
        PrevBlank := False;
        Continue;
      end;

      // fenced code
      M := TRegEx.Match(Line, '^ {0,3}(```+|~~~+)\s*([\w.+#-]*)');
      if M.Success then
      begin
        FlushPara;
        Fence := M.Groups[1].Value;
        Lang := M.Groups[2].Value;
        Inc(I);
        Code := TList<string>.Create;
        try
          while (I < N) and not Trim(ALines[I]).StartsWith(Fence) do
          begin
            Code.Add(ALines[I]);
            Inc(I);
          end;
          Inc(I);
          if Lang <> '' then
            SB.Append('\code{.').Append(Lang).Append('}').Append(#10)
          else
            SB.Append('\code').Append(#10);
          for L := 0 to Code.Count - 1 do
            SB.Append(Code[L]).Append(#10);
          SB.Append('\endcode').Append(#10);
        finally
          Code.Free;
        end;
        PrevBlank := False;
        Continue;
      end;

      if Trimmed = '' then
      begin
        FlushPara;
        SB.Append(#10);
        Inc(I);
        PrevBlank := True;
        Continue;
      end;

      // ATX header
      M := TRegEx.Match(Line, '^ {0,3}(#{1,6})\s+(.*?)(\s+#+)?\s*$');
      if M.Success then
      begin
        FlushPara;
        L := Length(M.Groups[1].Value);
        SB.Append('<h').Append(L.ToString).Append('>').Append(ConvertInline(M.Groups[2].Value)).Append('</h')
          .Append(L.ToString).Append('>').Append(#10);
        Inc(I);
        PrevBlank := False;
        Continue;
      end;

      // setext header: a text line followed by === or ---
      if (Para.Count = 1) and (TRegEx.IsMatch(Line, '^ {0,3}=+\s*$') or TRegEx.IsMatch(Line, '^ {0,3}-+\s*$')) then
      begin
        if Trimmed[1] = '=' then L := 1 else L := 2;
        SB.Append('<h').Append(L.ToString).Append('>').Append(ConvertInline(Trim(Para[0]))).Append('</h')
          .Append(L.ToString).Append('>').Append(#10);
        Para.Clear;
        Inc(I);
        Continue;
      end;

      if IsRule(Line) then
      begin
        FlushPara;
        SB.Append('<hr/>').Append(#10);
        Inc(I);
        PrevBlank := False;
        Continue;
      end;

      // block quote
      if Trimmed.StartsWith('>') then
      begin
        FlushPara;
        Item := TList<string>.Create;
        try
          while (I < N) and not IsBlank(ALines[I]) do
          begin
            Trimmed := TrimLeft(ALines[I]);
            if Trimmed.StartsWith('>') then
              Trimmed := Copy(Trimmed, 2, MaxInt).TrimLeft([' ']);
            Item.Add(Trimmed);
            Inc(I);
          end;
          SB.Append('<blockquote>').Append(#10).Append(Blocks(Item.ToArray)).Append('</blockquote>').Append(#10);
        finally
          Item.Free;
        end;
        PrevBlank := False;
        Continue;
      end;

      // table
      if (Pos('|', Line) > 0) and (I + 1 < N) and IsTableSeparator(ALines[I + 1]) and not IsTableSeparator(Line) then
      begin
        FlushPara;
        Rows := TList<string>.Create;
        try
          K := I + 2;
          while (K < N) and (Pos('|', ALines[K]) > 0) and not IsBlank(ALines[K]) do
          begin
            Rows.Add(ALines[K]);
            Inc(K);
          end;
          SB.Append(ConvertTable(Line, ALines[I + 1], Rows.ToArray));
          I := K;
        finally
          Rows.Free;
        end;
        PrevBlank := False;
        Continue;
      end;

      // list
      // bullets (and "1.") may interrupt a paragraph; other numbers may not
      if ListMarker(Line, BaseInd, ContentCol, ListOrdered) and
        ((Para.Count = 0) or not ListOrdered or TRegEx.IsMatch(Line, '^ *1[.)]')) then
      begin
        FlushPara;
        if ListOrdered then SB.Append('<ol>').Append(#10) else SB.Append('<ul>').Append(#10);
        while I < N do
        begin
          if not (ListMarker(ALines[I], Ind, ContentCol, Ordered) and (Ind = BaseInd) and (Ordered = ListOrdered)) then
            Break;
          Item := TList<string>.Create;
          try
            Item.Add(Copy(ALines[I], ContentCol + 1, MaxInt));
            Inc(I);
            while I < N do
            begin
              if IsBlank(ALines[I]) then
              begin
                // a blank line continues the item only if indented text follows
                K := I;
                while (K < N) and IsBlank(ALines[K]) do
                  Inc(K);
                if (K < N) and (IndentOf(ALines[K]) > BaseInd) then
                begin
                  while I < K do
                  begin
                    Item.Add('');
                    Inc(I);
                  end;
                  Continue;
                end;
                Break;
              end;
              if ListMarker(ALines[I], Ind, J, Ordered) and (Ind <= BaseInd) then
                Break;
              if IndentOf(ALines[I]) <= BaseInd then
              begin
                // lazy continuation of the item's paragraph
                if (Item.Count = 0) or IsBlank(Item[Item.Count - 1]) then
                  Break;
                Item.Add(ALines[I]);
              end
              else
                Item.Add(Copy(ALines[I], Min(IndentOf(ALines[I]), ContentCol) + 1, MaxInt));
              Inc(I);
            end;
            SB.Append('<li>').Append(Trim(Blocks(Item.ToArray))).Append('</li>').Append(#10);
          finally
            Item.Free;
          end;
          // loose lists: skip blank lines between items of the same list
          K := I;
          while (K < N) and IsBlank(ALines[K]) do
            Inc(K);
          if (K < N) and (K > I) and ListMarker(ALines[K], Ind, J, Ordered) and (Ind = BaseInd) and
            (Ordered = ListOrdered) then
            I := K;
        end;
        if ListOrdered then SB.Append('</ol>').Append(#10) else SB.Append('</ul>').Append(#10);
        PrevBlank := False;
        Continue;
      end;

      // indented code block (after a blank line, not continuing a paragraph)
      if PrevBlank and (Para.Count = 0) and (IndentOf(Line) >= 4) then
      begin
        Code := TList<string>.Create;
        try
          while (I < N) and (IsBlank(ALines[I]) or (IndentOf(ALines[I]) >= 4)) do
          begin
            Code.Add(Copy(ALines[I], 5, MaxInt));
            Inc(I);
          end;
          while (Code.Count > 0) and IsBlank(Code[Code.Count - 1]) do
            Code.Delete(Code.Count - 1);
          SB.Append('\code').Append(#10);
          for L := 0 to Code.Count - 1 do
            SB.Append(Code[L]).Append(#10);
          SB.Append('\endcode').Append(#10);
        finally
          Code.Free;
        end;
        Continue;
      end;

      Para.Add(Line);
      PrevBlank := False;
      Inc(I);
    end;
    FlushPara;
    Result := SB.ToString;
  finally
    Para.Free;
    SB.Free;
  end;
end;

function MarkdownToDoxygen(const AText: string; ATabSize: Integer; AStrict: Boolean): string;
var
  Lines: TArray<string>;
  I: Integer;
begin
  NativeQuotes := not AStrict;
  Lines := AText.Replace(#13#10, #10).Replace(#13, #10).Split([#10]);
  for I := 0 to High(Lines) do
    Lines[I] := Lines[I].Replace(#9, StringOfChar(' ', ATabSize)).TrimRight([#13]);
  Result := Blocks(Lines).TrimRight([#10]);
end;

end.
