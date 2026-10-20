unit Defines;

interface

{$IFDEF MSWINDOWS}
procedure OnlyWindows;
{$ENDIF}
{$IFDEF LINUX}
procedure OnlyLinux;
{$ENDIF}
{$IF CompilerVersion >= 30}
procedure Modern;
{$ELSE}
procedure Legacy;
{$IFEND}
{$IFDEF MYDEF}
procedure UserDefined;
{$ENDIF}
{$I defines.inc}

implementation

end.
