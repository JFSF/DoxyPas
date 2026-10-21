unit DoxyPas.Config.Writer;

interface

uses
  System.SysUtils,
  DoxyPas.Config;

/// <summary>Writes a Doxyfile template (Doxygen's Config::writeTemplate).</summary>
/// <param name="AShort">No explanatory comments (doxygen -s).</param>
/// <param name="AUpdate">Keep the text of bool/int values as read, e.g. when updating a file (doxygen -u).</param>
function WriteDoxyfile(AConfig: TConfig; AShort, AUpdate: Boolean): string;

/// <summary>Writes only the options that differ from the defaults (doxygen -x).</summary>
function WriteDoxyfileDiff(AConfig: TConfig): string;

implementation

uses
  System.Classes,
  DoxyPas.Config.Options,
  DoxyPas.Config.Implemented,
  DoxyPas.Core.Version;

const
  MaxOptionLength = 23;

function ConvertToComment(const AText, AUserComment: string): string;
var
  T: string;
  I: Integer;
begin
  Result := '';
  if AText <> '' then
  begin
    T := Trim(AText);
    Result := '#';
    if (T <> '') and (T[1] <> #10) then
      Result := Result + ' ';
    for I := 1 to Length(T) do
      if T[I] = #10 then
      begin
        Result := Result + #10'#';
        if (I < Length(T)) and (T[I + 1] <> #10) then
          Result := Result + ' ';
      end
      else
        Result := Result + T[I];
    Result := Result + #10;
  end;
  if AUserComment <> '' then
  begin
    if Result <> '' then
      Result := Result + #10;
    Result := Result + AUserComment;
  end;
end;

function StringValue(const AText: string; AInitSpace, AWasQuoted: Boolean): string;
var
  NeedsEscaping: Boolean;
  C: Char;
  I: Integer;
begin
  Result := '';
  if AText = '' then
    Exit;
  if AInitSpace then
    Result := ' ';
  NeedsEscaping := AWasQuoted;
  for C in AText do
    if CharInSet(C, [' ', ',', #10, #9, '"', '#']) then
      NeedsEscaping := True;
  if not NeedsEscaping then
    Exit(Result + AText);
  Result := Result + '"';
  for I := 1 to Length(AText) do
  begin
    if (AText[I] = ' ') and (I = Length(AText)) then
      Break; // skip inserted space at the end
    if AText[I] = '"' then
      Result := Result + '\';
    Result := Result + AText[I];
  end;
  Result := Result + '"';
end;

function ListValue(AOption: TConfigOption): string;
var
  I: Integer;
  S: string;
  WasQuoted: Boolean;
begin
  Result := '';
  for I := 0 to AOption.List.Count - 1 do
  begin
    S := AOption.List[I];
    if I > 0 then
      Result := Result + ' \'#10 + StringOfChar(' ', MaxOptionLength + 1);
    WasQuoted := (Length(S) >= 2) and (S[1] = '"') and (S[Length(S)] = '"');
    if WasQuoted then
      S := Copy(S, 2, Length(S) - 2);
    Result := Result + StringValue(S, True, WasQuoted);
  end;
end;

function OptionValue(AOption: TConfigOption; AUpdate: Boolean): string;
begin
  case AOption.Info.Kind of
    okBool:
      if AUpdate and (AOption.Raw <> '') then
        Result := StringValue(AOption.Raw, True, False)
      else if AOption.BoolVal then
        Result := ' YES'
      else
        Result := ' NO';
    okInt:
      if AUpdate and (AOption.Raw <> '') then
        Result := StringValue(AOption.Raw, True, False)
      else
        Result := ' ' + IntToStr(AOption.IntVal);
    okString, okEnum: Result := StringValue(AOption.Str, True, False);
    okList: Result := ListValue(AOption);
  else
    Result := '';
  end;
end;

procedure WriteOption(ATarget: TStringBuilder; AOption: TConfigOption; AShort, AUpdate: Boolean);
var
  Name, Doc: string;
begin
  Name := AOption.Info.Name;
  Doc := AOption.Info.Doc;
  if not IsImplemented(Name) then
    Doc := Doc + #10#10'Not implemented in DoxyPas: the option is accepted and has no effect.';
  if not AShort then
    ATarget.Append(#10).Append(ConvertToComment(Doc, AOption.UserComment)).Append(#10)
  else if AOption.UserComment <> '' then
    ATarget.Append(ConvertToComment('', AOption.UserComment));
  ATarget.Append(Name).Append(StringOfChar(' ', MaxOptionLength - Length(Name))).Append('=')
    .Append(OptionValue(AOption, AUpdate)).Append(#10);
end;

function WriteDoxyfile(AConfig: TConfig; AShort, AUpdate: Boolean): string;
var
  SB: TStringBuilder;
  Opt: TConfigOption;
  Group: Integer;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('# Doxyfile ').Append(DoxyPasVersion).Append(#10#10);
    if not AShort then
      SB.Append(ConvertToComment(ConfigHeader, ''));
    Group := -1;
    for Opt in AConfig.Options do
    begin
      if Opt.Info.Kind = okObsolete then
        Continue;
      if Opt.Info.Group <> Group then
      begin
        Group := Opt.Info.Group;
        if not AShort then
          SB.Append(#10);
        SB.Append('#---------------------------------------------------------------------------'#10);
        SB.Append('# ').Append(ConfigGroups[Group].Docs).Append(#10);
        SB.Append('#---------------------------------------------------------------------------'#10);
      end;
      WriteOption(SB, Opt, AShort, AUpdate);
    end;
    if AConfig.UserComment <> '' then
      SB.Append(#10).Append(AConfig.TakeUserComment);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function WriteDoxyfileDiff(AConfig: TConfig): string;
var
  SB: TStringBuilder;
  Opt: TConfigOption;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('# Difference with default Doxyfile ').Append(DoxyPasVersion).Append(#10);
    for Opt in AConfig.Options do
      if (Opt.Info.Kind <> okObsolete) and not Opt.IsDefault then
      begin
        Opt.UserComment := '';
        WriteOption(SB, Opt, True, True);
      end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

end.
