@echo off
rem Builds Styles.RES (manifest + VCL styles). The .vsf files are Embarcadero's: copied from the RAD Studio installation (%BDS%),
rem not kept in the repository. Used by build.bat and by the PreBuildEvent of DoxyPasGui.dproj.
setlocal
set HERE=%~dp0
if not exist "%HERE%..\..\build\styles" mkdir "%HERE%..\..\build\styles"
copy /y "%BDS%\Redist\styles\vcl\WindowsModern.vsf" "%HERE%..\..\build\styles\" >nul || exit /b 1
copy /y "%BDS%\Redist\styles\vcl\WindowsModernDark.vsf" "%HERE%..\..\build\styles\" >nul || exit /b 1
pushd "%HERE%"
"%BDS%\bin\brcc32.exe" Styles.rc >nul || exit /b 1
popd
