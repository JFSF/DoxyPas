unit DoxyPas.Output.HtmlCode;

{ Syntax colouring of Pascal code for the HTML output, with the span classes of Doxygen's style sheet (keyword,
  keywordtype, keywordflow, comment, preprocessor, stringliteral). }

interface

/// <summary>One &lt;div class="line"&gt; per line of ACode, coloured.</summary>
function HighlightPascal(const ACode: string): string;

type
  /// <summary>The URL an identifier links to, or '' for no link.</summary>
  TWordLinker = reference to function(const AWord: string): string;

/// <summary>Like HighlightPascal, with Doxygen's line numbers and anchors (l00001) and links on identifiers.
/// AStripDocComments (STRIP_CODE_COMMENTS) leaves out the documentation comments (///, //!, {**, (**) and keeps their lines.</summary>
function HighlightSource(const ACode: string; ALineNumbers: Boolean; const ALink: TWordLinker;
  AFirstLine: Integer = 1; AStripDocComments: Boolean = False): string;

type
  /// <summary>A piece of a line of code with its colour class ('' for plain text).</summary>
  TCodeSpan = record
    Cls: string;
    Text: string;
  end;

/// <summary>The lines of ACode as lists of coloured pieces (for the program listing of the XML output).</summary>
function CodeLines(const ACode: string): TArray<TArray<TCodeSpan>>;

/// <summary>&lt;span class="keyword"&gt;AWord&lt;/span&gt;</summary>
function KeywordSpan(const AWord: string): string;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DoxyPas.Output.HtmlTemplate;

var
  Flow, Types, Keywords: TDictionary<string, Boolean>;

procedure InitWords;
var
  S: string;
begin
  Flow := TDictionary<string, Boolean>.Create;
  Types := TDictionary<string, Boolean>.Create;
  Keywords := TDictionary<string, Boolean>.Create;
  for S in ['if', 'then', 'else', 'for', 'to', 'downto', 'do', 'while', 'repeat', 'until', 'case', 'of', 'begin',
    'end', 'try', 'except', 'finally', 'with', 'goto', 'break', 'continue', 'exit', 'raise'] do
    Flow.Add(S, True);
  for S in ['integer', 'cardinal', 'int64', 'uint64', 'byte', 'word', 'longint', 'longword', 'shortint', 'smallint',
    'boolean', 'char', 'widechar', 'ansichar', 'string', 'ansistring', 'unicodestring', 'widestring', 'shortstring',
    'single', 'double', 'extended', 'real', 'currency', 'pointer', 'variant', 'tobject', 'nativeint', 'nativeuint'] do
    Types.Add(S, True);
  for S in ['unit', 'program', 'library', 'package', 'uses', 'interface', 'implementation', 'initialization',
    'finalization', 'type', 'var', 'const', 'procedure', 'function', 'constructor', 'destructor', 'property', 'class',
    'record', 'object', 'array', 'set', 'file', 'packed', 'private', 'protected', 'public', 'published', 'strict',
    'virtual', 'override', 'abstract', 'overload', 'reintroduce', 'inherited', 'out', 'in', 'is', 'as', 'not', 'and',
    'or', 'xor', 'div', 'mod', 'shl', 'shr', 'nil', 'true', 'false', 'read', 'write', 'default', 'index', 'stored',
    'inline', 'static', 'final', 'sealed', 'forward', 'external', 'stdcall', 'cdecl', 'register', 'helper', 'operator',
    'resourcestring', 'threadvar', 'generic', 'specialization', 'dynamic', 'message', 'name', 'implements'] do
    Keywords.Add(S, True);
end;

function KeywordSpan(const AWord: string): string;
begin
  Result := '<span class="keyword">' + HtmlEscape(AWord) + '</span>';
end;

type
  TTok = record
    Cls: string;   // '' = plain
    Text: string;
  end;

function Tokenize(const S: string): TArray<TTok>;
var
  L: TList<TTok>;
  I, N, J: Integer;
  C: Char;
  Low: string;

  procedure Emit(const ACls: string; AFrom, ATo: Integer);
  var
    T: TTok;
  begin
    T.Cls := ACls;
    T.Text := Copy(S, AFrom, ATo - AFrom);
    L.Add(T);
  end;

begin
  L := TList<TTok>.Create;
  try
    I := 1;
    N := Length(S);
    while I <= N do
    begin
      C := S[I];
      J := I;
      if (C = '/') and (I < N) and (S[I + 1] = '/') then
      begin
        while (J <= N) and (S[J] <> #10) do
          Inc(J);
        Emit('comment', I, J);
      end
      else if C = '{' then
      begin
        while (J <= N) and (S[J] <> '}') do
          Inc(J);
        if J <= N then
          Inc(J);
        if (I < N) and (S[I + 1] = '$') then
          Emit('preprocessor', I, J)
        else
          Emit('comment', I, J);
      end
      else if (C = '(') and (I < N) and (S[I + 1] = '*') then
      begin
        J := I + 2;
        while (J < N) and not ((S[J] = '*') and (S[J + 1] = ')')) do
          Inc(J);
        J := J + 2;
        if J > N + 1 then
          J := N + 1;
        Emit('comment', I, J);
      end
      else if C = '''' then
      begin
        Inc(J);
        while J <= N do
        begin
          if S[J] = '''' then
          begin
            if (J < N) and (S[J + 1] = '''') then
              Inc(J)
            else
              Break;
          end
          else if S[J] = #10 then
            Break;
          Inc(J);
        end;
        if (J <= N) and (S[J] = '''') then
          Inc(J);
        Emit('stringliteral', I, J);
      end
      else if CharInSet(C, ['a'..'z', 'A'..'Z', '_']) then
      begin
        while (J <= N) and CharInSet(S[J], ['a'..'z', 'A'..'Z', '_', '0'..'9']) do
          Inc(J);
        Low := LowerCase(Copy(S, I, J - I));
        if Flow.ContainsKey(Low) then Emit('keywordflow', I, J)
        else if Types.ContainsKey(Low) then Emit('keywordtype', I, J)
        else if Keywords.ContainsKey(Low) then Emit('keyword', I, J)
        else Emit('', I, J);
      end
      else if CharInSet(C, ['0'..'9']) or ((C = '$') and (I < N) and CharInSet(S[I + 1], ['0'..'9', 'a'..'f', 'A'..'F'])) then
      begin
        Inc(J);
        while (J <= N) and CharInSet(S[J], ['0'..'9', 'a'..'f', 'A'..'F', '.']) and
          not ((S[J] = '.') and (J < N) and (S[J + 1] = '.')) do
          Inc(J);
        Emit('charliteral', I, J);
      end
      else
      begin
        Inc(J);
        Emit('', I, J);
      end;
      I := J;
    end;
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

// A comment Doxygen treats as documentation: ///, //!, {*, {!, (** and (*!
function IsDocComment(const AText: string): Boolean;
begin
  Result := AText.StartsWith('///') or AText.StartsWith('//!') or AText.StartsWith('{*') or AText.StartsWith('{!') or
    AText.StartsWith('(**') or AText.StartsWith('(*!');
end;

function HighlightSource(const ACode: string; ALineNumbers: Boolean; const ALink: TWordLinker;
  AFirstLine: Integer = 1; AStripDocComments: Boolean = False): string;
var
  SB: TStringBuilder;
  T: TTok;
  Parts: TArray<string>;
  K, Line: Integer;
  Open, Strip: Boolean;
  Href, Tip: string;

  procedure StartLine;
  begin
    SB.Append('<div class="line">');
    if ALineNumbers then
      SB.Append('<a id="l').Append(Format('%.5d', [Line])).Append('" name="l').Append(Format('%.5d', [Line])).
        Append('"></a><span class="lineno">').Append(Format('%5d', [Line]).Replace(' ', '&#160;')).
        Append('</span>&#160;');
  end;

begin
  Line := AFirstLine;
  SB := TStringBuilder.Create;
  try
    StartLine;
    for T in Tokenize(ACode.Replace(#13#10, #10)) do
    begin
      Parts := T.Text.Split([#10]);
      for K := 0 to High(Parts) do
      begin
        if K > 0 then
        begin
          SB.Append('</div>');
          Inc(Line);
          StartLine;
        end;
        Strip := AStripDocComments and (T.Cls = 'comment') and IsDocComment(T.Text);
        if Strip then
          Continue;
        Open := (T.Cls <> '') and (Parts[K] <> '');
        if Open then
          SB.Append('<span class="' + T.Cls + '">');
        Href := '';
        if Assigned(ALink) and (T.Cls = '') and (Parts[K] <> '') and CharInSet(Parts[K][1], ['A'..'Z', 'a'..'z', '_']) then
          Href := ALink(Parts[K]);
        if Href <> '' then
        begin
          // the linker may add a tooltip after a #1: "url#1text" (the text is HTML already)
          Tip := '';
          if Pos(#1, Href) > 0 then
          begin
            Tip := Copy(Href, Pos(#1, Href) + 1, MaxInt);
            Href := Copy(Href, 1, Pos(#1, Href) - 1);
          end;
          SB.Append('<a class="code" href="' + HtmlEscape(Href) + '"');
          if Tip <> '' then
            SB.Append(' title="' + Tip + '"');
          SB.Append('>' + HtmlEscape(Parts[K]) + '</a>');
        end
        else
          SB.Append(HtmlEscape(Parts[K]).Replace('  ', '&#160; '));
        if Open then
          SB.Append('</span>');
      end;
    end;
    SB.Append('</div>');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function CodeLines(const ACode: string): TArray<TArray<TCodeSpan>>;
var
  T: TTok;
  Parts: TArray<string>;
  K: Integer;
  Cur: TList<TCodeSpan>;
  Lines: TList<TArray<TCodeSpan>>;
  S: TCodeSpan;
begin
  Lines := TList<TArray<TCodeSpan>>.Create;
  Cur := TList<TCodeSpan>.Create;
  try
    for T in Tokenize(ACode.Replace(#13#10, #10)) do
    begin
      Parts := T.Text.Split([#10]);
      for K := 0 to High(Parts) do
      begin
        if K > 0 then
        begin
          Lines.Add(Cur.ToArray);
          Cur.Clear;
        end;
        if Parts[K] <> '' then
        begin
          if (T.Cls = '') and (Cur.Count > 0) and (Cur.Last.Cls = '') then
          begin
            S := Cur.Last;                       // neighbouring plain pieces are one
            S.Text := S.Text + Parts[K];
            Cur[Cur.Count - 1] := S;
          end
          else
          begin
            S.Cls := T.Cls;
            S.Text := Parts[K];
            Cur.Add(S);
          end;
        end;
      end;
    end;
    Lines.Add(Cur.ToArray);
    Result := Lines.ToArray;
  finally
    Cur.Free;
    Lines.Free;
  end;
end;

function HighlightPascal(const ACode: string): string;
begin
  Result := HighlightSource(ACode, False, nil);
end;

initialization
  InitWords;

finalization
  Keywords.Free;
  Types.Free;
  Flow.Free;

end.
