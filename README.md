# DoxyPas

Documentation generator for **Object Pascal**: Delphi, Free Pascal and Lazarus sources. It is written entirely in Delphi and
is based on [Doxygen](https://github.com/doxygen/doxygen) (the Doxyfile, the documentation comments and the look of the
output are the ones of Doxygen), but it reads Pascal: units, classes, records, interfaces, object types, helpers, generics,
routines, properties, constants, enumerations and the forms (`.dfm`, `.fmx`). Licensed under GPL-2.0 (see `LICENSE`).
Planning and decision log: [`docs/DOXYPAS.md`](docs/DOXYPAS.md).

## What it reads

* Source files `*.pas *.dpr *.dpk *.pp *.p *.lpr` (option `FILE_PATTERNS`), and the forms `*.dfm *.fmx`
  (text and binary) with `PASCAL_PARSE_DFM`.
* Delphi projects (`.dproj`, `.groupproj`) and Lazarus projects (`.lpi`, `.lpk`) with `DELPHI_PROJECT`: the files, the
  conditional defines and the search paths come from the project.
* Documentation comments of Doxygen (`///`, `{**` ... `}`, `(**` ... `*)`, `//!<`, `{!<` ... `}`, `\brief`, `\param`, ...) and the XMLDoc of
  Delphi (`/// <summary>`, ...) with `PASCAL_XMLDOC`.
* Conditional compilation: `PASCAL_DIALECT` and `PASCAL_PLATFORM` choose the symbols that are defined; `PREDEFINED` adds
  more; `INCLUDE_PATH` is where `{$I file}` is searched.

## What it writes

HTML (with search, tree view, source browser, call and dependency graphs through `dot`), LaTeX/PDF, XML (the one of Doxygen),
SQLite, tag files and the files for a CHM. The text of the pages is in English, Portuguese, Brazilian, Spanish, French,
German, Italian, Dutch, Polish, Russian, Chinese or Japanese (`OUTPUT_LANGUAGE`). The sections use the terms of Pascal:
units, types, constants, routines, methods, class methods, fields, properties, and the visibilities public, published,
protected, strict protected, private and strict private. `LAYOUT_FILE` (see `doxypas -l`) changes the pages.

## Use

    doxypas -g Doxyfile        # a Doxyfile with the options of Pascal and their documentation
    doxypas Doxyfile           # generates the documentation
    DoxyPasGui.exe Doxyfile    # Windows: edit the options, run, open the result (add /run to run it at once)

The folders `__history`, `__recovery` (Delphi) and `backup` (Lazarus) are left out by default.

## Build

Requires Delphi 13 (RAD Studio 37.0). From a command prompt:

    build.bat            # builds src\DoxyPas.dpr for Win32, Win64, Linux64 and the GUI for Win32, Win64
    build.bat test       # builds and runs the DUnitX tests (Win32, Win64)
    build.bat gen        # regenerates the options and the resources (see below)

Output goes to `build\<platform>\`.

## Options and resources

`resources\config\config.xml` is the option table (Doxygen's, without the options of C/C++ and other languages, and with the
defaults of Pascal); `build.bat gen` regenerates `src\Config\DoxyPas.Config.Options.pas` from it and from
`config_pascal.xml` (the options of DoxyPas: `PASCAL_*`, `DELPHI_PROJECT`). The options that were removed are obsolete:
a Doxyfile that has them gets a warning and `doxypas -u` takes them out.

## Documentation

* User guide: [English](docs/en/USER_GUIDE.md) · [Português](docs/pt/GUIA_DO_UTILIZADOR.md)
* Reference of the 221 options: [English](docs/en/OPTIONS.md) · [Português](docs/pt/OPCOES.md)
* Example project used for the images: [`docs/example`](docs/example). Português: [README.pt.md](README.pt.md).
