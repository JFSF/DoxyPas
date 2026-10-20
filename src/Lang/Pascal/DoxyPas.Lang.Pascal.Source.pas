unit DoxyPas.Lang.Pascal.Source;

{ Tolerant Object Pascal tokenizer. DelphiAST gives the structure of a unit; this gives the exact source text
  of types, default values and directives, and the comments (which DelphiAST only lists loosely). }

interface

type
  TPasTokenKind = (tkEOF, tkIdent, tkNumber, tkString, tkSymbol, tkLineComment, tkBlockComment, tkDirective);

  TPasToken = record
    Kind: TPasTokenKind;
    Start: Integer;          // 1-based index into the source text
    Len: Integer;
    Line, Col: Integer;      // 1-based, first character of the token
    EndLine, EndCol: Integer; // position just after the token
  end;

  TPasSource = class
  strict private
    FText: string;
    FTokens: TArray<TPasToken>;
    procedure Tokenize;
  public
    constructor Create(const AText: string);
    property Text: string read FText;
    /// <summary>Number of tokens, including the final tkEOF.</summary>
    function Count: Integer;
    function Token(AIndex: Integer): TPasToken;
    function TokenText(AIndex: Integer): string;
    function IsComment(AIndex: Integer): Boolean;
    /// <summary>True if the token is the symbol/punctuation S.</summary>
    function IsSymbol(AIndex: Integer; const S: string): Boolean;
    /// <summary>True if the token is the identifier/keyword W (case-insensitive).</summary>
    function IsWord(AIndex: Integer; const W: string): Boolean;
    /// <summary>Index of the first token starting at or after (ALine, ACol); the EOF token if none.</summary>
    function IndexAt(ALine, ACol: Integer): Integer;
    /// <summary>Next token after AIndex that is not a comment or compiler directive.</summary>
    function NextCode(AIndex: Integer): Integer;
    function PrevCode(AIndex: Integer): Integer;
    /// <summary>Source text of the code tokens in [AFrom, ATo): comments dropped, whitespace collapsed.</summary>
    function Slice(AFrom, ATo: Integer): string;
    /// <summary>First token at or after AStart, outside any (), [], &lt;&gt; (if AAngle) or record/object
    /// body, that is one of the symbols in AStopSymbols (single characters) or one of the lower-case
    /// words in AStopWords. A closing ')' / ']' at depth 0 stops too if listed.</summary>
    function ScanTo(AStart: Integer; const AStopSymbols: string; const AStopWords: array of string;
      AAngle: Boolean): Integer;
  end;

implementation

uses
  System.SysUtils,
  System.Character,
  System.Generics.Collections;

constructor TPasSource.Create(const AText: string);
begin
  inherited Create;
  FText := AText;
  Tokenize;
end;

function TPasSource.Count: Integer;
begin
  Result := Length(FTokens);
end;

function TPasSource.Token(AIndex: Integer): TPasToken;
begin
  if AIndex >= Length(FTokens) then
    AIndex := High(FTokens);
  Result := FTokens[AIndex];
end;

function TPasSource.TokenText(AIndex: Integer): string;
begin
  with Token(AIndex) do
    Result := Copy(FText, Start, Len);
end;

function TPasSource.IsComment(AIndex: Integer): Boolean;
begin
  Result := Token(AIndex).Kind in [tkLineComment, tkBlockComment, tkDirective];
end;

function TPasSource.IsSymbol(AIndex: Integer; const S: string): Boolean;
begin
  with Token(AIndex) do
    Result := (Kind = tkSymbol) and (Len = Length(S)) and (Copy(FText, Start, Len) = S);
end;

function TPasSource.IsWord(AIndex: Integer; const W: string): Boolean;
begin
  with Token(AIndex) do
    Result := (Kind = tkIdent) and (Len = Length(W)) and SameText(Copy(FText, Start, Len), W);
end;

function TPasSource.IndexAt(ALine, ACol: Integer): Integer;
var
  Lo, Hi, Mid: Integer;
begin
  Lo := 0;
  Hi := High(FTokens);
  while Lo < Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if (FTokens[Mid].Line < ALine) or ((FTokens[Mid].Line = ALine) and (FTokens[Mid].Col < ACol)) then
      Lo := Mid + 1
    else
      Hi := Mid;
  end;
  Result := Lo;
end;

function TPasSource.NextCode(AIndex: Integer): Integer;
begin
  Result := AIndex + 1;
  while (Result < High(FTokens)) and IsComment(Result) do
    Inc(Result);
  if Result > High(FTokens) then
    Result := High(FTokens);
end;

function TPasSource.PrevCode(AIndex: Integer): Integer;
begin
  Result := AIndex - 1;
  while (Result > 0) and IsComment(Result) do
    Dec(Result);
  if Result < 0 then
    Result := 0;
end;

function TPasSource.Slice(AFrom, ATo: Integer): string;
var
  I, PrevEnd: Integer;
  T: TPasToken;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    PrevEnd := -1;
    for I := AFrom to ATo - 1 do
    begin
      T := Token(I);
      if T.Kind in [tkEOF, tkLineComment, tkBlockComment, tkDirective] then
        Continue;
      if (PrevEnd >= 0) and (T.Start > PrevEnd) then
        SB.Append(' ');
      SB.Append(Copy(FText, T.Start, T.Len).Replace(#13#10, ' ').Replace(#10, ' ').Replace(#13, ' '));
      PrevEnd := T.Start + T.Len;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TPasSource.ScanTo(AStart: Integer; const AStopSymbols: string; const AStopWords: array of string;
  AAngle: Boolean): Integer;
var
  Depth, Body, I, J: Integer;
  T: TPasToken;
  S, W: string;
begin
  Depth := 0;
  Body := 0;
  I := AStart;
  while I < High(FTokens) do
  begin
    T := FTokens[I];
    case T.Kind of
      tkSymbol:
        begin
          S := Copy(FText, T.Start, T.Len);
          if (S = '(') or (S = '[') then
            Inc(Depth)
          else if AAngle and (S = '<') then
            Inc(Depth)
          else if (S = ')') or (S = ']') or (AAngle and (S = '>')) then
          begin
            if (Depth = 0) and (Body = 0) and (Pos(S, AStopSymbols) > 0) then
              Exit(I);
            if Depth > 0 then
              Dec(Depth);
          end
          else if (Depth = 0) and (Body = 0) and (T.Len = 1) and (Pos(S, AStopSymbols) > 0) then
            Exit(I);
        end;
      tkIdent:
        begin
          W := LowerCase(Copy(FText, T.Start, T.Len));
          if (Depth = 0) and (Body = 0) then
            for J := 0 to High(AStopWords) do
              if W = AStopWords[J] then
                Exit(I);
          if (W = 'record') or (W = 'object') or (W = 'interface') or (W = 'dispinterface') then
          begin
            // "procedure ... of object" is not a body
            J := PrevCode(I);
            if not ((W = 'object') and IsWord(J, 'of')) then
              Inc(Body);
          end
          else if (W = 'end') and (Body > 0) then
            Dec(Body);
        end;
    end;
    Inc(I);
  end;
  Result := High(FTokens);
end;

procedure TPasSource.Tokenize;
var
  Tokens: TList<TPasToken>;
  P, L, Line, Col: Integer;

  procedure Adv(N: Integer);
  var
    K: Integer;
  begin
    for K := 1 to N do
    begin
      if P > L then
        Exit;
      if FText[P] = #13 then
      begin
        if (P < L) and (FText[P + 1] = #10) then
          Inc(P);
        Inc(Line);
        Col := 1;
      end
      else if FText[P] = #10 then
      begin
        Inc(Line);
        Col := 1;
      end
      else
        Inc(Col);
      Inc(P);
    end;
  end;

  procedure Emit(AKind: TPasTokenKind; AStart, ALen, ALine, ACol: Integer);
  var
    T: TPasToken;
  begin
    T.Kind := AKind;
    T.Start := AStart;
    T.Len := ALen;
    T.Line := ALine;
    T.Col := ACol;
    T.EndLine := Line;
    T.EndCol := Col;
    Tokens.Add(T);
  end;

  function At(AOffset: Integer): Char;
  begin
    if P + AOffset <= L then
      Result := FText[P + AOffset]
    else
      Result := #0;
  end;

  function IsIdentStart(C: Char): Boolean;
  begin
    Result := (C = '_') or C.IsLetter;
  end;

  function IsIdentChar(C: Char): Boolean;
  begin
    Result := (C = '_') or C.IsLetterOrDigit;
  end;

  function IsHex(C: Char): Boolean;
  begin
    Result := CharInSet(C, ['0'..'9', 'a'..'f', 'A'..'F']);
  end;

  procedure LexString(S, SLine, SCol: Integer);
  var
    Q: Integer;
    Multi: Boolean;
  begin
    // Delphi 12 multi-line string: ''' followed by end of line ... ''' on a line of its own
    Multi := (At(0) = '''') and (At(1) = '''') and (At(2) = '''');
    if Multi then
    begin
      Q := 3;
      while (At(Q) = ' ') or (At(Q) = #9) do
        Inc(Q);
      Multi := (At(Q) = #13) or (At(Q) = #10);
    end;
    if Multi then
    begin
      Adv(3);
      while P <= L do
      begin
        if (At(0) = #10) or (At(0) = #13) then
        begin
          Adv(1);
          while (At(0) = ' ') or (At(0) = #9) do
            Adv(1);
          if (At(0) = '''') and (At(1) = '''') and (At(2) = '''') then
          begin
            Adv(3);
            Break;
          end;
        end
        else
          Adv(1);
      end;
    end
    else
    begin
      Adv(1);
      while (P <= L) and (At(0) <> #10) and (At(0) <> #13) do
        if At(0) = '''' then
        begin
          Adv(1);
          if At(0) = '''' then
            Adv(1)
          else
            Break;
        end
        else
          Adv(1);
    end;
    Emit(tkString, S, P - S, SLine, SCol);
  end;

var
  S, SLine, SCol: Integer;
  C: Char;
  Two: string;
begin
  Tokens := TList<TPasToken>.Create;
  try
    L := Length(FText);
    P := 1;
    Line := 1;
    Col := 1;
    while P <= L do
    begin
      C := FText[P];
      if C <= ' ' then
      begin
        Adv(1);
        Continue;
      end;
      S := P;
      SLine := Line;
      SCol := Col;
      if (C = '/') and (At(1) = '/') then
      begin
        while (P <= L) and (At(0) <> #10) and (At(0) <> #13) do
          Adv(1);
        Emit(tkLineComment, S, P - S, SLine, SCol);
      end
      else if C = '{' then
      begin
        while (P <= L) and (At(0) <> '}') do
          Adv(1);
        Adv(1);
        if (S + 1 <= L) and (FText[S + 1] = '$') then
          Emit(tkDirective, S, P - S, SLine, SCol)
        else
          Emit(tkBlockComment, S, P - S, SLine, SCol);
      end
      else if (C = '(') and (At(1) = '*') then
      begin
        Adv(2);
        while (P <= L) and not ((At(0) = '*') and (At(1) = ')')) do
          Adv(1);
        Adv(2);
        if (S + 2 <= L) and (FText[S + 2] = '$') then
          Emit(tkDirective, S, P - S, SLine, SCol)
        else
          Emit(tkBlockComment, S, P - S, SLine, SCol);
      end
      else if C = '''' then
        LexString(S, SLine, SCol)
      else if (C = '#') and (IsHex(At(1)) or (At(1) = '$')) then
      begin
        Adv(1);
        if At(0) = '$' then
          Adv(1);
        while IsHex(At(0)) do
          Adv(1);
        Emit(tkString, S, P - S, SLine, SCol);
      end
      else if C.IsDigit or ((C = '$') and IsHex(At(1))) then
      begin
        if C = '$' then
        begin
          Adv(1);
          while IsHex(At(0)) do
            Adv(1);
        end
        else
        begin
          while At(0).IsDigit do
            Adv(1);
          if (At(0) = '.') and At(1).IsDigit then
          begin
            Adv(1);
            while At(0).IsDigit do
              Adv(1);
          end;
          if CharInSet(At(0), ['e', 'E']) and (At(1).IsDigit or (CharInSet(At(1), ['+', '-']) and At(2).IsDigit)) then
          begin
            Adv(2);
            while At(0).IsDigit do
              Adv(1);
          end;
        end;
        Emit(tkNumber, S, P - S, SLine, SCol);
      end
      else if IsIdentStart(C) or ((C = '&') and IsIdentStart(At(1))) then
      begin
        Adv(1);
        while IsIdentChar(At(0)) do
          Adv(1);
        Emit(tkIdent, S, P - S, SLine, SCol);
      end
      else
      begin
        Two := Copy(FText, P, 2);
        if (Two = ':=') or (Two = '<>') or (Two = '<=') or (Two = '>=') or (Two = '..') or (Two = '+=') or
          (Two = '-=') or (Two = '*=') or (Two = '/=') or (Two = '@@') then
          Adv(2)
        else
          Adv(1);
        Emit(tkSymbol, S, P - S, SLine, SCol);
      end;
    end;
    Emit(tkEOF, P, 0, Line, Col);
    FTokens := Tokens.ToArray;
  finally
    Tokens.Free;
  end;
end;

end.
