# DelphiAST spike (D-006 / D-035)

Throw-away harness used to evaluate DelphiAST (MPL-2.0, commit 3840253, 2026-01-25) as the Pascal parser.
Not part of the build. To reproduce:

    git clone https://github.com/RomanYankovsky/DelphiAST.git   (next to this folder, i.e. ..\DelphiAST)
    dcc64 -U..\DelphiAST\Source;..\DelphiAST\Source\SimpleParser -I..\DelphiAST\Source\SimpleParser Spike.dpr
    Spike <dir> [iface|xml] [v] [fpc]     # parses every *.pas (and *.pp with "fpc") under <dir>

`modern.pas` exercises Delphi 10.3+ syntax (inline vars, attributes, generics, helpers, anonymous methods, `is not`).
