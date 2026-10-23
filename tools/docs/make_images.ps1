# Regenerates the images of docs\images: runs DoxyPas on docs\example with a few option overrides and takes a screenshot
# of a page of each result with headless Chrome. Needs build\Win64\DoxyPas.exe, Graphviz (dot) and Chrome.
$ErrorActionPreference = 'Continue'
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
$ex = "$root\docs\example"
$img = "$root\docs\images"
$tmp = "$root\build\docs_tmp"
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $tmp, $img -Force | Out-Null

# name, overrides, page, width, height
$shots = @(
  @('main',        '',                                                  'index.html',                              1250, 420),
  @('class',       '',                                                  'class_shapes_1_1_t_shape.html',           1250, 1500),
  @('hierarchy',   '',                                                  'hierarchy.html',                          1250, 640),
  @('unit',        '',                                                  'unit_rectangles.html',                    1250, 1300),
  @('source',      '',                                                  'unit_circles_source.html',                1250, 900),
  @('dark',        'HTML_COLORSTYLE = DARK',                            'class_circles_1_1_t_circle.html',         1250, 900),
  @('hue',         'HTML_COLORSTYLE_HUE = 20',                          'class_circles_1_1_t_circle.html',         1250, 900),
  @('pt',          'OUTPUT_LANGUAGE = Portuguese',                      'class_circles_1_1_t_circle.html',         1250, 900),
  @('uml',         "UML_LOOK = YES`nDOT_UML_DETAILS = YES",             'class_rectangles_1_1_t_rectangle.html',   1250, 1500),
  @('nodot',       'HAVE_DOT = NO',                                     'class_rectangles_1_1_t_rectangle.html',   1250, 1100),
  @('notree',      "GENERATE_TREEVIEW = NO",                            'class_circles_1_1_t_circle.html',         1250, 900),
  @('sidebar',     "FULL_SIDEBAR = YES",                                'class_circles_1_1_t_circle.html',         1250, 900),
  @('private',     "EXTRACT_PRIVATE = YES",                             'class_circles_1_1_t_circle.html',         1250, 1000),
  @('callgraph',   "CALL_GRAPH = YES`nCALLER_GRAPH = YES",              '*_cgraph.svg',                            420, 200),
  @('callergraph', "CALL_GRAPH = YES`nCALLER_GRAPH = YES",              '*_icgraph.svg',                           420, 200),
  @('inline',      "INLINE_SOURCES = YES",                              'unit_circles.html',                       1250, 1300)
)
foreach ($s in $shots) {
  $name, $over, $page, $w, $h = $s
  $out = "$tmp\$name"
  $cfg = "$tmp\$name.cfg"
  (Get-Content "$ex\Doxyfile" -Raw) + "`nINPUT = $ex\src`nUSE_MDFILE_AS_MAINPAGE = $ex\README.md`nOUTPUT_DIRECTORY = $out`nSTRIP_FROM_PATH = $ex`n$over`n" | Set-Content $cfg -Encoding utf8
  & "$root\build\Win64\DoxyPas.exe" $cfg 2>&1 | Out-Null
  if (-not $?) { Write-Warning "run failed: $name" }
  $page = (Get-ChildItem "$out\html\$page" | Select-Object -First 1).Name
  & $chrome --headless=new --disable-gpu --hide-scrollbars "--window-size=$w,$h" "--screenshot=$img\$name.png" ("file:///" + "$out\html\$page".Replace('\', '/')) 2>&1 | Out-Null
  Write-Host "$name -> $img\$name.png"
}
