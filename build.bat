@echo off
setlocal
rem Command-line build with dcc (no .dproj yet). Usage: build.bat [test]
call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" || exit /b 1
set ROOT=%~dp0
set DUNITX=%BDS%\source\DUnitX
set DAST=%ROOT%third_party\DelphiAST\Source;%ROOT%third_party\DelphiAST\Source\SimpleParser
set OPTS=-Q -B -W+ -NSSystem;System.Win;Winapi -U"%DAST%" -I"%ROOT%third_party\DelphiAST\Source\SimpleParser"
set SDK=%USERPROFILE%\Documents\Embarcadero\Studio\SDKs\ubuntu24.04.sdk

if /i "%1"=="test" goto :tests
if /i "%1"=="gen" goto :gen

pushd "%ROOT%src"
for %%P in (32 64) do (
  if not exist "%ROOT%build\Win%%P\dcu" mkdir "%ROOT%build\Win%%P\dcu"
  "%BDS%\bin\dcc%%P.exe" %OPTS% -E"%ROOT%build\Win%%P" -N0"%ROOT%build\Win%%P\dcu" DoxyPas.dpr || exit /b 1
)
rem Linux64 needs the SDK registered in the IDE (ubuntu24.04.sdk).
if not exist "%ROOT%build\Linux64\dcu" mkdir "%ROOT%build\Linux64\dcu"
"%BDS%\bin\dcclinux64.exe" -Q -B --syslibroot:"%SDK%" -U"%DAST%" -I"%ROOT%third_party\DelphiAST\Source\SimpleParser" -NSSystem;System.Win --libpath:"%SDK%\usr\lib\gcc\x86_64-linux-gnu\13;%SDK%\usr\lib\x86_64-linux-gnu;%BDS%\lib\linux64\release" -E"%ROOT%build\Linux64" -N0"%ROOT%build\Linux64\dcu" DoxyPas.dpr
popd
exit /b %ERRORLEVEL%

:tests
pushd "%ROOT%tests\unit"
for %%P in (32 64) do (
  if not exist "%ROOT%build\tests%%P\dcu" mkdir "%ROOT%build\tests%%P\dcu"
  "%BDS%\bin\dcc%%P.exe" %OPTS% -U"%DUNITX%" -I"%DUNITX%;%ROOT%third_party\DelphiAST\Source\SimpleParser" -E"%ROOT%build\tests%%P" -N0"%ROOT%build\tests%%P\dcu" DoxyPasTests.dpr || exit /b 1
  "%ROOT%build\tests%%P\DoxyPasTests.exe" || exit /b 1
)
popd
exit /b 0

:gen
rem Regenerates src\Config\DoxyPas.Config.Options.pas from resources\config\*.xml
if not exist "%ROOT%build\tools\dcu" mkdir "%ROOT%build\tools\dcu"
pushd "%ROOT%tools\GenConfig"
"%BDS%\bin\dcc32.exe" %OPTS% -E"%ROOT%build\tools" -N0"%ROOT%build\tools\dcu" GenConfig.dpr || exit /b 1
popd
"%ROOT%build\tools\GenConfig.exe" "%ROOT%src\Config\DoxyPas.Config.Options.pas" "%ROOT%resources\config\config.xml" "%ROOT%resources\config\config_pascal.xml"
rem Packs resources\xml\*.xsd into src\Resources\DoxyPas.Resources.Xml.pas
pushd "%ROOT%tools\PackResources"
"%BDS%\bin\dcc32.exe" %OPTS% -E"%ROOT%build\tools" -N0"%ROOT%build\tools\dcu" PackResources.dpr || exit /b 1
popd
"%ROOT%build\tools\PackResources.exe" "%ROOT%src\Resources\DoxyPas.Resources.Xml.pas" DoxyPas.Resources.Xml XmlResource "%ROOT%resources\xml\compound.xsd" "%ROOT%resources\xml\index.xsd" "%ROOT%resources\xml\xml.xsd"
