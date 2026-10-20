# DoxyPas — Registo de Decisões, Análise e Plano

> Documento vivo. **Todas** as decisões de planeamento e desenvolvimento ficam aqui.
> Convenção: cada decisão tem um ID `D-NNN`, estado (`Aceite` · `Proposta` · `Em aberto` · `Revista`), data e justificação.
> Decisões nunca são apagadas — se mudarem, a antiga passa a `Revista` e aponta para a nova.

- **Criado em:** 2026-10-20
- **Fonte de referência:** Doxygen 1.19.0 (dev) em `G:\doxygen` (licença GPL v2)
- **Ambiente de desenvolvimento:** Delphi 13 Florence (RAD Studio 37.0), Windows 11, Graphviz (`dot`) e Java 21 instalados; FPC/Lazarus **não** instalados
- **Estado actual:** fase de **planeamento** — nenhum código escrito

---

## 1. Objectivo

Criar o **DoxyPas**: um gerador de documentação a partir de código-fonte e comentários, inspirado no Doxygen, **escrito inteiramente em Delphi**, cujo alvo principal é **Object Pascal** (dialectos Delphi e FreePascal).

Não é um *wrapper* nem um filtro sobre o Doxygen: é uma reimplementação/adaptação das suas funcionalidades, com um *front-end* de linguagem Pascal nativo.

---

## 2. Análise do Doxygen original

### 2.1 Dimensão

| Item | Valor |
|---|---|
| Ficheiros em `src/` | 337 |
| Linhas (`.cpp .h .l .y`, sem tradutores) | ≈ 199 000 |
| Scanners Flex (`.l`) | 19 (≈ 2 MB de fonte) |
| Tradutores de idioma (`translator_xx.h`) | ≈ 40 idiomas (≈ 60–100 KB cada) |
| Opções de configuração (`src/config.xml`) | 352 (174 bool · 91 string · 43 list · 27 int · 17 enum · 35 obsoletas) |
| Ficheiros em `testing/` | 151 |
| Referências a Pascal/Delphi no código | **0** — não há *parser* Pascal |

Maiores ficheiros: `scanner.l` (536 KB, parser C/C++/Java/C#/…), `doxygen.cpp` (462 KB, orquestração), `commentscan.l` (258 KB), `memberdef.cpp` (208 KB), `code.l` (198 KB), `pre.l` (186 KB), `index.cpp` (186 KB), `classdef.cpp` (181 KB), `util.cpp` (161 KB).

### 2.2 Pipeline (de `doxygen.cpp`: `parseInput()` + `generateOutput()`)

```
Doxyfile ──► Config (configimpl.l)
                │
                ▼
 ficheiros ─► pre.l (pré-processador C) ─► commentcnv.l (normaliza comentários)
                │
                ▼
           scanner.l / pyscanner.l / fortranscanner.l …   ← "outline parsers" por linguagem
                │  produzem árvore de Entry (entry.h) com blocos de documentação
                ▼
           commentscan.l  (interpreta comandos \param \brief @ref … e liga docs às Entry)
                │
                ▼
 ┌───────────── parseInput(): ~70 passos de "build*" / "find*" / "compute*" ─────────────┐
 │ buildGroupList, buildNamespaceList, buildFileList, buildClassList, buildFunctionList, │
 │ buildVarList, buildTypedefList, findMemberDocumentation, computeClassRelations,       │
 │ computeMemberRelations, buildCompleteMemberLists, computeMemberReferences,            │
 │ resolveUserReferences, generateXRefPages, addMembersToIndex, …                        │
 └───────────────────────────────────────────────────────────────────────────────────────┘
                │   Modelo semântico: Definition → ClassDef/MemberDef/FileDef/NamespaceDef/
                │   GroupDef/PageDef/DirDef/ConceptDef/ModuleDef (+ MemberList, LinkedMap)
                ▼
 generateOutput(): para cada Definition
        docparser.cpp + doctokenizer.l  → AST de documentação (docnode.h, ~50 tipos de nó)
                │  (markdown.cpp converte Markdown → comandos Doxygen antes do tokenizer)
                ▼
        Visitors (padrão Visitor): htmldocvisitor / latexdocvisitor / rtfdocvisitor /
                                   mandocvisitor / docbookvisitor / xmldocvisitor / textdocvisitor
        Geradores (OutputGen): htmlgen, latexgen, rtfgen, mangen, docbookgen, xmlgen,
                               perlmodgen, sqlite3gen, defgen  + índices, pesquisa, tag file
        Grafos: dot*.cpp (Graphviz), plantuml, mermaid, msc, diagram.cpp (nativo)
```

Observações relevantes para o port:

1. **O acoplamento à linguagem está concentrado em poucos sítios**: `pre.l` (pré-processador C), os *outline parsers* `.l` e os *code highlighters* `*code.l`. Todo o resto (modelo, resolução, documentação, saídas) é largamente agnóstico — é o que vale a pena portar.
2. **O Doxygen usa Flex/Bison** (lexers gerados). Em Delphi o equivalente natural é um lexer/parser escrito à mão (mais fácil de depurar, sem ferramenta externa).
3. **Há geração de código no build** (`configgen.py`, `scan_states.py`, `res2cc_cmd.py`, `caseconvert.py`): config.xml → `configoptions.cpp`; recursos (`templates/`) → ficheiros C++. Em Delphi: `{$R}`/ficheiros `.rc` ou pasta de recursos.
4. **Multithreading**: `threadpool.h`, geração de grafos `dot` e fontes em paralelo.
5. **Modelo de dados**: `Entry` (resultado do parser) ≠ `Definition` (modelo final). Manter esta separação.
6. **Recursos prontos a reutilizar** (`templates/`): `html/` (CSS, JS: navtree, search, dynsections, menu, tabs; `header.html`/`footer.html`), `latex/`, `xml/*.xsd`, `general/layout_default.xml`. Licença compatível (GPL; fontes Material Symbols = Apache 2.0).

### 2.3 Classificação dos módulos para o port

| Decisão | Módulos Doxygen | Notas |
|---|---|---|
| **Portar (núcleo)** | `entry`, `definition*`, `classdef`, `memberdef`, `memberlist`, `membername`, `membergroup`, `filedef`, `namespacedef`, `groupdef`, `pagedef`, `dirdef`, `linkedmap`, `symbolresolver`, `doxygen.cpp` (pipeline), `util.cpp`, `index.cpp`, `outputlist/outputgen`, `reflist`, `section`, `cite`, `layout`, `resourcemgr`, `tagreader`, `searchindex*`, `ftvhelp`, `arguments`, `message`, `portable`, `fileinfo`, `filename`, `dstring`, `regex` | `regex` → `System.RegularExpressions`; `dstring`/`textstream`/`utf8` → `string`/`TStringBuilder`/`TEncoding` |
| **Portar (documentação)** | `commentcnv.l`, `commentscan.l`, `doctokenizer.l`, `docparser`, `docnode`, `docvisitor`, `cmdmapper`, `markdown`, `htmlentity`, `emoji`, `aliases`, `formula`, `htmlattrib` | `.l` → lexers escritos à mão |
| **Portar (saídas) — por prioridade** | 1. `htmlgen` + `htmldocvisitor` + `index/navtree/search` · 2. `xmlgen` + `xmldocvisitor` · 3. `dot*` (grafos) · 4. `latexgen` + visitor · 5. `sqlite3gen`, `docbookgen` · 6. `rtfgen`, `mangen`, `htmlhelp (CHM)`, `qhp` | RTF/Man/Perlmod/Eclipse/Docsets: baixa prioridade ou descartar (ver D-012) |
| **Substituir por parser novo** | `pre.l`, `scanner.l`, `code.l`, `declinfo.l`, `defargs.l`, `constexp.l/.y` | Novo *front-end* Pascal: lexer, pré-processador (`{$IFDEF}`…), parser de contorno, *highlighter* de código Pascal |
| **Descartar** | `clangparser`, `fortran*`, `vhdl*` + `vhdlparser/`, `pyscanner/pycode`, `sqlcode`, `xmlcode`, `lexscanner/lexcode`, `perlmodgen`, `htags`, `defgen`, `stlsupport`, `dia`, `msc` (interno), `libmscgen`, `liblodepng`, `TinyDeflate`, `svg` (dep), `libversion`, `addon/doxypysql`, `addon/doxyapp`, `addon/doxyparse` | Outras linguagens e deps C++ sem equivalente útil |
| **Reescrever** | `doxywizard` (Qt) → GUI VCL; `translator_*.h` (40 classes) → ficheiros de recursos de strings por idioma; `configimpl.l` → leitor de Doxyfile manual | Ver D-009, D-010 |
| **Novo (específico Delphi)** | Leitor de `.dfm`/`.fmx` (árvore de componentes), `.dpr/.dpk/.dproj`, grafo de dependências `uses`, suporte XMLDoc (`///` + `<summary>`), RTTI/atributos, genéricos, *helpers*, *anonymous methods* | Ver §5 |

---

## 3. Mapeamento conceptual Doxygen → Pascal

| Doxygen | DoxyPas (Pascal) |
|---|---|
| File (`.cpp/.h`) | File (`.pas/.dpr/.dpk/.inc/.dfm`) |
| Namespace / Module | **Unit** (compound próprio, mostrado como "Unit"/"Unidade"; `Layout` renomeia) |
| Class / Struct | `class`, `record`, `object`, *class helper*, *record helper* |
| Interface (IDL/Java) | `interface` / `dispinterface` (com GUID) |
| Member: function/variable/typedef/enum/define | `procedure/function/constructor/destructor/operator`, `var/const/field/class var`, `type` alias, `enum`, `{$DEFINE}` |
| Property | `property` (read/write/stored/default/index) — membro de 1ª classe |
| Event/Signal | `property OnXxx: TNotifyEvent` (marcado como evento) |
| Visibility | `strict private/private/strict protected/protected/public/published` |
| Include graph | Grafo de `uses` (interface vs implementation) |
| Inheritance graph | Herança + interfaces implementadas |
| Call graph | Opcional (fase tardia — exige análise dos corpos) |
| Template | Genéricos `TFoo<T: class, constructor>` |
| Group `\defgroup` | Igual (comandos Doxygen mantidos) |
| Page / mainpage / Markdown | Igual |
| Directory | Pasta / projecto (`.dproj`) |
| Namespace-level `using` | `uses` |

---

## 4. Estrutura de pastas proposta

```
G:\Claude\DoxyPas\
├─ docs\
│  ├─ DOXYPAS.md                  ← este documento
│  └─ adr\                        ← (futuro) decisões extensas, se este ficar grande
├─ src\                           ← tudo o que é compilado no executável principal
│  ├─ DoxyPas.dpr                 ← CLI  (doxypas.exe)
│  ├─ DoxyPas.dproj
│  ├─ Core\                       ← DoxyPas.Core.*
│  │   Strings, Utils, FileUtils, Portable, Log, Messages, Threading,
│  │   LinkedMap (TLinkedMap<T>), Version
│  ├─ Config\                     ← DoxyPas.Config.*
│  │   Options (gerado), Doxyfile.Reader, Doxyfile.Writer, Values, Expand (env/aliases)
│  ├─ Lang\Pascal\                ← DoxyPas.Lang.Pascal.*    (front-end Pascal)
│  │   Tokens, Lexer, Preprocessor ({$IFDEF}/{$I}), Parser (outline), Entries builder,
│  │   Dialects (Delphi/FPC), CodeHighlighter, DfmReader
│  ├─ Lang\Project\               ← leitores .dpr/.dpk/.dproj/.groupproj/.lpi
│  ├─ Comments\                   ← DoxyPas.Comments.*
│  │   Converter (≈commentcnv), Scanner (≈commentscan), XmlDoc, PasDocCompat, Aliases, CmdMapper
│  ├─ Model\                      ← DoxyPas.Model.*   (≈ entry/definition/...)
│  │   Entry, Definition, ClassDef, MemberDef, MemberList, MemberGroup,
│  │   UnitDef, FileDef, GroupDef, PageDef, DirDef, Arguments, Sections, RefList
│  ├─ Build\                      ← DoxyPas.Build.*   (passos de parseInput)
│  │   Pipeline, BuildLists, FindMembers, Relations, Resolver (SymbolResolver), XRefs, Indexes
│  ├─ Doc\                        ← DoxyPas.Doc.*
│  │   Tokenizer, Parser, Nodes, Visitor, Markdown, HtmlEntities, Emoji, Formula, Cite
│  ├─ Output\                     ← DoxyPas.Output.*
│  │   OutputGen (interface), OutputList, Html\{Gen,DocVisitor,Index,NavTree,Search},
│  │   Xml\, Latex\, Sqlite\, Docbook\, Rtf\, Man\, Tag\ (tagfile r/w), Layout
│  ├─ Graphs\                     ← DoxyPas.Graphs.*
│  │   Dot (Runner, Node, Graph, ClassGraph, IncludeGraph, DirDeps, Collab…), PlantUml, Mermaid
│  └─ I18n\                       ← DoxyPas.I18n.*   (Translator + .lang por idioma)
├─ gui\                           ← DoxyPasWizard.dpr  (VCL; edita Doxyfile, corre o CLI)
├─ packages\                      ← (opcional) DoxyPas.Core.dpk … se vier a ser biblioteca
├─ resources\                     ← activos copiados do Doxygen/adaptados
│  ├─ html\ (css, js, header/footer, fontes)  ├─ latex\  ├─ xml\ (xsd)  ├─ layout\
│  ├─ lang\ (en.lang, pt.lang, pt-BR.lang, …) └─ config\ (options.json derivado de config.xml)
├─ tools\                         ← geradores de build (em Delphi): GenConfig, PackResources
├─ tests\
│  ├─ unit\ (DUnitX)              ← por módulo
│  ├─ golden\ (fontes Pascal + saída esperada: XML/HTML)
│  └─ corpus\ (amostras reais: RTL stubs, FPC RTL, projecto próprio)
├─ examples\                      ← exemplos documentados (≈ Doxygen examples\)
├─ third_party\                   ← (ou gerido por Boss em modules\)
├─ boss.json
├─ README.md   LICENSE (GPL-2.0)   .gitignore   .editorconfig
```

Regras de nomenclatura (D-004): unidades `DoxyPas.<Área>.<Nome>.pas`; ficheiro = nome da unidade; tipos `TFoo`, interfaces `IFoo`, excepções `EFoo`; saída de compilação fora da árvore de fontes (`build\Win64\Release\`).

---

## 5. Funcionalidades específicas Delphi/FPC a cobrir

**Parsing:** `unit/program/library/package`; `interface/implementation/initialization/finalization`; classes, records (com métodos, operadores), *helpers*, interfaces + GUID; genéricos com restrições; propriedades (indexadas, `default`); `class var/class procedure/static`; atributos `[...]`; *anonymous methods*, *reference to*; `inline`, `overload`, `virtual/override/abstract/final/reintroduce`; convenções de chamada; `external`; `asm` (ignorar corpo); `resourcestring`; `threadvar`; *forward declarations*; tipos *anónimos* em `var`; declarações de *inline variables* e *inline constants* (Delphi 10.3+); `for..in`; sintaxe Delphi 13.
**Pré-processador:** `{$DEFINE/$UNDEF/$IFDEF/$IFNDEF/$IF/$ELSE/$ENDIF/$I/$INCLUDE}`, `PREDEFINED` do Doxyfile, defines por plataforma/compilador (`MSWINDOWS`, `CPUX64`, `VER370`, `FPC`…), `{$IF CompilerVersion >= …}`.
**Comentários de documentação:** `///`, `//!`, `{** … }`, `(** … *)`, `{! … }`, comentários *trailing* (`//<`, `{!< }`), XMLDoc (`<summary> <param> <returns> <remarks> <exception> <see cref>`) e *tags* PasDoc (`@param`, `@returns`) por compatibilidade.
**Formulários:** `.dfm` / `.fmx` (texto) → árvore de componentes, propriedades e eventos ligados aos *handlers*.
**Projectos:** `.dproj`/`.dpr`/`.dpk`/`.groupproj` (e `.lpi/.lpk` FPC) para descobrir fontes, *search paths* e *defines*.
**Grafos:** herança, colaboração, dependências `uses`, directórios; opcional: *call graph*.

---

## 6. Bibliotecas, *frameworks* e componentes

Critério: **open-source/free primeiro**; comercial só se a qualidade compensar claramente (preferência do utilizador).
Estados: ✅ Escolhido · 🔶 Candidato (a validar em *spike*) · ❌ Descartado.

### 6.1 Núcleo (CLI)

| Necessidade | Opção | Licença | Estado | Notas |
|---|---|---|---|---|
| Strings, I/O, ficheiros, JSON, regex, hash, threads, zip | **RTL do Delphi** (`System.*`, `System.RegularExpressions` (PCRE2), `System.JSON`, `System.Hash`, `System.Zip`, `System.Threading`) | — | ✅ | Zero dependências; cobre `regex.*`, `md5hash`, `threadpool`, `iconv`, `utf8`, `filesystem`, `fmt/spdlog` |
| Colecções genéricas / DI | **Spring4D** | Apache 2.0 | 🔶 | `IList<T>`, `IDictionary`, `TCollections`; útil p/ `LinkedMap`/`MemberList`. Alternativa: `System.Generics.Collections` apenas (RTL) |
| XML (leitura de *tag files*, `.dproj`, escrita) | `Xml.XMLDoc` + `Xml.omnixmldom` (RTL) | — | 🔶 | Evitar MSXML (só Windows); escrita de XML por *streaming* próprio |
| Markdown | **EtheaDev MarkdownProcessor** (CommonMark/Daring Fireball) | Apache 2.0 (a confirmar) | ❌ por omissão | Doxygen tem *markdown.cpp* próprio com extensões (tabelas, `\ref`, auto-links, code fences); o resultado tem de alimentar o tokenizer de comandos → **portar `markdown.cpp`**. Usar a lib só como referência/validação |
| Motor de *templates* (HTML) | **Sempare Template Engine** | Apache 2.0 / dual | 🔶 | Opcional p/ `header.html/footer.html`/layout; o Doxygen usa o seu próprio mini-*template* (`$projectname`…) → começar com substituição simples própria |
| SQLite (saída `sqlite3gen`) | **FireDAC SQLite** ou **mORMot 2** (`mormot.db.raw.sqlite3.static`, sem DLL) | FireDAC (RAD) / MPL-GPL-LGPL | 🔶 | Decidir quando se chegar a essa saída (fase tardia) |
| Linha de comandos | RTL (`ParamStr`, `System.SysUtils`) | — | ✅ | Parser de *switches* próprio, pequeno |
| Logging | Próprio (`DoxyPas.Core.Log`, equivalente `message.cpp`: warn/error + `WARN_FORMAT`) | — | ✅ | Doxygen tem formato de avisos fixo e configurável; replicar |
| Gestão de dependências | **Boss** (`boss.json`; já presente em `~\.boss`) | MIT | ✅ | Reprodutível; sem copiar fontes para o repo |
| Testes | **DUnitX** | Apache 2.0 | ✅ | + *golden files* |
| Mocking (se necessário) | Delphi-Mocks | Apache 2.0 | 🔶 | Só se houver necessidade real |

### 6.2 Parser Pascal (decisão central — ver D-006)

| Opção | Licença | Prós | Contras | Estado |
|---|---|---|---|---|
| **A. Lexer + parser de contorno escritos à mão** | nossa | Controlo total da ligação comentário↔declaração, dialectos Delphi **e** FPC, tolerância a erros, só precisa de declarações (corpos saltados), sem dependências | Mais trabalho inicial | 🔶 **Recomendada** |
| B. **DelphiAST** (RomanYankovsky) | MPL 1.1 (a confirmar) | Pronto; AST completa | Parse "uma unit de cada vez sem tabela de símbolos"; suporte a sintaxe recente (Delphi 12/13) e **comentários** a validar; FPC mal suportado; AST completa é mais pesada que o necessário | 🔶 *spike* de comparação |
| C. **fcl-passrc** (FPC) | LGPL modificada | Muito completo p/ FPC | Código FPC (não compila em Delphi sem *port*); sem Delphi 13 | ❌ (só referência) |
| D. mwPasLex / SynEdit Pascal highlighter | MPL | Bom lexer | Só lexer; |  🔶 pode servir de base ao *highlighter* |
| E. **PasDoc** | **GPL** | Referência funcional (tags, saídas) | Código FPC; pretende-se algo diferente | ❌ (referência de funcionalidades) |

**Nota:** PasDoc já existe e é maduro. O DoxyPas distingue-se por: compatibilidade com Doxyfile/comandos Doxygen, grafos (herança/uses/colaboração), pesquisa, Markdown, saídas HTML modernas/XML/LaTeX/SQLite, múltiplas fontes de linguagem e *tag files*.

### 6.3 Ferramentas externas (opcionais, via processo)

| Ferramenta | Uso | Estado |
|---|---|---|
| **Graphviz `dot`** | Todos os grafos (já instalado: `C:\ProgramData\chocolatey\bin\dot.exe`) | ✅ (`DOT_PATH`) |
| **PlantUML** (Java 21 instalado) | `\startuml` | ✅ opcional |
| **Mermaid CLI** (`mmdc`) | `\startmermaid` | ✅ opcional |
| **LaTeX** (`pdflatex`/`xelatex`) | PDF a partir da saída LaTeX | ✅ opcional |
| **HTML Help Workshop** (`hhc.exe`) | `.chm` | ✅ opcional |
| **Perl** (`bib2xhtml.pl`) | Citações BibTeX (`\cite`) | 🔶 baixa prioridade |

### 6.4 GUI (assistente — fase tardia)

| Opção | Licença | Estado | Notas |
|---|---|---|---|
| **VCL** (Windows) | RAD | ✅ | Substitui `doxywizard` (Qt). Reutiliza `config.xml` para gerar os separadores/ajuda |
| **VirtualTreeView** (JAM Software) | MPL/Apache | 🔶 | Já instalado (`VirtualTreeview_by_JamSoftware-13 8.3`) |
| **SVGIconImageList / StyledComponents** | MPL / Apache | 🔶 | Já instalados (ícones/estilo modernos) |
| **EhLib / TRichView / FastReport / Gnostice eDocEngine / ImageEn** | **comerciais, já licenciados pelo utilizador** | ❌ para o núcleo | Não são necessários: nenhum compensa face às alternativas free/RTL. Reconsiderar *eDocEngine* só se se quiser PDF nativo sem LaTeX; *TRichView* só se se quiser saída RTF/visualizador integrado |
| **FMX** (multi-plataforma) | RAD | ❌ nesta fase | Reavaliar se for pedido Linux/macOS na GUI |

### 6.5 Outras bibliotecas avaliadas e **não** necessárias
mORMot 2 completo (excessivo para o núcleo; manter como opção p/ SQLite/JSON rápido), Indy/Taurus TLS (não há rede), FireDAC (só se SQLite), Skia4Delphi (sem renderização própria; grafos vêm do `dot`), ACBr, DataSnap, etc.

---

## 7. Registo de decisões

| ID | Data | Estado | Decisão | Justificação |
|---|---|---|---|---|
| D-001 | 2026-10-20 | Aceite | **Ponto de partida:** código do Doxygen em `G:\doxygen`, adaptado ao ecossistema Pascal; implementação **100 % Delphi** (nenhum código C/C++ em runtime). | Pedido do utilizador. |
| D-002 | 2026-10-20 | Aceite | **Fase actual = planeamento.** Não se escreve código até o utilizador aprovar a estrutura e as decisões abertas (§9). | Pedido do utilizador. |
| D-003 | 2026-10-20 | Aceite | Toda a documentação de decisão vive em `docs\DOXYPAS.md` (idioma: português europeu). Idioma dos identificadores/comentários do código: ver Q-004. | Pedido do utilizador. |
| D-004 | 2026-10-20 | Proposta | **Convenções:** unidades com *namespace* `DoxyPas.<Área>.<Nome>`; estilo Delphi (T/I/E, `F` para campos, `A` para parâmetros); *Style Guide* do plugin `delphi-dev`; UTF-8 com BOM nos `.pas`; `.editorconfig` na raiz. | Consistência e legibilidade; encoding seguro para Delphi. |
| D-005 | 2026-10-20 | **Aceite** (Q-003) | **Compilador/alvo:** Delphi 13 Florence (RAD Studio 37.0). Alvos **Win32, Win64 e Linux64** desde o M0 (Linux64 exige PAServer + SDK Linux no RAD Studio). Todo o código só com RTL (sem `Winapi.*` fora de `Core.Portable`; nada de MSXML, registo, `ShellExecute` directo). CI/testes devem correr nos três alvos. Implicações: separadores de caminho e *case-sensitivity* (`CASE_SENSE_NAMES`), `dot`/Java/LaTeX localizados via `PATH`, `Process` via RTL (`System.Net`-free) encapsulado em `Core.Portable`. | Pedido do utilizador; disciplina de portabilidade desde o início. |
| D-021 | 2026-10-20 | Aceite (Q-002) | **Só Delphi compila o DoxyPas.** FPC/Lazarus são apenas linguagem de **entrada**; sem `{$IFDEF FPC}` no código-fonte do projecto. | Pedido do utilizador. |
| D-023 | 2026-10-20 | Aceite (Q-005) | **Repositório:** `https://github.com/JFSF/DoxyPas`. A pasta local `G:\Claude\DoxyPas` ainda não é repo git; `git init` + `remote add` só no arranque do M0 e a pedido (nenhum push sem confirmação). Visibilidade (pública/privada) por confirmar — com GPL-2.0, pública é o natural. | Indicado pelo utilizador. |
| D-024 | 2026-10-20 | Aceite (interpretação provisória de Q-006) | **Primeira versão alvo: `v1.0.0`.** Versão do DoxyPas segue SemVer, independente da do Doxygen; guardar em `DoxyPas.Core.Version`. O âmbito mínimo de v1.0.0 (a definir) deve incluir pelo menos M0–M6 + GUI (D-026). | Q-006 respondida com "v1.0.0". |
| D-027 | 2026-10-20 | Aceite (Q-006) | **Versão mínima de Delphi na entrada: Delphi 10 (Seattle) e posteriores.** Sintaxe suportada inclui genéricos, *anonymous methods*, atributos, *class helpers*, e (10.3+) *inline variables/constants*. Delphi 7/2007/XE ficam fora (sem `{$IF}` legado, sem `String[N]`/`with` como caso prioritário). Os *defines* de versão (`VER300`…`VER370`) cobrem 10 Seattle → 13 Florence. | Pedido do utilizador. |
| D-028 | 2026-10-20 | Aceite (Q-006) | **Projecto de referência/validação: `G:\CodeManager`** (CodeManager.dpr/.dproj, 111 `.pas` em `src\`, 0 `.dfm/.fmx` — UI criada em código, + `tests\CodeManagerTests.dpr`). Passa a ser o 1º teste de integração real (M2: parse sem erros; M6: HTML gerado; M8: leitura de `.dproj`). Nota: sem `.dfm`, o leitor de formulários (M8) não pode ser validado com ele — será preciso outro exemplo. | Pedido do utilizador. |
| D-025 | 2026-10-20 | Aceite (Q-007) | **HTML igual ao do Doxygen:** reutilizar `templates\html` (CSS, JS, navtree, pesquisa, fontes) e a estrutura de páginas/nomes de ficheiros do original (`classTFoo.html`, `index.html`, …). Tema novo fica fora do âmbito de v1.0.0. | Pedido do utilizador; menor risco. |
| D-026 | 2026-10-20 | Aceite (Q-008) | **GUI (VCL) é a prioridade entre os extras:** passa a marco próprio **M7**, logo a seguir ao HTML (M6); Delphi extras, LaTeX/SQLite/CHM e outros idiomas deslocam-se uma posição. A GUI ainda só é VCL/Windows (Linux64 = só CLI). | Pedido do utilizador. |
| D-029 | 2026-10-20 | Aceite | **M0 — build por linha de comandos (`build.bat`) com `dcc32/dcc64/dcclinux64`, sem `.dproj` por agora.** Os `.dproj` serão criados quando a GUI/IDE o justificar (M7), para não manter dois sistemas de build à mão. SDK Linux: `%USERPROFILE%\Documents\Embarcadero\Studio\SDKs\ubuntu24.04.sdk` + `lib\linux64\release` do RAD Studio (PAServer só é preciso para depurar). | Simplicidade; validado nos 3 alvos. |
| D-030 | 2026-10-20 | Aceite | **DUnitX vem do próprio RAD Studio** (`$(BDS)\source\DUnitX`, Apache 2.0, só em testes) — não é preciso Boss para ele. `boss.json` existe mas sem dependências. Testes correm em Win32 e Win64; o executável Linux64 é verificado manualmente (WSL Ubuntu disponível) até haver CI. | Zero dependências externas no M0. |
| D-031 | 2026-10-20 | Aceite | **Git:** repositório local em `main`, `origin` = `https://github.com/JFSF/DoxyPas.git`, primeiro commit feito; **nenhum push** até confirmação do utilizador. `.gitattributes` força CRLF em `.pas/.dpr/.bat`; `.editorconfig` UTF-8 com BOM. | D-023. |
| D-032 | 2026-10-20 | Aceite | **Opções geradas (M1):** `tools\GenConfig` (Delphi, XML via `Xml.omnixmldom`) lê `resources\config\config.xml` (cópia do Doxygen 1.19.0, **não editar**) + `config_pascal.xml` (opções DoxyPas: `PASCAL_DIALECT`, `PASCAL_XMLDOC`, `PASCAL_PARSE_DFM`, `DELPHI_PROJECT`) e gera `src\Config\DoxyPas.Config.Options.pas` (356 opções, 19 grupos; **ficheiro gerado e versionado**, regenerar com `build.bat gen`). Port fiel de `transformDocs/prepCDocs` de `configgen.py` (texto dos comentários do template). Todas as opções C++ ficam aceites (D-008). | Fonte única de verdade; compila sem a ferramenta. |
| D-033 | 2026-10-20 | Aceite | **Modelo/Leitura/Escrita de Doxyfile:** `DoxyPas.Config` (valores + `PostProcess`: `$(ENV)`, vazio→defeito, conversão bool/int/enum, como `Config::postProcess`), `Config.Reader` (port de `configimpl.l`: `=`, `+=`, `\` de continuação, aspas/escapes, `#`/`##`, `@INCLUDE`/`@INCLUDE_PATH` até profundidade 10, avisos com linha/ficheiro) e `Config.Writer` (template, `-s`, `-u` mantendo texto original, `-x` diferenças). Verificado: `-g` → `-x` vazio; `-u` byte-idêntico; `doc\Doxyfile` e `testing\Doxyfile` do Doxygen lidos sem avisos. | Compatibilidade total com Doxyfiles existentes (D-008). |
| D-034 | 2026-10-20 | Aceite | **CLI (M1):** `doxypas [-g [f]] [-s] [-u [f]] [-x [f]] [-v] [-h] [f]` em `DoxyPas.Cli.RunCli` (testável); `-g` recusa sobrescrever (usar `-` para stdout); `-u` cria `.bak`. Diagnósticos via `Core.Log` com `LogSink` substituível (testes). **Atalhos conhecidos:** `DOXYFILE_ENCODING` aplicado a todo o ficheiro (Doxygen só a partir da tag); comentários `##` no início do ficheiro tratados como os do fim; `-x_noenv` não implementado; quebra de linhas dos comentários do template só por espaços (Doxygen também parte palavras longas). | Âmbito mínimo do M1. |
| D-022 | 2026-10-20 | Aceite (Q-004) | **Identificadores, comentários de código, mensagens de log/CLI base e nomes de ficheiros em inglês**; a documentação do projecto (`docs\`) em português europeu; textos de UI via ficheiros `.lang` (D-010). | Pedido do utilizador. |
| D-006 | 2026-10-20 | Proposta (spike pendente) | **Front-end Pascal escrito à mão** (lexer + pré-processador + parser de contorno que salta corpos), em vez de DelphiAST/Flex. Executar um *spike* de 1–2 dias comparando com DelphiAST (comentários, Delphi 13, FPC, desempenho) antes de confirmar. | Controlo da associação comentário↔declaração e dos dialectos; só se precisam declarações. |
| D-007 | 2026-10-20 | Proposta | **Dois níveis de entrada no pipeline:** `Parser → Entry (árvore)` → passos `Build/*` → `Definition (modelo)` → `Doc parser (AST)` → `Visitors` → `OutputGen`. Mantém-se a arquitectura do Doxygen (separação Entry/Definition, padrão Visitor, `OutputList` com vários geradores). | Reduz risco do port; facilita comparar comportamento com o original. |
| D-008 | 2026-10-20 | Proposta | **Compatibilidade com Doxyfile:** ler o formato existente (352 opções), aceitar opções C++-only sem erro (ignorar com aviso opcional), e adicionar opções Pascal com prefixo próprio (`PASCAL_DIALECT`, `PASCAL_XMLDOC`, `PASCAL_PARSE_DFM`, `DELPHI_PROJECT`, …). Nome por defeito do ficheiro: `Doxyfile`. | Reaproveita documentação, scripts e conhecimento dos utilizadores. |
| D-009 | 2026-10-20 | Proposta | **Opções geradas de `config.xml`:** ferramenta `tools\GenConfig` (Delphi) transforma `config.xml` (copiado/adaptado para `resources\config`) em `DoxyPas.Config.Options.pas` (+ texto de ajuda para a GUI). Substitui `configgen.py`. | Fonte única de verdade; sem Python no build. |
| D-010 | 2026-10-20 | Proposta | **Internacionalização:** em vez de 40 classes `translator_*`, um conjunto de ficheiros `.lang` (chave→texto) em `resources\lang`, carregados em *runtime*. Prioridade: `en`, `pt` (PT), `pt-BR`; restantes idiomas migrados por *script* a partir dos `translator_*.h`. | Evita 40×(60–100 KB) de código; fácil de contribuir. |
| D-011 | 2026-10-20 | Proposta | **Idioma de entrada:** só Pascal (Delphi + FPC) + `.dfm/.fmx`. Sem C/C++/Python/Fortran/VHDL/SQL/XML/clang. | Âmbito do projecto. |
| D-012 | 2026-10-20 | Proposta | **Formatos de saída — prioridade:** (1) HTML, (2) XML, (3) Tag file + pesquisa, (4) LaTeX, (5) SQLite, (6) Docbook, (7) CHM/QHP/RTF/Man. Perl-mod, Eclipse-help, Docsets: **descartados** salvo pedido. | Cobre >95 % do uso; reduz esforço. |
| D-013 | 2026-10-20 | Proposta | **Grafos via Graphviz `dot`** (processo externo, como no original); `diagram.cpp` nativo (PNG com lodepng) **não** será portado. Suporte a PlantUML/Mermaid como opcional. | Menos código; qualidade superior. |
| D-014 | 2026-10-20 | Proposta | **Markdown:** portar `markdown.cpp` do Doxygen (e não usar uma biblioteca externa), por estar integrado com os comandos Doxygen. | Necessário para `\ref`, auto-links, blocos de código e tabelas no mesmo fluxo. |
| D-015 | 2026-10-20 | Proposta | **Resolução de símbolos Pascal:** `unit` actua como espaço de nomes; `uses` (interface/implementation) define visibilidade; *unit scope names* (`System.`, `Vcl.`, …) tratados como o `UNITSCOPENAME` do compilador. | Necessário para que `\ref`/auto-links e grafos funcionem como em Delphi. |
| D-016 | 2026-10-20 | Proposta | **Dependências geridas por Boss** (`boss.json`); usar RTL sempre que possível; qualquer dependência de terceiros exige entrada em §6 com licença verificada. | Reprodutibilidade, menor superfície. |
| D-017 | 2026-10-20 | Proposta | **Testes:** DUnitX por módulo + *golden tests* (fonte Pascal → XML/HTML esperados) + **auto-documentação** (correr DoxyPas sobre o próprio código-fonte como teste de integração). | Detecta regressões de parser e de saída. |
| D-018 | 2026-10-20 | **Aceite** (Q-001) | **Licença do projecto: GPL v2.** Obras derivadas do Doxygen (port de código e *templates*) herdam GPL-2.0; Apache 2.0 é incompatível com GPL-2.0-*only* (só com GPLv3), logo cada dependência Apache (Spring4D, Sempare, DUnitX) deve ser vista caso a caso; DUnitX só em testes (não distribuído). | O ficheiro `LICENSE` do Doxygen é GPL v2; cabeçalhos dizem "GNU General Public License" sem "or later" explícito. |
| D-019 | 2026-10-20 | Proposta | **GUI:** VCL (assistente de configuração + execução + pré-visualização), em fase tardia; CLI é o produto primário. | Substitui `doxywizard`; sem Qt. |
| D-020 | 2026-10-20 | Proposta | **Componentes comerciais já licenciados (EhLib, TRichView, FastReport, Gnostice, ImageEn, AlphaControls, BSF):** não entram no núcleo nem no CLI; avaliar só para a GUI se algum justificar claramente. | Preferência do utilizador por open-source e nada no núcleo precisa deles. |

---

## 8. Roadmap proposto (marcos)

| Marco | Conteúdo | Critério de saída |
|---|---|---|
| **M0 — Fundações** | Repositório (git), `.editorconfig`, Boss, projecto CLI vazio, `Core` (strings/log/threads), DUnitX a correr | `doxypas --version` e testes verdes |
| **M1 — Config** | `GenConfig`, leitor de Doxyfile (352 opções), `--help`, `-g` (gerar Doxyfile) | Lê/escreve Doxyfiles do Doxygen sem perda |
| **M2 — Front-end Pascal** | Lexer, pré-processador, parser de contorno, `Entry`, ligação comentário↔declaração; *spike* DelphiAST | Parse de RTL/FPC RTL sem erros em >99 % das units |
| **M3 — Comentários e docs** | `commentcnv/commentscan`, `doctokenizer`, `docparser`, Markdown, XMLDoc | Árvore de docs correcta p/ corpus de testes |
| **M4 — Modelo e resolução** | `Definition`s, passos `Build/*`, relações de classes/membros, `uses`, links | XML de saída = esperado nos *golden tests* |
| **M5 — Saída XML + Tag** | `xmlgen`, `tagreader/writer` | XML valida contra `compound.xsd` |
| **M6 — Saída HTML** | `htmlgen`, visitor, índices, navtree, pesquisa, grafos `dot` | Documentação navegável do próprio DoxyPas |
| **M7 — GUI VCL** (D-026) | Assistente de configuração a partir de `config.xml`, execução do CLI, pré-visualização | Editar e correr um Doxyfile sem tocar na linha de comandos |
| **M8 — Delphi extras** | DFM/FMX, `.dproj`, XMLDoc completo, grafo `uses`, genéricos/atributos | Documentar um projecto real (a escolher) |
| **M9 — Extras** | LaTeX, SQLite, CHM, outros idiomas | Conforme prioridade |

---

## 9. Questões em aberto (para o utilizador)

| ID | Questão | Recomendação |
|---|---|---|
| Q-001 | ~~Licença~~ | **Resolvida:** GPL-2.0 → D-018 |
| Q-002 | ~~FPC como alvo de compilação?~~ | **Resolvida:** só Delphi → D-021 |
| Q-003 | ~~Plataformas~~ | **Resolvida:** Win32/Win64/Linux64 → D-005 |
| Q-004 | ~~Idioma do código~~ | **Resolvida:** inglês → D-022 |
| Q-005 | ~~Repositório git~~ | **Resolvida:** https://github.com/JFSF/DoxyPas → D-023 |
| Q-006 | ~~Referência e versão mínima~~ | **Resolvida:** Delphi 10+ e projecto CodeManager → D-027, D-028 (e "v1.0.0" em D-024) |
| Q-007 | ~~Aspecto do HTML~~ | **Resolvida:** igual ao Doxygen → D-025 |
| Q-008 | ~~Prioridade GUI/secundárias~~ | **Resolvida:** GUI primeiro → D-026 |

---

## 10. Registo de alterações do documento

| Data | Alteração |
|---|---|
| 2026-10-20 | **M1 concluído:** GenConfig + Config (Options/Config/Reader/Writer) + CLI (`-g -s -u -x`); 19 testes DUnitX verdes em Win32/Win64; binário Linux64 verificado em WSL. Decisões D-032…D-034. |
| 2026-10-20 | **M0 concluído:** `doxypas --version` → `0.1.0` em Win32, Win64 e Linux64 (testado em WSL); 3 testes DUnitX verdes em Win32/Win64. Unidades: `Core.Version`, `Core.Log`. Decisões D-029…D-031. Pendente do M0: threading utilitário, `LinkedMap` e `Strings` ficam para quando o M1/M2 os exigirem; CI não configurado. |
| 2026-10-20 | Q-006 resolvida: Delphi 10+ (D-027), CodeManager como referência (D-028). Todas as questões Q-001…Q-008 fechadas. |
| 2026-10-20 | Q-007, Q-008 resolvidas (D-025, D-026); Q-006 parcial (D-024); roadmap: GUI = M7. |
| 2026-10-20 | Q-005 resolvida: repositório GitHub (D-023). |
| 2026-10-20 | Respostas a Q-001…Q-004: D-018 e D-005 aceites/actualizadas; novas D-021, D-022. |
| 2026-10-20 | Criação. Análise do Doxygen 1.19.0, estrutura de pastas, avaliação de bibliotecas, decisões D-001…D-020, roadmap e questões em aberto. |
