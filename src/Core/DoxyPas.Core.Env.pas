unit DoxyPas.Core.Env;

{ The environment variables of the process, for the tools that DoxyPas runs (dot, latex, ...). }

interface

/// <summary>Sets an environment variable of the process (the tools that are run later see it).</summary>
procedure SetEnv(const AName, AValue: string);

/// <summary>Adds the directories in front of PATH, in the order given.</summary>
procedure PrependToPath(const ADirs: TArray<string>);

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  System.SysUtils,
  System.IOUtils;

{$IFDEF POSIX}
function LibcSetEnv(Name, Value: MarshaledAString; Overwrite: Integer): Integer; cdecl; external 'libc.so.6' name 'setenv';
{$ENDIF}

procedure SetEnv(const AName, AValue: string);
{$IFDEF POSIX}
var
  N, V: UTF8String;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  Winapi.Windows.SetEnvironmentVariable(PChar(AName), PChar(AValue));
{$ENDIF}
{$IFDEF POSIX}
  N := UTF8String(AName);
  V := UTF8String(AValue);
  LibcSetEnv(MarshaledAString(N), MarshaledAString(V), 1);
{$ENDIF}
end;

procedure PrependToPath(const ADirs: TArray<string>);
var
  Path, D: string;
begin
  Path := GetEnvironmentVariable('PATH');
  for D in ADirs do
    if Trim(D) <> '' then
      if Path = '' then
        Path := Trim(D)
      else
        Path := Trim(D) + TPath.PathSeparator + Path;
  SetEnv('PATH', Path);
end;

end.