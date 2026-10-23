# Third-party notices / Avisos de terceiros

DoxyPas is licensed under the GNU General Public License v2 (`LICENSE`). It contains or is derived from:

| Component | Where | Author / license | Notes |
|---|---|---|---|
| **Doxygen** | `resources/config`, `resources/html`, `resources/layout`, `resources/xml`, `resources/lang`, and the design of the generator | Dimitri van Heesch and contributors, GPL-2.0 | DoxyPas is a port/adaptation of Doxygen 1.19.0 (the Doxyfile options and their documentation, the HTML/CSS/JS templates, the XML schemas, the LaTeX layout and the translations of the page texts). Documents produced by Doxygen/DoxyPas are not covered by this license. |
| **DelphiAST** | `third_party/DelphiAST` | Roman Yankovsky and contributors, MPL-2.0 | Vendored at upstream commit `3840253`, with the local patches listed in `third_party/DelphiAST/PATCHES.md`. Files keep their license headers. MPL-2.0 may be combined with GPL-2.0 (MPL-2.0 section 3.3). |
| **VCL styles** `WindowsModern`, `WindowsModernDark` | embedded in `DoxyPasGui.exe` at build time | Embarcadero Technologies | Not in this repository: `build.bat` copies them from `Redist\stylescl` of the RAD Studio installation of whoever builds. |
| **DUnitX** | used only to build the tests (`tests/unit`) | Vincent Parrett and contributors, Apache-2.0 | Taken from the RAD Studio installation; not distributed. |

External programs that DoxyPas can call, and that are **not** distributed with it: Graphviz `dot` (EPL), a LaTeX distribution
(MiKTeX / TeX Live), Microsoft HTML Help Compiler.

Os componentes acima mantêm as suas licenças. / The components above keep their own licenses.
