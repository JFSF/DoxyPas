# DoxyPas

Doxygen-style documentation generator for Object Pascal (Delphi and FreePascal sources), written entirely in Delphi.
Based on [Doxygen](https://github.com/doxygen/doxygen). Licensed under GPL-2.0 (see `LICENSE`).

Status: **M4 (semantic model and symbol resolution: `--model`)**. Planning and decision log: [`docs/DOXYPAS.md`](docs/DOXYPAS.md).

## Build

Requires Delphi 13 (RAD Studio 37.0). From a command prompt:

    build.bat            # builds src\DoxyPas.dpr for Win32, Win64, Linux64
    build.bat test       # builds and runs the DUnitX tests (Win32, Win64)

Output goes to `build\<platform>\`.

## Configuration tooling

`resources\config\config.xml` is Doxygen's option table; `build.bat gen` regenerates
`src\Config\DoxyPas.Config.Options.pas` from it (plus `config_pascal.xml` with the DoxyPas options).
