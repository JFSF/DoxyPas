unit DoxyPas.Output.HtmlTemplate;

{ Helpers for the HTML output taken from Doxygen's htmlgen/util: conditional blocks and $keywords of the
  header/footer templates, the colour markers (##AA) and the style sheet assembled for HTML_COLORSTYLE. }

interface

uses
  System.Generics.Collections;

type
  TColorStyle = (csLight, csDark, csAutoLight, csAutoDark, csToggle);

  THtmlColors = record
    Style: TColorStyle;
    Hue, Sat, Gamma: Integer;      // HTML_COLORSTYLE_HUE / _SAT / _GAMMA
    class function Parse(const AStyle: string; AHue, ASat, AGamma: Integer): THtmlColors; static;
  end;

/// <summary>Removes the blocks between &lt;!--BEGIN NAME--&gt; and &lt;!--END NAME--&gt; whose name is disabled (or
/// enabled, for &lt;!--BEGIN !NAME--&gt;) and all block markers.</summary>
function SelectBlocks(const S: string; AEnabled: TDictionary<string, Boolean>): string;

/// <summary>Replaces $keywords (the longest matching key wins).</summary>
function SubstituteKeywords(const S: string; AKeys: TDictionary<string, string>): string;

function RemoveEmptyLines(const S: string): string;

/// <summary>"##AA" -> "#rrggbb" according to hue, saturation and gamma.</summary>
function ReplaceColorMarkers(const S: string; const AColors: THtmlColors): string;

/// <summary>Replaces var(--name) by the value defined in ASettings (the contents of a *_settings.css file).</summary>
function ReplaceVariables(const S, ASettings: string): string;

/// <summary>The doxygen.css written to the output: colour settings according to the colour style, the style sheet
/// itself and the scrollbar styling.</summary>
function BuildStyleSheet(const AColors: THtmlColors; const ALight, ADark, ACss, AScrollbar, AVersion: string;
  AFullSidebar, AAddScrollbar: Boolean): string;

/// <summary>The same replacement for the other style sheets and scripts (tabs.css, navtree.css, ...).</summary>
function ApplyColorStyle(const S: string; const AColors: THtmlColors; const ALight, ADark: string): string;

function HtmlEscape(const S: string): string;
function JsString(const S: string): string;

implementation

uses
  System.SysUtils,
  System.Math,
  System.StrUtils,
  System.Generics.Defaults;

class function THtmlColors.Parse(const AStyle: string; AHue, ASat, AGamma: Integer): THtmlColors;
begin
  if SameText(AStyle, 'LIGHT') then Result.Style := csLight
  else if SameText(AStyle, 'DARK') then Result.Style := csDark
  else if SameText(AStyle, 'AUTO_DARK') then Result.Style := csAutoDark
  else if SameText(AStyle, 'TOGGLE') then Result.Style := csToggle
  else Result.Style := csAutoLight;
  Result.Hue := AHue;
  Result.Sat := ASat;
  Result.Gamma := AGamma;
end;

function SelectBlocks(const S: string; AEnabled: TDictionary<string, Boolean>): string;
const
  BeginM = '<!--BEGIN ';
  EndM = '<!--END ';
  CloseM = '-->';
var
  SB: TStringBuilder;
  P, Q, N: Integer;
  Name: string;
  Negate, On_: Boolean;

  // reads "[!]NAME-->" at APos; returns the position after the marker, or 0 if it is not a known block marker
  function ReadMarker(APos: Integer; out AName: string; out ANegate: Boolean): Integer;
  var
    E: Integer;
  begin
    Result := 0;
    ANegate := (APos <= Length(S)) and (S[APos] = '!');
    if ANegate then
      Inc(APos);
    E := PosEx(CloseM, S, APos);
    if E = 0 then
      Exit;
    AName := Copy(S, APos, E - APos);
    if AEnabled.ContainsKey(AName) then
      Result := E + Length(CloseM);
  end;

  // the position after the END marker of AName
  function SkipBlock(AFrom: Integer; const AName: string): Integer;
  var
    I, After: Integer;
    N2: string;
    Neg: Boolean;
  begin
    I := AFrom;
    while I <= Length(S) do
    begin
      if (S[I] = '<') and (string.CompareOrdinal(S, I - 1, EndM, 0, Length(EndM)) = 0) then
      begin
        After := ReadMarker(I + Length(EndM), N2, Neg);
        if (After > 0) and (N2 = AName) then
          Exit(After);
      end;
      Inc(I);
    end;
    Result := Length(S) + 1;
  end;

begin
  SB := TStringBuilder.Create;
  try
    P := 1;
    N := Length(S);
    while P <= N do
    begin
      if S[P] = '<' then
      begin
        if string.CompareOrdinal(S, P - 1, BeginM, 0, Length(BeginM)) = 0 then
        begin
          Q := ReadMarker(P + Length(BeginM), Name, Negate);
          if Q > 0 then
          begin
            On_ := AEnabled[Name] <> Negate;
            P := Q;
            if not On_ then
              P := SkipBlock(P, Name);
            Continue;
          end;
        end
        else if string.CompareOrdinal(S, P - 1, EndM, 0, Length(EndM)) = 0 then
        begin
          Q := ReadMarker(P + Length(EndM), Name, Negate);
          if Q > 0 then
          begin
            P := Q;
            Continue;
          end;
        end;
      end;
      SB.Append(S[P]);
      Inc(P);
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function SubstituteKeywords(const S: string; AKeys: TDictionary<string, string>): string;
var
  Keys: TArray<string>;
  SB: TStringBuilder;
  P, N: Integer;
  K: string;
  Found: Boolean;
begin
  Keys := AKeys.Keys.ToArray;
  TArray.Sort<string>(Keys, TComparer<string>.Construct(
    function(const A, B: string): Integer
    begin
      Result := Length(B) - Length(A);
    end));
  SB := TStringBuilder.Create;
  try
    P := 1;
    N := Length(S);
    while P <= N do
    begin
      Found := False;
      if S[P] = '$' then
        for K in Keys do
          if string.CompareOrdinal(S, P - 1, K, 0, Length(K)) = 0 then
          begin
            SB.Append(AKeys[K]);
            Inc(P, Length(K));
            Found := True;
            Break;
          end;
      if not Found then
      begin
        SB.Append(S[P]);
        Inc(P);
      end;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function RemoveEmptyLines(const S: string): string;
var
  Lines: TArray<string>;
  SB: TStringBuilder;
  L: string;
begin
  SB := TStringBuilder.Create;
  try
    Lines := S.Replace(#13#10, #10).Split([#10]);
    for L in Lines do
      if Trim(L) <> '' then
        SB.Append(L).Append(#10);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

procedure Hsl2Rgb(H, S, L: Double; out R, G, B: Double);
var
  V, M, SV, Fract, VSF, Mid1, Mid2: Double;
  Sextant: Integer;
begin
  R := L;
  G := L;
  B := L;
  if L <= 0.5 then
    V := L * (1.0 + S)
  else
    V := L + S - L * S;
  if V > 0 then
  begin
    M := L + L - V;
    SV := (V - M) / V;
    H := H * 6.0;
    Sextant := Trunc(H);
    Fract := H - Sextant;
    VSF := V * SV * Fract;
    Mid1 := M + VSF;
    Mid2 := V - VSF;
    case Sextant of
      0: begin R := V; G := Mid1; B := M; end;
      1: begin R := Mid2; G := V; B := M; end;
      2: begin R := M; G := V; B := Mid1; end;
      3: begin R := M; G := Mid2; B := V; end;
      4: begin R := Mid1; G := M; B := V; end;
      5: begin R := V; G := M; B := Mid2; end;
    end;
  end;
end;

function IsHex(C: Char): Boolean;
begin
  Result := CharInSet(C, ['0'..'9', 'a'..'f', 'A'..'F']);
end;

function ReplaceColorMarkers(const S: string; const AColors: THtmlColors): string;
var
  SB: TStringBuilder;
  P, N, Level: Integer;
  R, G, B: Double;
begin
  SB := TStringBuilder.Create;
  try
    P := 1;
    N := Length(S);
    while P <= N do
    begin
      if (S[P] = '#') and (P + 3 <= N) and (S[P + 1] = '#') and IsHex(S[P + 2]) and IsHex(S[P + 3]) then
      begin
        Level := StrToInt('$' + Copy(S, P + 2, 2));
        Hsl2Rgb(AColors.Hue / 360.0, AColors.Sat / 255.0, Power(Level / 255.0, AColors.Gamma / 100.0), R, G, B);
        SB.Append(LowerCase(Format('#%.2x%.2x%.2x', [Trunc(R * 255.0), Trunc(G * 255.0), Trunc(B * 255.0)])));
        Inc(P, 4);
      end
      else
      begin
        SB.Append(S[P]);
        Inc(P);
      end;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

// "--name: value;" lines -> name/value pairs
function ParseSettings(const ASettings: string): TDictionary<string, string>;
var
  Line: string;
  C, Semi: Integer;
begin
  Result := TDictionary<string, string>.Create;
  for Line in ASettings.Replace(#13#10, #10).Split([#10]) do
    if Line.StartsWith('--') then
    begin
      C := Pos(':', Line);
      Semi := LastDelimiter(';', Line);
      if (C > 0) and (Semi > C) then
        Result.AddOrSetValue(Copy(Line, 1, C - 1), Trim(Copy(Line, C + 1, Semi - C - 1)));
    end;
end;

function ReplaceVariables(const S, ASettings: string): string;
var
  Map: TDictionary<string, string>;
  SB: TStringBuilder;
  P, I, J: Integer;
  Value: string;
begin
  Map := ParseSettings(ASettings);
  SB := TStringBuilder.Create;
  try
    P := 1;
    repeat
      I := PosEx('var(', S, P);
      if I = 0 then
        Break;
      J := PosEx(')', S, I + 4);
      if J = 0 then
        Break;
      SB.Append(Copy(S, P, I - P));
      if Map.TryGetValue(Copy(S, I + 4, J - I - 4), Value) then
        SB.Append(Value)
      else
        SB.Append(Copy(S, I, J - I + 1));
      P := J + 1;
    until False;
    SB.Append(Copy(S, P, MaxInt));
    Result := SB.ToString;
  finally
    Map.Free;
    SB.Free;
  end;
end;

function ApplyColorStyle(const S: string; const AColors: THtmlColors; const ALight, ADark: string): string;
begin
  case AColors.Style of
    csLight: Result := ReplaceVariables(S, ReplaceColorMarkers(ALight, AColors));
    csDark: Result := ReplaceVariables(S, ReplaceColorMarkers(ADark, AColors));
  else
    Result := S;
  end;
end;

function BuildStyleSheet(const AColors: THtmlColors; const ALight, ADark, ACss, AScrollbar, AVersion: string;
  AFullSidebar, AAddScrollbar: Boolean): string;
var
  SB: TStringBuilder;
  Css: string;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('/* The standard CSS for doxygen ').Append(AVersion).Append('*/'#10#10);
    case AColors.Style of
      csAutoLight, csToggle:
        SB.Append('html {'#10).Append(ReplaceColorMarkers(ALight, AColors)).Append('}'#10#10);
      csAutoDark:
        SB.Append('html {'#10).Append(ReplaceColorMarkers(ADark, AColors)).Append('}'#10#10);
    end;
    case AColors.Style of
      csAutoLight:
        SB.Append('@media (prefers-color-scheme: dark) {'#10'  html:not(.dark-mode) {'#10'    color-scheme: dark;'#10#10)
          .Append(ReplaceColorMarkers(ADark, AColors)).Append('}}'#10);
      csAutoDark:
        SB.Append('@media (prefers-color-scheme: light) {'#10'  html:not(.light-mode) {'#10'    color-scheme: light;'#10#10)
          .Append(ReplaceColorMarkers(ALight, AColors)).Append('}}'#10);
      csToggle:
        SB.Append('html.dark-mode {'#10).Append(ReplaceColorMarkers(ADark, AColors)).Append('}'#10#10);
    end;
    Css := ACss;
    if AFullSidebar then
      Css := Css + #10'#titlearea {'#10'  border-bottom: none;'#10'  background-color: var(--nav-background-color);'#10 +
        '  border-right: 1px solid var(--nav-border-color);'#10'}'#10;
    SB.Append(ApplyColorStyle(Css, AColors, ALight, ADark));
    if AAddScrollbar then
      SB.Append(ApplyColorStyle(AScrollbar, AColors, ALight, ADark));
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function HtmlEscape(const S: string): string;
begin
  Result := S.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;');
end;

function JsString(const S: string): string;
begin
  Result := S.Replace('\', '\\').Replace('"', '\"').Replace('''', '\''').Replace(#13, '').Replace(#10, '\n');
end;

end.
