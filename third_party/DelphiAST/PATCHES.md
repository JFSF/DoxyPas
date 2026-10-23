# Local patches to DelphiAST

Upstream: https://github.com/RomanYankovsky/DelphiAST, commit 3840253 (2026-01-25), MPL-2.0 (see LICENSE).
Files under `Source\` keep their original license headers. Every change below must also be reported upstream
when it is not DoxyPas-specific.

| # | File | Change | Why |
|---|---|---|---|
| 1 | `Source/DelphiAST.pas` (`SetCurrentCompoundNodesEndPosition`) | Removed `Temp.FileName := Lexer.FileName;` | The end position is taken after the lexer looked ahead, so a `{$I}` include right after a declaration changed the *start* file of the node. DoxyPas maps node positions to source files and needs the file where the node begins. |
| 2 | `Source/SimpleParser/*.rsj` | Not vendored | Resource file not needed to build. |
| 3 | `Source/SimpleParser/SimpleParser.Lexer.pas` (`IsIdentifierChar`-like function near line 1910) | `TCharacter.IsX(AChar)` replaced by the `TCharHelper` form `AChar.IsX` | Delphi 13 marks the class form deprecated (W1000); same behavior. |
