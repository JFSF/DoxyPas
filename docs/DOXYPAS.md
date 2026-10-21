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
| **A. Lexer + parser de contorno escritos à mão** | nossa | Controlo total da ligação comentário↔declaração, dialectos Delphi **e** FPC, tolerância a erros, só precisa de declarações (corpos saltados), sem dependências | Mais trabalho inicial | ❌ Descartada após *spike* (reavaliar só para lexer/highlighter) |
| B. **DelphiAST** (RomanYankovsky) | **MPL-2.0** (confirmado) | Pronto; AST completa | Parse "uma unit de cada vez sem tabela de símbolos"; suporte a sintaxe recente (Delphi 12/13) e **comentários** a validar; FPC mal suportado; AST completa é mais pesada que o necessário | ✅ **Escolhida (D-035)** — ver §6.2.1 |
| C. **fcl-passrc** (FPC) | LGPL modificada | Muito completo p/ FPC | Código FPC (não compila em Delphi sem *port*); sem Delphi 13 | ❌ (só referência) |
| D. mwPasLex / SynEdit Pascal highlighter | MPL | Bom lexer | Só lexer; |  🔶 pode servir de base ao *highlighter* |
| E. **PasDoc** | **GPL** | Referência funcional (tags, saídas) | Código FPC; pretende-se algo diferente | ❌ (referência de funcionalidades) |

**Nota:** PasDoc já existe e é maduro. O DoxyPas distingue-se por: compatibilidade com Doxyfile/comandos Doxygen, grafos (herança/uses/colaboração), pesquisa, Markdown, saídas HTML modernas/XML/LaTeX/SQLite, múltiplas fontes de linguagem e *tag files*.


#### 6.2.1 Resultados do *spike* DelphiAST (2026-10-20)

Harness em `tools\spikes\delphiast\` (Delphi 13, Win64, `TPasSyntaxTreeBuilder` com `InitDefinesDefinedByCompiler`).

| Corpus | Ficheiros | OK | Falhas | Velocidade |
|---|---|---|---|---|
| `G:\CodeManager` (projecto de referência, D-028) | 111 | **111** | 0 | 3 MB/s (completo) · 10 MB/s (`InterfaceOnly`) |
| Fonte do RAD Studio 13 completo (`rtl vcl fmx data indy soap…`) | 2 475 | **2 461 (99,4 %)** | 14 | 6,4 MB/s (137 MB em 21 s) |
| Módulos Boss instalados | 143 | 143 | 0 | — |
| DUnitX | 85 | 85 | 0 | — |
| `modern.pas` (inline var, atributos, genéricos, *helpers*, `is not`, métodos anónimos) | 1 | 1 | 0 | — |
| FPC (`fcl-base`, `fcl-json`, `fcl-passrc`; `*.pp`, só *interface*) | 79 | 75 (95 %) | 4 | 29 MB/s |

- **Memória:** pico de 38 MB a processar `vcl` (árvore libertada por ficheiro).
- **Linux64:** compila com `dcclinux64` sem alterações e corre em WSL (as 4 falhas no CodeManager vêm de `{$IFDEF MSWINDOWS}` — comportamento esperado).
- **As 14 falhas do RAD:** 6 units iOS/Android (`library`/`external` com constantes e sintaxe de *bridge*), `System.Rtti`, `Vcl.Edge`/`FMX.WebBrowser.Win` (`stdcall` em declarações de interface), `iOSapi.CoreGraphics`, etc. — todas obscuras e corrigíveis por *patch*.
- **Comentários:** lista plana com linha/coluna (`Builder.Comments`) — a associação a declarações (`///`, `//!`, `{** }`, XMLDoc) faz-se por posição no DoxyPas.
- **Limitações a tratar no M2:** posições `end_line/end_col` das declarações imprecisas (apontam para o *token* seguinte) → texto da declaração obtido por intervalo de *tokens*/reconstrução; `class var` não marca o campo; um erro de sintaxe aborta a unit (a excepção traz a árvore parcial); FPC (modos `objfpc`, `deprecated 'msg'` em propriedades, `generic/specialize`) a ~95 % → *patches* conforme os corpora do M2.
- **Fidelidade da AST:** visibilidade (`STRICTPRIVATE…PUBLISHED`), directivas (`virtual/override/abstract/stdcall/overload`), genéricos e restrições, atributos, GUID de interfaces, propriedades (`read/write`), parâmetros (`const/out/var`) — tudo presente.

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
| D-035 | 2026-10-20 | Aceite | **Parser Pascal = DelphiAST** (RomanYankovsky, **MPL-2.0**, compatível com GPL-2.0 — §3.3 do MPL lista a GPL-2.0 como *Secondary License*; os ficheiros do DelphiAST mantêm a licença MPL), atrás de uma interface própria (`DoxyPas.Lang.Pascal.Parser` → `Entry`), para poder trocar de motor. **Substitui D-006** (parser à mão). Cópia *vendored* em `third_party\DelphiAST\` (commit 3840253) com `PATCHES.md`; decidir mais tarde se se faz *fork* `JFSF/DelphiAST` consumido via Boss. Um lexer próprio (leve) só será escrito para o *highlighter* de código e para a associação precisa comentário↔declaração, se necessário. Resultados do *spike* em §6.2.1. | Cobertura e velocidade muito acima do esperado; um parser à mão custaria semanas só para igualar a cauda longa de sintaxe. |
| D-036 | 2026-10-20 | Aceite | **Modelo `Entry` (M2):** `DoxyPas.Model.Entry` — árvore `TEntry` com `Kind` (unit, class, method, field, constant, property, type alias, enum, enum value), `ClassKind` (class/record/object/interface/dispinterface/helpers), `TRoutineKind`, `Protection` (6 níveis, incl. *strict*), `Virtualness`, conjunto de `Flags` (class member, static, abstract, final, sealed, inline, overload, reintroduce, forward, external, deprecated, platform, …), `Args`, `TypeParams`, `Bases`, `Attributes`, `Directives`, propriedades (read/write/index/stored/default), `Doc` e posições (início/fim). Os textos (tipos, valores por omissão) são **texto-fonte** normalizado. Nome do enum de rotinas é `TRoutineKind` (colide com `System.TypInfo.TMethodKind`). | Equivalente Pascal do `Entry` do Doxygen; alimenta o M4. |
| D-037 | 2026-10-20 | Aceite | **Texto exacto a partir do código-fonte, estrutura a partir do DelphiAST:** `DoxyPas.Lang.Pascal.Source` é um *tokenizer* tolerante (comentários, directivas, *strings* incl. multilinha do Delphi 12, números) com `Slice`/`ScanTo` (respeita `()`, `[]`, `<>`, `record…end`). A AST do DelphiAST perde `of object`, `static`, `deprecated`, valores por omissão, subintervalos, etc.; por isso tipos, valores, directivas e `class var` são lidos do texto. | Fidelidade das declarações mostradas na documentação. |
| D-038 | 2026-10-20 | Aceite | **Comentários de documentação:** `///`, `//!`, `{** }`, `{! }`, `(** *)`, `(*! *)` (antes) e as variantes com `<` (depois: `///<`, `//!<`, `{!< }`, `(**< *)`); linhas `///`/`//!` consecutivas formam um bloco; `//`, `{ }`, `(* *)` e `////` **não** são documentação. Associação por posição na árvore (bloco *antes* → próxima declaração, só com atributos/comentários/palavras de secção (`type var const …`) no intervalo; bloco *depois* → declaração anterior, ou o contentor se vier logo a seguir ao `end;`/cabeçalho). Vários blocos na mesma entidade juntam-se. O texto fica **bruto** em `Entry.Doc` (marcadores removidos); XMLDoc e comandos Doxygen são interpretados no M3. Comentários `{ }` simples como documentação (estilo PasDoc) ficam como opção futura. | Semântica do Doxygen adaptada ao Pascal. |
| D-039 | 2026-10-20 | Aceite | **Defines e plataforma:** não se usa `InitDefinesDefinedByCompiler` (depende da plataforma em que o DoxyPas foi compilado). `DefaultPascalDefines(dialecto, plataforma)` produz o conjunto (Delphi: `VER370`, `UNICODE`, `CONDITIONALEXPRESSIONS`, … + plataforma; FPC: `FPC`, `CPU64`, …); nova opção `PASCAL_PLATFORM` (Win32/Win64/Linux64/macOS/iOS/Android, defeito Win64) e `PREDEFINED` (só o nome conta) → `PascalOptionsFromConfig`. **Limitação conhecida:** `{$IF CompilerVersion >= N}` e `RTLVersion` usam as constantes do compilador que compilou o DoxyPas (Delphi 13 = 37.0) — equivale a "documentar como Delphi 13". | Resultado independente da plataforma de compilação do DoxyPas. |
| D-040 | 2026-10-20 | Aceite | **DelphiAST *vendored*** em `third_party\DelphiAST\` (commit 3840253) com `PATCHES.md`. Patch 1: `SetCurrentCompoundNodesEndPosition` já não reescreve `FileName` (o fim é lido depois do *lookahead* do lexer e trocava o ficheiro de origem do nó quando há `{$I}` a seguir). Ficheiros `{$I}`: cada nó é lido no ficheiro onde começa (cache de `TPasSource` por ficheiro); a associação de comentários só cobre o ficheiro principal (**limitação:** docs dentro de `.inc` não são associadas). | Entidades vindas de *includes* com texto correcto. |
| D-041 | 2026-10-20 | Aceite | **Erros de sintaxe:** `ParsePascalFile/Text` devolve sempre a árvore (parcial se houver erro) e `ErrorMessage/Line/Col`; ficheiros sem BOM são lidos como UTF-8 e, se inválido, na página de código ANSI. Comando de desenvolvimento `doxypas --parse <ficheiro|pasta> [Doxyfile] [--verbose] [--interface-only]` (ficheiro: despeja as entidades; pasta: resumo). Saída em UTF-8 (`SetTextCodePage`, `SetConsoleOutputCP`). | Diagnóstico e *golden tests*. |
| D-042 | 2026-10-20 | Aceite | **Pipeline de documentação (M3):** texto bruto de `Entry.Doc` → `ALIASES` → XMLDoc → secções condicionais (`\cond`, `\if…\endif` com `ENABLED_SECTIONS`) → Markdown → separação *brief*/*detailed* → comandos ao nível da entidade (`\ingroup`, `\internal`, `\public/\protected/\private`, `\static`, `\overload`, `\hide/\showinitializer`, `\details`) → `Entry.Brief/Detailed/Groups/Flags` (`DoxyPas.Comments.Scanner` + `EntryDocs`). A AST só é construída quando for precisa (`DoxyPas.Doc.Parser`); o texto fica em formato Doxygen/HTML como no original. | Mesma arquitectura de `commentscan` → `docparser`. |
| D-043 | 2026-10-20 | Aceite | **Brief/detailed = semântica do Doxygen:** sem `\brief`/`<summary>` não há *brief* implícito, salvo `JAVADOC_AUTOBRIEF` (1ª frase) ou `QT_AUTOBRIEF` (1ª linha); um comentário *depois* da declaração (`///<`) é *brief*. `\brief` termina em linha em branco ou em linha que comece por comando de bloco (`\param`, `\return`, …). Blocos autónomos `\page`, `\mainpage`, `\defgroup`, `\addtogroup` viram entradas `ekPage`/`ekGroup` sob a unit; `\file` documenta a própria unit. | Compatibilidade com Doxyfiles e hábitos Doxygen; um `PASCAL_AUTOBRIEF` próprio só se vier a ser pedido. |
| D-044 | 2026-10-20 | Aceite | **Markdown → Doxygen (`DoxyPas.Doc.Markdown`):** cabeçalhos ATX/setext, ênfase (`* _ ** __ ~~`, `_` só no início de palavra para não estragar `snake_case`), *code spans*, blocos cercados e indentados (→ `\code`), listas (aninhadas, ordenadas, soltas), citações, tabelas (alinhamento), régua, ligações, imagens, *autolinks*, quebras duras e escapes; blocos `\code`, `\verbatim`, `\f[`… passam intactos. **Não suportado ainda:** ligações por referência (`[a][b]`), notas de rodapé, blocos HTML Markdown, listas de definições. | Mesmo desenho do `markdown.cpp` (texto → texto), testável isoladamente. |
| D-045 | 2026-10-20 | Aceite | **AST de documentação (`DoxyPas.Doc.Nodes`):** uma só classe `TDocNode` com `Kind` (parágrafo, texto, estilo, símbolo, URL/e-mail, ligação, `\ref`, âncora, verbatim, fórmula, listas, tabelas, secção simples, lista de parâmetros, secção/página, imagem, `\copydoc/\inheritdoc`, …) em vez de ~50 classes. Parser de caracteres único (comandos Doxygen + etiquetas HTML + entidades). **Etiquetas HTML desconhecidas ficam como texto literal** (genéricos `TList<T>` são comuns em Pascal); comando desconhecido gera aviso e fica literal; `\` ou `@` colados a uma palavra/caminho (`C:\Temp`, `a@b`) não são comandos (excepto `\endxxx`). | Menos código; tolerância a texto real. |
| D-046 | 2026-10-20 | Aceite | **XMLDoc (`PASCAL_XMLDOC`):** `<summary>`→`\brief`, `<remarks>`→`\remark`, `<param name>`→`\param`, `<typeparam>`→`\tparam`, `<returns>`→`\return`, `<exception cref>`→`\exception`, `<example>/<value>`→`\par`, `<para>`, `<c>`/`<code>`, `<list>/<item>/<term>/<description>`→listas/tabela HTML, `<see cref/href/langword>`, `<seealso>`, `<paramref>`, `<inheritdoc [cref]>`. Só se activa com etiquetas inequívocas (não com HTML normal). | Convenção do Delphi Help Insight. |
| D-047 | 2026-10-20 | Aceite | **Modelo semântico (M4) — `DoxyPas.Model.Defs/Project`:** `TDefinition` → `TScopeDef` (símbolos por nome, sem distinguir maiúsculas) → `TUnitDef` (uses resolvidos, `UsedBy`, membros, classes), `TClassDef` (bases resolvidas, derivadas, membros, classes aninhadas, `AllMembers`), mais `TMemberDef` (função, variável, propriedade, typedef, enumeração, valor de enumeração, constante; `Impl`, `Reimplements`, `ReimplementedBy`, `ReadMember/WriteMember`), `TGroupDef`, `TPageDef`. `TProject` é dono de tudo e guarda os *Roots* (`Entry`) do parser. | Equivalente Pascal da hierarquia `Definition` do Doxygen. |
| D-048 | 2026-10-20 | Aceite | **Passes (`DoxyPas.Build.Passes`):** criar definições → juntar implementações às declarações (método `TFoo.Bar` ↔ membro `Bar` de `TFoo` por nome e argumentos; rotinas sem declaração ficam *impl-only*; docs da declaração e da implementação juntam-se) → resolver `uses`, bases (com `TFoo = class(TFoo)` de outra unit), acessores de propriedades → listas completas de membros (membros ocultos por redeclaração/`reintroduce` e `private` de outras units excluídos) → `Reimplements` (override/implementação de interface) → `INHERIT_DOCS` → `\copydoc/\copybrief/\copydetails/\inheritdoc` → grupos (`\ingroup`, sub-grupos) → nomes de ficheiro → validação (não documentado, `\param` inexistente, `\ref` por resolver, `WARN_NO_PARAMDOC`). | Mesma ordem lógica de `parseInput()`. |
| D-049 | 2026-10-20 | Aceite | **Resolução de nomes Pascal:** identificadores sem distinguir maiúsculas; procura em classe (e ascendentes) → âmbitos envolventes → unit → units usadas (implementação, depois *interface*, da última para a primeira) → nomes de units → qualquer unit do projecto (para `\ref`). Nomes qualificados (`Unit.Classe.Membro`, `Classe::Membro`, `Enum.Valor`), parâmetros genéricos e `()` ignorados. Nova opção **`PASCAL_UNIT_SCOPES`** (`System`, `Vcl`, `FMX`, …): `Classes` resolve para `System.Classes`. Valores de enumeração são símbolos do âmbito que os contém. | Reproduz as regras do compilador o suficiente para ligações fiáveis. |
| D-050 | 2026-10-20 | Aceite | **Visibilidade (`TProject.IsVisible`):** `EXTRACT_ALL`, `EXTRACT_PRIVATE` (inclui *strict private*), `EXTRACT_STATIC` (itens só da secção *implementation*), `EXTRACT_LOCAL_CLASSES`, `HIDE_UNDOC_MEMBERS/CLASSES`, `INTERNAL_DOCS`/`\internal`; um item sem documentação aparece (sem secção própria) dentro de um contentor documentado. Units são visíveis se documentadas ou com algum membro visível. | Semântica do Doxygen mapeada para Pascal. |
| D-051 | 2026-10-20 | Aceite | **Nomes de ficheiro como no Doxygen** (`convertNameToFile`/`escapeCharsInString`): `class`/`struct`/`interface` + `Unit::Classe` (`classUnit_1_1TFoo`; com `CASE_SENSE_NAMES=NO` as maiúsculas viram `_x`: `class_unit_1_1_t_foo`), `unit` + nome para units (nova designação; o Doxygen usaria *namespace*/*file*), `group__nome`, `index` para a *mainpage*, âncoras de membros `a` + MD5 (qualificado + assinatura); nomes ≥ 128 caracteres → corte + MD5. Os *golden tests* fixam `CASE_SENSE_NAMES = NO`. | D-025: mesma estrutura de nomes do original. |
| D-052 | 2026-10-20 | Aceite | **Entrada e paralelismo:** `CollectInputFiles` (INPUT, `FILE_PATTERNS`, `RECURSIVE`, `EXCLUDE`, `EXCLUDE_PATTERNS`, ordenação estável); se `FILE_PATTERNS` está no valor por omissão (lista C/C++ do Doxygen) usam-se `*.pas *.dpr *.dpk *.pp *.lpr`. O *parsing* e a leitura dos comentários correm em `TParallel.For` (sem estado partilhado); resultados idênticos ao modo sequencial (testado; `--verbose` força 1 *thread*). Comando de desenvolvimento `doxypas --model <caminho> [Doxyfile]` mostra o modelo. | Velocidade sem perder determinismo. |
| D-053 | 2026-10-20 | Aceite | **Saída XML (M5) — `DoxyPas.Output.XmlGen`:** `index.xml`, um `<id>.xml` por classe/*record*/interface (`class`/`struct`/`interface`), **unit (`kind="namespace"`)**, grupo e página (`indexpage` para a *mainpage*), mais `compound.xsd`, `index.xsd` e `xml.xsd`. Estrutura do Doxygen: `compoundname`, `basecompoundref`/`derivedcompoundref`, `innerclass`, `templateparamlist` (genéricos + restrições), `sectiondef` por visibilidade (`public-func`, `private-attrib`, `public-static-func`, `property`, … ; units: `typedef`, `enum`, `func`, `var`), `memberdef` (`type`, `definition`, `argsstring`, `qualifiedname`, `read/write`, `reimplements/reimplementedby`, `param`, `enumvalue`, `initializer`, `location` com `bodyfile` da implementação), `listofallmembers`; a *uses* faz de `includes/includedby`. `xml:lang` vem de `OUTPUT_LANGUAGE`; caminhos relativos a `STRIP_FROM_PATH` com `/`. O `compound.xsd` incluído tem **`Pascal` na lista de linguagens**. **Validado contra os XSD**: CodeManager 197/197 ficheiros, 121 ficheiros aleatórios de `vcl` (1 542 ficheiros, 78 MB em 14 s), casos *golden* 15/15. | Consumível pelas ferramentas que lêem XML do Doxygen. |
| D-054 | 2026-10-20 | Aceite | **Documentação → XML (`DoxyPas.Output.XmlDoc`):** parágrafos, estilos (`bold`, `emphasis`, `computeroutput`, …), `ulink`, `ref` (`kindref` compound/member, `external` para *tag files*), âncoras, listas, tabelas, `simplesect`, `parameterlist` (com `direction`), `xrefsect` (todo/bug/test/deprecated), `sect1…sect6`, `programlisting` (`\code`), `verbatim`, `formula`, imagens. **Autolink (`AUTOLINK_SUPPORT`) sensível a maiúsculas**: só classes, units, `Nome()` e nomes qualificados (e *typedefs*/enumerações em contexto de tipo); `%Palavra` suprime; não liga a si próprio. Resolução em `DoxyPas.Model.Links` (`\ref` → compound/membro/grupo/página/secção/âncora/externo). | Comportamento do Doxygen, partilhado com os outros geradores. |
| D-055 | 2026-10-20 | Aceite | **Tag files (`DoxyPas.Output.TagFile`):** escrita (`GENERATE_TAGFILE`: classes, units, grupos, páginas, membros com `anchorfile`/`anchor`/`arglist`) e leitura (`TAGFILES = ficheiro=url`) para `TProject.Externals`; um símbolo externo é encontrado pelo nome completo e por todos os sufixos (`ns.Foo.bar`, `Foo.bar`, `bar`; `::` ou `.`). Lidos antes da validação para que `\ref` externos não gerem aviso. Compatível com *tag files* do Doxygen (testado com formato original). XML lido com `Xml.omnixmldom` (multiplataforma). | Ligações entre projectos. |
| D-056 | 2026-10-20 | Aceite | **Recursos embebidos:** `tools\PackResources` gera `src\Resources\DoxyPas.Resources.Xml.pas` (XSD) a partir de `resources\xml\`, para o executável não depender de ficheiros externos (Win32/Win64/Linux64). `build.bat gen` regenera tudo (opções + recursos). | Executável autónomo. |
| D-057 | 2026-10-20 | Aceite | **Execução normal (`doxypas [Doxyfile]`):** lê o Doxyfile, recolhe os ficheiros, constrói o modelo e escreve as saídas activas (`GENERATE_XML` em `OUTPUT_DIRECTORY\XML_OUTPUT`, `GENERATE_TAGFILE`); mensagens de progresso salvo `QUIET`; avisos em `stderr` se `WARNINGS`; `GENERATE_HTML` por implementar → nota (M6). Sem ficheiros de entrada → erro. | Primeiro fluxo ponta-a-ponta. |
| D-058 | 2026-10-20 | Aceite | **Fora do M5 (a fazer):** `programlisting` do código-fonte (precisa do *highlighter* Pascal), grafos (`inheritancegraph`, `collaborationgraph`, `incdepgraph`), `Doxyfile.xml`, listas de *xrefitem* (todo/bug), `references/referencedby`, `\ref` para âncoras de secções em membros. | Âmbito do marco. |
| D-059 | 2026-10-20 | Aceite | **Saída HTML (M6) — `Output.HtmlGen/HtmlDoc/HtmlTemplate`, `Resources.Html`:** páginas por classe (+ `-members`), unit (`unit…`, *namespace*), grupo e página; índices `annotated`, `classes`, `hierarchy`, `namespaces`, `topics`, `pages`, `functions`; `menudata.js`, árvore (`navtreedata.js`, `navtreeindex*.js`) e dados de pesquisa cliente (`search/`). Usa os modelos, CSS e JS do Doxygen 1.19 (`resources\html`, embebidos via `PackResources -b64`), com cabeçalho/rodapé próprios ("Generated by DoxyPas"); `HTML_COLORSTYLE`, `GENERATE_TREEVIEW`, `SEARCHENGINE`, `DISABLE_INDEX`, `FULL_SIDEBAR`, `HTML_HEADER/FOOTER/STYLESHEET/EXTRA_STYLESHEET` suportados. Inglês apenas. |
| D-060 | 2026-10-20 | Aceite | **Fora do M6 (a fazer):** grafos (`dot`), navegador de código-fonte e *highlighter*, fórmulas, pesquisa por servidor, `HTML_DYNAMIC_MENUS = NO`, `LAYOUT_FILE`, listas *todo/bug*, tradução. **Por verificar:** inspecção visual no browser (a extensão não estava ligada); só se confirmou a geração (CodeManager: 345 ficheiros) e 84 testes verdes. |
| D-061 | 2026-10-20 | Aceite | **GUI VCL (M7) — `src\Gui`:** janela criada em código (sem DFM), com as 19 secções e 358 opções de `config.xml` geradas a partir de `ConfigOptions` (caixa, número, lista, *combo*, texto; a ajuda é a *hint*). Abre/grava Doxyfiles com `Config.Reader/Writer`, executa o `DoxyPas.exe` vizinho num processo oculto (saída no registo, sem bloquear) e abre o `index.html`. `build.bat` compila-a para Win32/Win64 junto da CLI. **Não feito:** pré-visualização embebida, validação por opção, pesquisa de opções, *Linux* (só CLI). Só se confirmou que compila e arranca; não foi usada de ponta a ponta. |
| D-062 | 2026-10-20 | Aceite | **Extras Delphi (M8):** (1) `DELPHI_PROJECT` (`Lang.Project`): `.dproj` lido por expressões regulares (funciona em Linux): `MainSource` e `DCCReference *.pas` entram nos ficheiros de entrada; `DCC_Define` e `DCC_UnitSearchPath` só dos grupos sem condição ou `Base` (os de Debug/Release não) alimentam os *defines* e `INCLUDE_PATH` do parser; `.dpr`/`.dpk`: `in 'x.pas'`. (2) `.dfm`/`.fmx` em texto (`PASCAL_PARSE_DFM`, `Lang.Pascal.Dfm`): cada formulário vira uma **página** `form_<ficheiro>` com a árvore de componentes (classe, `Caption`/`Text`, manipuladores `OnXxx`); a classe do formulário liga-se automaticamente; formulários binários dão aviso. (3) Página HTML da unit com «Used by». **Fora do M8:** grafo `uses` desenhado (precisa de `dot`), `.groupproj`/`.lpi`, valores de propriedades, ligação dos manipuladores aos métodos, FMX `.fmx` com estilos. |
| D-063 | 2026-10-20 | Aceite | **M9 (parcial):** (1) **Cor no HTML:** `Output.HtmlCode` colore Pascal com as classes do Doxygen (`keyword`, `keywordtype`, `keywordflow`, `comment`, `preprocessor`, `stringliteral`, `charliteral`) nos blocos `\code` e nas palavras-chave das declarações (a pedido do utilizador: `menos monocromático`). (2) **LaTeX** (`GENERATE_LATEX`, `LATEX_OUTPUT`): `Output.LatexGen` escreve `refman.tex` e um capítulo por página, unit, classe e grupo, com membros como subsecções (CodeManager: 197 ficheiros); **não compilado** (sem `pdflatex` na máquina). **Fica por fazer:** SQLite (`GENERATE_SQLITE3`), CHM, traduções (`OUTPUT_LANGUAGE` só inglês), estilo LaTeX do Doxygen, grafos. |
| D-064 | 2026-10-20 | Aceite | **SQLite (`GENERATE_SQLITE3`, `SQLITE3_OUTPUT`):** `Output.SqliteGen` escreve `doxygen_sqlite3.sql` com o esquema do Doxygen (`meta`, `path`, `refid`, `compounddef`, `memberdef`, `member`, `compoundref`, `contains`, `reimplements`, `param`, `memberdef_param`, vistas `def`, `local_file`, `external_file`, `inner_outer`) e os dados; carrega-se com `sqlite3 x.db < doxygen_sqlite3.sql`. **Em vez de gerar o `.db` directamente**: não depende de nenhuma biblioteca SQLite, por isso funciona em Win32/Win64/Linux64. Descrições em texto simples (não XML). Verificado carregando o script do CodeManager no SQLite do Python (196 compostos, 2 736 membros, 2 932 `refid`). **Fora:** `xrefs` (referências), `includes`, `SQLITE3_RECREATE_DB`. |
| D-065 | 2026-10-20 | Aceite | **CHM (`GENERATE_HTMLHELP`):** com a saída HTML, escreve `index.hhp` (opções, janela `main`, todos os ficheiros excepto `search/`), `index.hhc` (índice = a mesma árvore da navegação) e `index.hhk` (classes, units e membros por ordem alfabética); `CHM_FILE` dá o nome. Se `HHC_LOCATION` existir (só Windows) corre o `hhc.exe`; em Linux avisa. Verificado só a geração dos ficheiros (CodeManager); **o `.chm` não foi compilado** (o *HTML Help Workshop* não está instalado). Ficheiros em UTF-8 com `charset` no cabeçalho, `CHM_INDEX_ENCODING`, `GENERATE_CHI`, `BINARY_TOC` e `TOC_EXPAND` ignorados. |
| D-066 | 2026-10-20 | Aceite | **Traduções (`OUTPUT_LANGUAGE`):** `Output.Translator` com o inglês como chave (texto sem tradução sai em inglês) e as línguas **Portuguese, Brazilian, Spanish, French, German** (~110 textos: navegação, páginas, secções, comandos como `\\return`/`\\param`, introduções dos índices, rótulos da pesquisa). Os títulos das secções de membros usam `Nome (visibilidade)` nas línguas não inglesas, para evitar concordâncias de género. Aplica-se só ao HTML (`lang` incluído); XML, LaTeX e SQLite mantêm o inglês. As traduções são minhas e **não foram revistas por falantes nativos**; as outras línguas do Doxygen (cerca de 40) ficam em inglês. |
| D-067 | 2026-10-20 | Aceite | **Grafos de herança:** com `HAVE_DOT = YES` e `CLASS_GRAPH = YES` cada classe com bases ou derivadas ganha um diagrama (antepassados acima, descendentes até 3 níveis abaixo, limite `DOT_GRAPH_MAX_NODES`) gerado por `dot -Tsvg` (`DOT_PATH` ou `dot` no PATH) e embebido como `<object>` com os nós clicáveis; `DOT_CLEANUP` apaga os `.dot`. O ficheiro `.dot` é escrito **sem BOM** (o dot 2.38 rejeita-o). Só SVG (ignora `DOT_IMAGE_FORMAT`), só no Windows (a execução do processo está em `{$IFDEF MSWINDOWS}`, como o CHM) e só o grafo de herança; ver D-068 para os restantes. Verificado com `dot` 2.38 no CodeManager (44 diagramas). | Sem `dot` ou sem HAVE_DOT o HTML sai como antes. |
| D-068 | 2026-10-20 | Aceite | **Grafos de colaboração e de dependências:** `COLLABORATION_GRAPH` (membros variável/propriedade cujo tipo cita uma classe do projecto → aresta tracejada com o nome dos membros; inclui as bases), `INCLUDE_GRAPH` (unidades de `uses` da *interface*; as externas, como `System.*`, saem a cinzento e sem ligação) e `INCLUDED_BY_GRAPH` (unidades que usam esta). Os grafos de unidades só mostram dependências **directas** (o grafo transitivo ficava ilegível já com ~60 nós; `DOT_GRAPH_MAX_NODES` continua a limitar). Mesma execução do `dot` e mesmas limitações de D-067. **Por fazer:** grafos de chamadas (exigem análise dos corpos), de directórios e `GRAPHICAL_HIERARCHY`. | Verificado com `dot` 2.38 no CodeManager: 128 colaboração, 58 `uses`, 64 `used by`. |
| D-069 | 2026-10-21 | Aceite | **LaTeX compilado com MiKTeX (pdflatex):** o `refman.tex` do CodeManager gera um PDF de 428 páginas, sem referências por resolver (3 passagens). Correcções: caracteres que o `pdflatex` não tem (emojis, fora de T1) saem como `?` em `LatexEscape`; blocos de código em `Verbatim` com `fvextra` (`breaklines`); declarações de membros com `\raggedright`; `lmodern` (evita gerar fontes bitmap). Ficam ~200 avisos *overfull hbox* e o aspecto não foi visto (sem `pdftoppm`). Continua sem o estilo do Doxygen (`doxygen.sty`), sem índice remissivo (`makeindex`) e só com `pdflatex` (não `xelatex`). | Verificado com MiKTeX 25.x no Windows. |
| D-070 | 2026-10-21 | Aceite | **Navegador de código-fonte (`SOURCE_BROWSER = YES`):** cada unidade (ficheiro `.pas`/`.dpr`) ganha `<unidade>_source.html` com o texto colorido, números de linha com âncoras `l00001` e os identificadores ligados à sua página (resolução por nome a partir da unidade, com *cache* por palavra); a página da unidade ganha "Go to the source code of this file." e o "Definition at line N of file F" passa a ligar à linha e ao ficheiro. Descodificação UTF-8 (com ou sem BOM), senão ANSI. **Por fazer:** `INLINE_SOURCES` (corpo das rotinas na documentação), `REFERENCED_BY_RELATION`/`REFERENCES_RELATION`, lista de ficheiros nos índices e ficheiros `.inc` ou `.dfm` como páginas de código; ligações só para o que é documentado/ligável. | Verificado no CodeManager: 65 páginas, 673 ligações num só ficheiro; +1 teste (92). |
| D-071 | 2026-10-21 | Aceite | **Grafos de chamadas (`CALL_GRAPH`, `CALLER_GRAPH`, com `HAVE_DOT`):** `Model.Calls` (`TCallIndex`) percorre o corpo das rotinas e liga cada identificador a uma rotina: palavra simples → `Resolve` a partir do âmbito da rotina; `Obj.Nome` → `Obj.Nome` se `Obj` for uma classe do projecto, senão pelo nome quando só há **uma** rotina com esse nome. Sem informação de tipos isto é uma heurística: referências a métodos (p. ex. atribuição a um evento) contam como chamadas, e chamadas por variável cujo método tem nome repetido ficam de fora. O parser só guarda onde o corpo **começa**, por isso o corpo vai até ao início da rotina seguinte no ficheiro (inclui rotinas locais). Os grafos têm 2 níveis (`shortcut`) e aparecem na documentação de cada função. **O `dot` passou a correr em lotes** (`-O`, 25 ficheiros por chamada; `FlushGraphs` no fim): 1778 grafos passaram de 242 s para 22 s. | Verificado no CodeManager: 751 grafos de chamadas, 1027 de quem chama. Sem teste unitário (precisa de um projecto com corpos). |
| D-072 | 2026-10-21 | Aceite | **Directórios e grafo de dependências de directórios (`SHOW_FILES`, `DIRECTORY_GRAPH`):** `Model.Dirs` (`TDirTree`) constrói a árvore de directórios a partir dos ficheiros das unidades (raiz = directório comum a todos, com o seu nome). Gera `dirs.html` (hierarquia, também no menu e na árvore de navegação) e uma página `dir_<md5>.html` por directório com "Directories" e "Files" e, com `HAVE_DOT`, o grafo `dir_..._dep.svg`: o directório, os directórios cujas unidades ele usa e os que o usam, com o número de unidades em cada aresta. Dependência = `uses` (interface ou implementação) entre unidades do projecto. Só mostra vizinhos directos, sem agrupar por directório-pai como o Doxygen. Corrigido de passagem: `FlushGraphs` apagava um `.svg` inexistente (`TFile.Delete` falha se não existe) e rebentava na primeira geração. | Verificado no CodeManager: 6 directórios, 5 grafos; sem teste unitário. |
| D-073 | 2026-10-21 | Aceite | **`INLINE_SOURCES`:** a documentação de cada rotina com corpo mostra o código (`<div class="fragment">`, com a numeração das linhas do ficheiro e os identificadores ligados, como no navegador de código). Para saber onde o corpo **acaba** (o parser só guarda onde começa) `Model.Calls` ganhou `TBodyLocator` e `FindBodyEnd`: percorre os símbolos a partir do início, com uma pilha de blocos (`begin`/`asm`, `try`/`case`, `record`) e conta as rotinas locais (palavra de rotina depois de `;`); comentários e cadeias são ignorados. Sem `end` de fecho (declarações `external`) a rotina fica sem corpo. Os grafos de chamadas passaram a usar o mesmo intervalo exacto. Verificado no CodeManager: 1250 corpos, 1248 acabam em `end;` e os 2 restantes eram `external`/constante, agora excluídos. **Por fazer:** `STRIP_CODE_COMMENTS`, `REFERENCED_BY_RELATION` e `REFERENCES_RELATION`. | +1 teste (93). Cuidado: ficheiros `.pas` do projecto têm BOM; reescrevê-los sem BOM estraga os acentos. |
| D-074 | 2026-10-21 | Aceite | **`REFERENCES_RELATION` / `REFERENCED_BY_RELATION`:** a documentação de cada função, variável, constante e propriedade ganha "References a, b." e "Referenced by x, y." (nomes qualificados com a classe, ordenados, com ligação). O índice de `Model.Calls` passou a guardar todas as referências feitas nos corpos das rotinas (função, variável, constante, propriedade); as chamadas dos grafos são o subconjunto das funções. Para evitar falsos positivos, uma palavra simples que apareça no **cabeçalho** da rotina (parâmetro, variável local, tipo) é ignorada no corpo. Heurística por nome, como em D-071: `Obj.Campo` só conta se `Obj` for classe do projecto ou se o nome for único no projecto. **Não** cobre inicializadores de variáveis/constantes nem referências a partir de variáveis ou propriedades; `REFERENCES_LINK_SOURCE` fica por fazer. | Verificado no CodeManager (167 listas só em `TCMTreeList`); 3 s. |
| D-075 | 2026-10-21 | Aceite | **`STRIP_CODE_COMMENTS` (por omissão SIM, como no Doxygen):** nos fragmentos de código (páginas de código-fonte e `INLINE_SOURCES`) deixam de aparecer os comentários de documentação (`///`, `//!`, `{*`, `{!`, `(**`, `(*!`); as linhas e a numeração mantêm-se, só o texto desaparece. Comentários normais ficam. | +1 teste (94). |
| D-076 | 2026-10-21 | Aceite | **Estilo LaTeX (próprio, ao estilo do Doxygen):** o gerador escreve `doxypas.sty` (cores, `fancyhdr` com cabeçalho/rodapé, `titlesec`, caixa para o protótipo dos membros, lista compacta) em vez de depender de `doxygen.sty`; `refman.tex` tem página de título (nome, versão, `PROJECT_BRIEF`, data), índice, **partes** (Introduction, Topic/Unit/Class Documentation) e **índice remissivo** (`makeidx`, entradas `\index` para unidades, classes e membros). Cada classe/unidade tem "Inherits/Inherited by/Uses", **Member Overview** (tabelas por visibilidade e tipo, com a descrição breve), Detailed Description e Member Documentation. Gera também `make.bat` e `Makefile` (pdflatex + makeindex + 2 passagens). Verificado com MiKTeX: 524 páginas, 2798 linhas de índice, sem referências por resolver; 518 *overfull* e 1309 *underfull* (listas e tabelas). **Não vi o PDF** (sem rasterizador); só em inglês; sem grafos nem logótipo (`PROJECT_LOGO`). | Corrigido: `\\` numa linha vazia da página de título dava erro. |
| D-022 | 2026-10-20 | Aceite (Q-004) | **Identificadores, comentários de código, mensagens de log/CLI base e nomes de ficheiros em inglês**; a documentação do projecto (`docs\`) em português europeu; textos de UI via ficheiros `.lang` (D-010). | Pedido do utilizador. |
| D-006 | 2026-10-20 | Revista → D-035 | **Front-end Pascal escrito à mão** (lexer + pré-processador + parser de contorno que salta corpos), em vez de DelphiAST/Flex. Executar um *spike* de 1–2 dias comparando com DelphiAST (comentários, Delphi 13, FPC, desempenho) antes de confirmar. | Controlo da associação comentário↔declaração e dos dialectos; só se precisam declarações. |
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
| **M2 — Front-end Pascal** | Integração DelphiAST (*vendored* + `PATCHES.md`), adaptador AST → `Entry`, associação comentário↔declaração, defines por plataforma/`PREDEFINED`, `{$I}` | CodeManager 100 % e RAD Studio ≥ 99,4 % sem excepções; `Entry`s correctas nos testes *golden* |
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
| 2026-10-20 | **M9: traduções** (D-066); 91 testes. |
| 2026-10-20 | **M9: grafos de herança** (D-067); 91 testes. |
| 2026-10-20 | **M9: grafos de colaboração e de dependências** (D-068); 91 testes. |
| 2026-10-21 | **M9: LaTeX compila com MiKTeX** (D-069); 91 testes. |
| 2026-10-21 | **M9: navegador de código-fonte** (D-070); 92 testes. |
| 2026-10-21 | **M9: grafos de chamadas** (D-071); 92 testes. |
| 2026-10-21 | **M9: directórios e grafos de directórios** (D-072); 92 testes. |
| 2026-10-21 | **M9: INLINE_SOURCES** (D-073); 93 testes. |
| 2026-10-21 | **M9: relações referenciado por / referencia** (D-074); 93 testes. |
| 2026-10-21 | **M9: STRIP_CODE_COMMENTS** (D-075); 94 testes. |
| 2026-10-21 | **M9: estilo LaTeX** (D-076); 94 testes. |
| 2026-10-20 | **M9: CHM** (D-065). |
| 2026-10-20 | **M9: SQLite** (D-064); 90 testes. |
| 2026-10-20 | **M9 parcial (cor no HTML, LaTeX):** D-063; 89 testes. |
| 2026-10-20 | **M8 (extras Delphi) implementado:** D-062; 87 testes verdes. |
| 2026-10-20 | **M7 (GUI) implementado, por testar de ponta a ponta:** D-061. |
| 2026-10-20 | **M6 (HTML) implementado, falta verificação visual:** D-059, D-060. |
| 2026-10-20 | **M5 concluído:** `Output.XmlWriter/XmlDoc/XmlGen/TagFile`, `Model.Links`, `Resources.Xml`, `tools\PackResources` (D-053…D-058); `doxypas Doxyfile` gera XML e *tag file*. 81 testes DUnitX verdes (Win32/Win64; XML *golden* em `tests\golden\xml`); XML idêntico em Linux64; **todo o XML validado contra `compound.xsd`/`index.xsd`** (CodeManager 197 ficheiros em 2,7 s; amostra de `vcl`). |
| 2026-10-20 | **M4 concluído:** `Model.Defs/Project/ProjectDump`, `Build.Passes/Pipeline` (D-047…D-052); `doxypas --model`. 73 testes DUnitX verdes (Win32/Win64, incl. *golden* em `tests\golden\model`: herança/interfaces/*override*, junção declaração↔implementação, `\copydoc/\inheritdoc`, grupos/páginas, avisos); modelo idêntico em Linux64 e em modo paralelo/sequencial. CodeManager (113 ficheiros) em 1,3 s; `rtl` do RAD Studio em 45 s e `vcl` em 5,7 s (modelo completo + avisos). Pendente: agrupamento por `@{ … @}`, `\xrefitem` (listas todo/bug/deprecated), *call/caller* e referências de código-fonte, ficheiros `.dproj` para *search paths* (M8), docs em `.inc`. |
| 2026-10-20 | **M3 concluído:** `Doc.Nodes/Parser/Markdown/Dump`, `Comments.XmlDoc/Scanner/EntryDocs`, blocos `\page/\defgroup/\file` (D-042…D-046); `doxypas --doc <ficheiro>` e `--parse … --docs`. 62 testes DUnitX verdes (Win32/Win64; *golden* em `tests\golden\docs`); saída idêntica em Linux64. Validação com **415 313 comentários reais** do código do RAD Studio (todos tratados como texto de documentação): 0 excepções, 1 comentário > 200 ms, 635 avisos (só `\deffunc/\defvar` de documentação Macapi). Pendente (M4+): resolução de `\ref/\copydoc/\inheritdoc`, listas `\todo/\bug/\deprecated` (xrefitem), validação de `\param`, fórmulas/diagramas, `\include/\snippet`, `\cite`; comentários simples `{ }` como documentação (estilo PasDoc) por decidir. |
| 2026-10-20 | **M2 concluído:** DelphiAST integrado (D-035/D-040) + `Entry` + `Source` + `DocBlocks` + `Parser` + `Options` (D-036…D-041). Resultados: CodeManager 113/113 ficheiros, módulos Boss 198/198, fonte RAD Studio 13 **2 524/2 539 (99,4 %)** em 30 s; 36 testes DUnitX verdes (Win32/Win64, incl. *golden* em `tests\golden\pascal`); saída idêntica em Linux64 (WSL). Pendente: FPC (≈95 %, sem *patches*), docs em `.inc`, XMLDoc/comandos (M3), resolução `unit.Classe.Método` da implementação (M4). |
| 2026-10-20 | **Spike DelphiAST concluído:** adoptado como parser (D-035, substitui D-006). Resultados em §6.2.1; harness em `tools\spikes\delphiast`. |
| 2026-10-20 | **M1 concluído:** GenConfig + Config (Options/Config/Reader/Writer) + CLI (`-g -s -u -x`); 19 testes DUnitX verdes em Win32/Win64; binário Linux64 verificado em WSL. Decisões D-032…D-034. |
| 2026-10-20 | **M0 concluído:** `doxypas --version` → `0.1.0` em Win32, Win64 e Linux64 (testado em WSL); 3 testes DUnitX verdes em Win32/Win64. Unidades: `Core.Version`, `Core.Log`. Decisões D-029…D-031. Pendente do M0: threading utilitário, `LinkedMap` e `Strings` ficam para quando o M1/M2 os exigirem; CI não configurado. |
| 2026-10-20 | Q-006 resolvida: Delphi 10+ (D-027), CodeManager como referência (D-028). Todas as questões Q-001…Q-008 fechadas. |
| 2026-10-20 | Q-007, Q-008 resolvidas (D-025, D-026); Q-006 parcial (D-024); roadmap: GUI = M7. |
| 2026-10-20 | Q-005 resolvida: repositório GitHub (D-023). |
| 2026-10-20 | Respostas a Q-001…Q-004: D-018 e D-005 aceites/actualizadas; novas D-021, D-022. |
| 2026-10-20 | Criação. Análise do Doxygen 1.19.0, estrutura de pastas, avaliação de bibliotecas, decisões D-001…D-020, roadmap e questões em aberto. |
