unit DoxyPas.Config;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DoxyPas.Config.Options;

type
  EConfigError = class(Exception);

  /// <summary>Current value of one option; the static description lives in <c>ConfigOptions</c>.</summary>
  TConfigOption = class
  public
    Index: Integer;         // into ConfigOptions
    Raw: string;            // bool/int: text as read from the file (empty if not set)
    Str: string;            // string/enum value
    List: TList<string>;    // list value; items that were quoted keep their quotes
    BoolVal: Boolean;
    IntVal: Integer;
    UserComment: string;    // "##" comment lines placed in front of the tag
    Present: Boolean;       // obsolete option was found in the file
    constructor Create(AIndex: Integer);
    destructor Destroy; override;
    function Info: TOptionInfo;
    function IsDefault: Boolean;
  end;

  /// <summary>The configuration (Doxyfile) values. Equivalent to Doxygen's ConfigImpl.</summary>
  TConfig = class
  strict private
    FOptions: TObjectList<TConfigOption>;
    FByName: TDictionary<string, TConfigOption>;
    FUserComment: string;
    function Require(const AName: string; AKind: TOptionKind): TConfigOption;
  public
    constructor Create;
    destructor Destroy; override;
    property Options: TObjectList<TConfigOption> read FOptions;
    /// <summary>Returns nil if the option is unknown.</summary>
    function Find(const AName: string): TConfigOption;
    function GetBool(const AName: string): Boolean;
    function GetInt(const AName: string): Integer;
    /// <summary>Value of a string or enum option.</summary>
    function GetString(const AName: string): string;
    function GetList(const AName: string): TArray<string>;
    procedure AppendUserComment(const AText: string);
    function TakeUserComment: string;
    property UserComment: string read FUserComment;
    /// <summary>Expands $(ENV) references, applies defaults to empty values and converts bool/int/enum
    /// text to values (Doxygen's Config::postProcess). Call after reading, not before an update.</summary>
    procedure PostProcess;
  end;

function SubstEnvVars(const AText: string): string;
function SplitValues(const AValues: string): TArray<string>;

implementation

uses
  System.RegularExpressions,
  DoxyPas.Core.Log;

function SplitValues(const AValues: string): TArray<string>;
begin
  if AValues = '' then
    Result := nil
  else
    Result := AValues.Split(['|']);
end;

type
  TEnvExpander = class
    class function Expand(const AMatch: TMatch): string;
  end;

class function TEnvExpander.Expand(const AMatch: TMatch): string;
begin
  Result := GetEnvironmentVariable(AMatch.Groups[1].Value);
end;

function SubstEnvVars(const AText: string): string;
var
  Depth: Integer;
begin
  Result := AText;
  if Result = '' then
    Exit;
  Depth := 0;
  // e.g. $(HOME) and $(PROGRAMFILES(X86)); repeat so values may reference other variables
  while (Depth < 10) and TRegEx.IsMatch(Result, '\$\([A-Za-z][\w.\-]*(\([A-Za-z][\w.\-]*\))?\)') do
  begin
    Result := TRegEx.Replace(Result, '\$\(([A-Za-z][\w.\-]*)\)', TEnvExpander.Expand);
    Result := TRegEx.Replace(Result, '\$\(([A-Za-z][\w.\-]*\([A-Za-z][\w.\-]*\))\)', TEnvExpander.Expand);
    Inc(Depth);
  end;
  Result := Trim(Result);
end;

function StrToBool(const AText: string; out AValue: Boolean): Boolean;
var
  S: string;
begin
  S := LowerCase(Trim(AText));
  Result := True;
  if (S = 'yes') or (S = 'true') or (S = '1') or (S = 'all') then
    AValue := True
  else if (S = 'no') or (S = 'false') or (S = '0') or (S = 'none') then
    AValue := False
  else
    Result := False;
end;

{ TConfigOption }

constructor TConfigOption.Create(AIndex: Integer);
var
  Item: string;
begin
  inherited Create;
  Index := AIndex;
  List := TList<string>.Create;
  with ConfigOptions[AIndex] do
    case Kind of
      okBool: BoolVal := Default = '1';
      okInt: IntVal := StrToIntDef(Default, 0);
      okString, okEnum: Str := Default;
      okList: for Item in SplitValues(Values) do
        List.Add(Item);
    end;
end;

destructor TConfigOption.Destroy;
begin
  List.Free;
  inherited;
end;

function TConfigOption.Info: TOptionInfo;
begin
  Result := ConfigOptions[Index];
end;

function TConfigOption.IsDefault: Boolean;
var
  Def: TArray<string>;
  I, J: Integer;
  Cur: TList<string>;
begin
  with ConfigOptions[Index] do
    case Kind of
      okBool: Result := BoolVal = (Default = '1');
      okInt: Result := IntVal = StrToIntDef(Default, 0);
      okString, okEnum: Result := Trim(Str) = Trim(Default);
      okList:
        begin
          // like Doxygen: compare the non-blank items only
          Def := SplitValues(Values);
          Cur := TList<string>.Create;
          try
            for I := 0 to List.Count - 1 do
              if Trim(List[I]) <> '' then
                Cur.Add(Trim(List[I]));
            Result := Cur.Count = Length(Def);
            if Result then
              for J := 0 to Cur.Count - 1 do
                if Cur[J] <> Trim(Def[J]) then
                  Exit(False);
          finally
            Cur.Free;
          end;
        end;
    else
      Result := True;
    end;
end;

{ TConfig }

constructor TConfig.Create;
var
  I: Integer;
  Opt: TConfigOption;
begin
  inherited Create;
  FOptions := TObjectList<TConfigOption>.Create(True);
  FByName := TDictionary<string, TConfigOption>.Create;
  for I := 0 to ConfigOptionCount - 1 do
  begin
    Opt := TConfigOption.Create(I);
    FOptions.Add(Opt);
    FByName.Add(ConfigOptions[I].Name, Opt);
  end;
end;

destructor TConfig.Destroy;
begin
  FByName.Free;
  FOptions.Free;
  inherited;
end;

function TConfig.Find(const AName: string): TConfigOption;
begin
  if not FByName.TryGetValue(AName, Result) then
    Result := nil;
end;

function TConfig.Require(const AName: string; AKind: TOptionKind): TConfigOption;
begin
  Result := Find(AName);
  if Result = nil then
    raise EConfigError.CreateFmt('Internal error: requested unknown option %s', [AName]);
  if (Result.Info.Kind <> AKind) and not ((AKind = okString) and (Result.Info.Kind = okEnum)) then
    raise EConfigError.CreateFmt('Internal error: option %s has a different type', [AName]);
end;

function TConfig.GetBool(const AName: string): Boolean;
begin
  Result := Require(AName, okBool).BoolVal;
end;

function TConfig.GetInt(const AName: string): Integer;
begin
  Result := Require(AName, okInt).IntVal;
end;

function TConfig.GetString(const AName: string): string;
begin
  Result := Require(AName, okString).Str;
end;

function TConfig.GetList(const AName: string): TArray<string>;
begin
  Result := Require(AName, okList).List.ToArray;
end;

procedure TConfig.AppendUserComment(const AText: string);
begin
  FUserComment := FUserComment + AText;
end;

function TConfig.TakeUserComment: string;
begin
  Result := FUserComment;
  FUserComment := '';
end;

{ Expands $(ENV) in list items and strips their quotes (Doxygen's substEnvVarsInStrList). An unquoted item
  may expand into several items; quoted items are never split. }
procedure SubstEnvInList(AList: TList<string>);
var
  Res: TList<string>;
  Item, S, Word: string;
  WasQuoted, InQuote: Boolean;
  C: Char;
begin
  Res := TList<string>.Create;
  try
    for Item in AList do
    begin
      S := Item;
      WasQuoted := (Length(S) >= 2) and (S[1] = '"') and (S[Length(S)] = '"');
      if WasQuoted then
        S := Copy(S, 2, Length(S) - 2)
      else
        WasQuoted := (Pos(' ', S) > 0) or (Pos(#9, S) > 0) or (Pos('"', S) > 0);
      S := SubstEnvVars(S);
      if WasQuoted then
        Res.Add(S)
      else
      begin
        Word := '';
        InQuote := False;
        for C in S + ' ' do
          if InQuote then
          begin
            if C = '"' then
              InQuote := False
            else
              Word := Word + C;
          end
          else if C = '"' then
            InQuote := True
          else if (C = ' ') or (C = #9) then
          begin
            if Word <> '' then
              Res.Add(Word);
            Word := '';
          end
          else
            Word := Word + C;
      end;
    end;
    AList.Clear;
    AList.AddRange(Res);
  finally
    Res.Free;
  end;
end;

procedure TConfig.PostProcess;
var
  Opt: TConfigOption;
  J, N: Integer;
  B: Boolean;
  Found: Boolean;
  Range: TArray<string>;
begin
  for Opt in FOptions do
    with Opt.Info do
    begin
      // 1. environment variables
      case Kind of
        okString, okEnum: Opt.Str := SubstEnvVars(Opt.Str);
        okBool, okInt: Opt.Raw := SubstEnvVars(Opt.Raw);
        okList: SubstEnvInList(Opt.List);
      end;
      // 2. empty value -> default
      case Kind of
        okString: if (Opt.Str = '') and (Default <> '') then Opt.Str := Default;
        okList:
          if (Opt.List.Count = 0) and (Values <> '') then
            Opt.List.AddRange(SplitValues(Values));
      end;
      // 3. text -> value
      case Kind of
        okBool:
          if Trim(Opt.Raw) <> '' then
          begin
            if StrToBool(Opt.Raw, B) then
              Opt.BoolVal := B
            else
              Warn('', 0, System.SysUtils.Format('argument ''%s'' for option %s is not a valid boolean value. Using the default: %s!',
                [Opt.Raw, Name, BoolToStr(Opt.BoolVal, True).ToUpper]));
          end;
        okInt:
          if Opt.Raw <> '' then
          begin
            if TryStrToInt(Trim(Opt.Raw), N) and (N >= MinVal) and (N <= MaxVal) then
              Opt.IntVal := N
            else
              Warn('', 0, System.SysUtils.Format('argument ''%s'' for option %s is not a valid number in the range [%d..%d]! ' +
                'Using the default: %d!', [Opt.Raw, Name, MinVal, MaxVal, Opt.IntVal]));
          end;
        okEnum:
          begin
            if Opt.Str = '' then
              Opt.Str := Default
            else
            begin
              Found := False;
              Range := SplitValues(Values);
              for J := 0 to High(Range) do
                if SameText(Range[J], Trim(Opt.Str)) then
                begin
                  Opt.Str := Range[J];
                  Found := True;
                  Break;
                end;
              if not Found then
              begin
                Warn('', 0, System.SysUtils.Format('argument ''%s'' for option %s is not a valid enum value. Using the default: %s!',
                  [Opt.Str, Name, Default]));
                Opt.Str := Default;
              end;
            end;
          end;
      end;
    end;
end;

end.
