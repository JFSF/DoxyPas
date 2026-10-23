# Packs the files of a release into build\release\DoxyPas-<version>.zip: run build.bat first.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
$ver = [regex]::Match((Get-Content "$root\src\Core\DoxyPas.Core.Version.pas" -Raw), "DoxyPasVersion = '([^']+)'").Groups[1].Value
$stage = "$root\build\release\DoxyPas-$ver"
Remove-Item "$root\build\release" -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory "$stage\Win32", "$stage\Win64", "$stage\docs" -Force | Out-Null
foreach ($p in 'Win32', 'Win64') {
  foreach ($f in 'DoxyPas.exe', 'DoxyPasGui.exe') {
    if (-not (Test-Path "$root\build\$p\$f")) { throw "missing build${p}${f} - run build.bat" }
    Copy-Item "$root\build\$p\$f" "$stage\$p\"
  }
}
Copy-Item "$root\LICENSE", "$root\THIRD_PARTY_NOTICES.md", "$root\README.md", "$root\README.pt.md" $stage
Copy-Item "$root\docs\en", "$root\docs\pt", "$root\docs\images", "$root\docs\example" "$stage\docs" -Recurse
Remove-Item "$stage\docs\example\out" -Recurse -Force -ErrorAction SilentlyContinue
Compress-Archive "$stage\*" "$root\build\release\DoxyPas-$ver.zip"
Get-ChildItem "$root\build\release\*.zip" | Select-Object Name, @{n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } }
