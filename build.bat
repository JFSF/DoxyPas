@echo off
setlocal
rem Command-line build with dcc (no .dproj yet). Usage: build.bat [test]
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" || exit /b 1
set ROOT=%~dp0
set DUNITX=%BDS%\source\DUnitX
set OPTS=-Q -B -W+ -NSSystem;System.Win;Winapi
set SDK=%USERPROFILE%\Documents\Embarcadero\Studio\SDKs\ubuntu24.04.sdk

if /i "%1"=="test" goto :tests

pushd "%ROOT%src"
for %%P in (32 64) do (
  if not exist "%ROOT%build\Win%%P\dcu" mkdir "%ROOT%build\Win%%P\dcu"
  "%BDS%\bin\dcc%%P.exe" %OPTS% -E"%ROOT%build\Win%%P" -N0"%ROOT%build\Win%%P\dcu" DoxyPas.dpr || exit /b 1
)
rem Linux64 needs the SDK registered in the IDE (ubuntu24.04.sdk).
if not exist "%ROOT%build\Linux64\dcu" mkdir "%ROOT%build\Linux64\dcu"
"%BDS%\bin\dcclinux64.exe" -Q -B --syslibroot:"%SDK%" --libpath:"%SDK%\usr\lib\gcc\x86_64-linux-gnu\13;%SDK%\usr\lib\x86_64-linux-gnu;%BDS%\lib\linux64\release" -E"%ROOT%build\Linux64" -N0"%ROOT%build\Linux64\dcu" DoxyPas.dpr
popd
exit /b %ERRORLEVEL%

:tests
pushd "%ROOT%tests\unit"
for %%P in (32 64) do (
  if not exist "%ROOT%build\tests%%P\dcu" mkdir "%ROOT%build\tests%%P\dcu"
  "%BDS%\bin\dcc%%P.exe" %OPTS% -U"%DUNITX%" -I"%DUNITX%" -E"%ROOT%build\tests%%P" -N0"%ROOT%build\tests%%P\dcu" DoxyPasTests.dpr || exit /b 1
  "%ROOT%build\tests%%P\DoxyPasTests.exe" || exit /b 1
)
popd
