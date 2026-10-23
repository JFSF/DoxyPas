# DoxyPas — Preparação para o GetIt / GetIt readiness

Análise feita em 2026-10-23 contra as diretrizes públicas do GetIt
(<https://getitnow.embarcadero.com/submit/> e <https://getitnow.embarcadero.com/overview/>). A submissão é feita por
**formulário** (Google Forms) e a Embarcadero decide caso a caso: as regras "não são absolutas", mas o nível de qualidade é
mantido alto. Isto **não é** uma garantia de aceitação.

## 1. As diretrizes e onde o DoxyPas está

| Diretriz do GetIt | Estado | Observação |
|---|---|---|
| Atualizar em 30 dias após cada versão do RAD Studio | ✅ possível | Compila com o Delphi 13 (37.0) sem erros. É preciso aceitar este compromisso e ter forma de o cumprir (ver §3, CI). |
| "Melhor experiência" para quem usa o RAD Studio | ⚠️ **lacuna principal** | O DoxyPas é uma ferramenta autónoma (linha de comandos + GUI VCL). Não há integração no IDE (menu *Tools*, ação sobre o projeto aberto). Ver §2. |
| Código limpo e moderno (preferência) | ⚠️ | 111 testes DUnitX passam (Win32 e Win64). Mas a compilação dá 21 avisos (`W1000` símbolo obsoleto ×12, `W1002` específico de plataforma ×3, `W1019` ×3, `W1036` ×3) e 38 dicas. |
| Multi-dispositivo / FMX (não obrigatório) | ✅ n/a | A CLI compila para Win32, Win64 e Linux64; a GUI é VCL só para Windows. |
| Não substituir funcionalidade core Enterprise | ✅ | O RAD Studio não traz gerador de documentação (o Help Insight lê XMLDoc, não gera um manual). Convém dizê-lo no formulário. |
| Evitar queixas de propriedade intelectual | ⚠️ ver §2 | Licença GPL-2.0, derivada do Doxygen (GPL-2.0, atribuída em `THIRD_PARTY_NOTICES.md`); os estilos VCL `.vsf` do repositório são da Embarcadero. |

## 2. Riscos e decisões que são suas

1. **Tipo de pacote.** O GetIt lista "bibliotecas, componentes, extensões do IDE e SDKs". Uma ferramenta que só tem `.exe`
   tem menos hipóteses do que uma que se integra no IDE. Opções, por esforço:
   * (a) submeter como está, a explicar o valor (documentação de Delphi e FPC, XMLDoc, `.dproj`, `.dfm`);
   * (b) acrescentar uma entrada no menu *Tools* (via *Tools > Configure Tools* instalada pelo pacote, ou um pequeno
     pacote OTA que corre o `DoxyPas.exe` sobre o `.dproj` do projeto ativo e abre o resultado) — recomendado antes de submeter;
   * (c) ambas, com a (b) como segunda versão. **Pergunta para si:** (a) ou (b) primeiro?
2. **Licença GPL-2.0.** É obrigatória enquanto o código for derivado do Doxygen. Perguntar à Embarcadero, no formulário,
   se aceitam uma ferramenta GPL-2.0. Se vier a existir um pacote OTA que *linke* com o RTL/VCL, a questão da
   exceção de bibliotecas de sistema da GPL tem de ser confirmada com eles. O DelphiAST (MPL-2.0) é compatível (MPL-2.0 §3.3).
3. **Estilos VCL.** Eram cópias idênticas dos de `...\Studio\37.0\Redist\styles\vcl`; redistribuí-los num repositório
   público é uma zona cinzenta da licença do RAD Studio. **Resolvido:** já não estão no repositório (são copiados na compilação). Os
   `.exe` publicados contêm-nos embebidos, como qualquer aplicação VCL com estilos; confirme com a Embarcadero no formulário.
4. **Assinatura de código.** Os `.exe` não estão assinados: o SmartScreen e alguns antivírus desconfiam de executáveis novos
   e sem assinatura. Para o GetIt é preferível um certificado de assinatura de código (o seu ou da Embarcadero, se eles
   reassinarem o pacote).
5. **Dependências externas.** Graphviz (`dot`, para os grafos), uma distribuição LaTeX (para o PDF) e o *HTML Help Compiler*
   (para o CHM) são opcionais e **não** são distribuídos. A descrição do pacote deve dizê-lo.
6. **Segurança.** O DoxyPas não usa rede. Executa programas indicados no Doxyfile (`INPUT_FILTER`, `FILTER_PATTERNS`,
   `FILE_VERSION_FILTER`, `HHC_LOCATION`, `DOT_PATH`): um Doxyfile é por isso código de confiança, como um makefile. Convém
   avisá-lo na documentação (uma linha).

## 3. Lista de trabalho antes de submeter

| # | Tarefa | Quem | Esforço |
|---|---|---|---|
| 1 | Decidir (a)/(b) do §2.1 e implementar a integração no IDE se for (b). | Você | médio |
| 2 | ✅ **Feito.** Os `.vsf` já não estão no repositório: `src/Gui/prebuild.bat` copia-os de `%BDS%\Redist\styles\vcl` ao compilar. | — | — |
| 3 | ✅ **Feito.** `DoxyPas.groupproj`, `src/Gui/DoxyPasGui.dproj` e `tests/unit/DoxyPasTests.dproj`; o `src/DoxyPas.dproj` ganhou caminhos de pesquisa e de saída. Verificado com `msbuild` (Release, Win32 e Win64) e com `build.bat`. Por verificar: abrir o `.groupproj` no IDE. | — | — |
| 4 | ✅ **Feito.** Ícone novo (`resources/icon/doxypas.ico`) e informação de versão `0.1.0.0` nos dois `.exe`, via `src/DoxyPas.rc` e `src/Gui/Styles.rc` (compilados pelo `brcc32`). A empresa é "DoxyPas contributors": **troque pelo seu nome ou da sua empresa** nos `.rc` e `.dproj` se quiser. O número está em três sítios (`Core.Version.pas` e os dois `.rc`). | — | — |
| 5 | ✅ **Feito.** Usa `%BDS%` se já estiver definido (linha de comandos do RAD Studio), senão `DELPHI_VER` (omissão `37.0`). | — | — |
| 6 | ✅ **Feito:** 0 avisos (restam 38 dicas, de variáveis por usar). O `SimpleParser.Lexer.pas` do DelphiAST foi tocado (`TCharacter` → `TCharHelper`) e está registado em `third_party/DelphiAST/PATCHES.md`. | — | — |
| 7 | Integração contínua (GitHub Actions num *runner* com Delphi, ou pelo menos um script local) que compile e corra os testes, para cumprir os "30 dias" após uma versão nova. | Você | médio |
| 8 | Publicar uma *release* no GitHub com o zip de `tools\release\make_zip.ps1` (já criado) e uma etiqueta `v0.1.0`; o GetIt pede um ficheiro/URL estável para descarregar. | Você | pequeno |
| 9 | Assinar os executáveis (§2.4). | Você | depende |
| 10 | Testar a instalação numa máquina limpa (sem Delphi, sem Graphviz) e com o Delphi 13 em Windows 11. | Você | pequeno |
| 11 | Subir a versão para **1.0.0** quando as tarefas 1–6 estiverem feitas (um `0.1.0` dá má impressão num catálogo). | Você | — |
| 12 | Preencher o formulário (rascunho em §4). | Você | pequeno |

**Decisão tomada (2026-10-23):** submeter como ferramenta autónoma (opção (a) do §2.1); a integração no IDE fica para uma versão posterior.

Já feito nesta preparação: documentação em inglês e português com imagens (`docs/`), `README.pt.md`,
`THIRD_PARTY_NOTICES.md`, o script do pacote `tools/release/make_zip.ps1` (gera `build/release/DoxyPas-0.1.0.zip`, 8,7 MB: executáveis
Win32/Win64 da CLI e da GUI, licenças e documentação) e esta análise. Verificado: `build.bat` compila Win32, Win64, Linux64 e a GUI
sem erros; `build.bat test` — 111 testes, 0 falhas.

## 4. Rascunho do formulário (English)

**Name:** DoxyPas

**One-line description:** Doxygen-style documentation generator for Object Pascal (Delphi, Free Pascal, Lazarus), written
entirely in Delphi.

**Description:** DoxyPas reads Delphi, Free Pascal and Lazarus sources, Delphi/Lazarus projects (`.dproj`, `.groupproj`,
`.lpi`) and forms (`.dfm`, `.fmx`), and writes API documentation as HTML (search, navigation tree, source browser, class,
collaboration, uses and call graphs through Graphviz), LaTeX/PDF, XML, SQLite, tag files and CHM files. It understands Pascal
(units, classes, records, interfaces, helpers, generics, properties, visibilities, conditional compilation) and reads both
Doxygen-style comments and the XML documentation of Delphi (`/// <summary>`). It is based on Doxygen (same Doxyfile with 221
options); page texts are available in 12 languages. It includes a command-line tool for Win32, Win64 and Linux64 and a VCL
GUI to edit the options and run it.

**Category:** Tool / documentation.

**Supported RAD Studio versions:** Delphi 13 (tested). Win32, Win64 (CLI and GUI), Linux64 (CLI).

**License:** GPL-2.0 (derived from Doxygen); DelphiAST under MPL-2.0 is included. See `LICENSE` and `THIRD_PARTY_NOTICES.md`.

**Third-party requirements:** none to run; optional: Graphviz (graphs), a LaTeX distribution (PDF), HTML Help Compiler (CHM).

**Does it replace core Enterprise functionality?** No. RAD Studio's Help Insight reads XML comments but does not generate API
manuals.

**Repository / download:** <https://github.com/JFSF/DoxyPas> (public). Release zip: *(URL of the GitHub release, after step 8)*.

**Maintenance:** *(your commitment to update within 30 days of each RAD Studio release.)*

**Questions for Embarcadero:** is a GPL-2.0 tool acceptable in GetIt; would a package that adds a *Tools* menu entry be preferred.

**Contact:** *(your e-mail)*
