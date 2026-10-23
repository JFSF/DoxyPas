# DoxyPas — Guia do utilizador

[English](../en/USER_GUIDE.md) · [Referência das opções](OPCOES.md) · [README](../../README.md)

O DoxyPas escreve a documentação de programas em **Object Pascal** (Delphi, Free Pascal, Lazarus) a partir dos ficheiros
fonte e dos comentários que eles têm. É escrito em Delphi, funciona como o [Doxygen](https://github.com/doxygen/doxygen)
(o mesmo Doxyfile, os mesmos comandos nos comentários, o mesmo aspeto) e percebe Pascal: units, classes, records,
interfaces, helpers, genéricos, rotinas, propriedades, enumerações e os formulários (`.dfm`, `.fmx`).

![Como o DoxyPas funciona](../images/pipeline.png)

*Entram o Doxyfile (as opções) e os fontes; os comentários são lidos, ligados às declarações num modelo do programa, e
escritos como HTML, LaTeX/PDF, XML, SQLite, ficheiro de etiquetas ou CHM. Os grafos são desenhados pelo `dot` do Graphviz.*

## Índice

1. [Início rápido](#1-início-rápido)
2. [Linha de comandos](#2-linha-de-comandos)
3. [O Doxyfile](#3-o-doxyfile)
4. [Escrever os comentários](#4-escrever-os-comentários)
5. [A saída HTML, página a página](#5-a-saída-html-página-a-página)
6. [Grafos](#6-grafos)
7. [Formulários, projetos e compilação condicional](#7-formulários-projetos-e-compilação-condicional)
8. [As outras saídas](#8-as-outras-saídas)
9. [A interface gráfica](#9-a-interface-gráfica)
10. [Receitas](#10-receitas)
11. [Problemas](#11-problemas)
12. [Compilar o projeto e refazer as imagens](#12-compilar-o-projeto-e-refazer-as-imagens)

## 1. Início rápido

Precisa do `DoxyPas.exe` (ver [compilar](#12-compilar-o-projeto-e-refazer-as-imagens)) e, para ter os grafos, do
[Graphviz](https://graphviz.org/) (`dot`) no `PATH`.

```
doxypas -g Doxyfile        # escreve um Doxyfile com todas as opções e a sua documentação
                           # edite-o: pelo menos PROJECT_NAME, INPUT, RECURSIVE
doxypas Doxyfile           # escreve a documentação
```

A pasta [`docs/example`](../example) é um pequeno projeto com o seu Doxyfile; todas as imagens deste guia foram feitas a
partir dele:

```
cd docs\example
doxypas Doxyfile           # escreve docs\example\out\html\index.html
```

O Doxyfile do exemplo é curto, porque as opções que não estão escritas têm o valor por omissão (ver a
[referência](OPCOES.md)):

```
PROJECT_NAME      = "Geometry"
PROJECT_NUMBER    = 1.0
PROJECT_BRIEF     = "Shapes and measures"
INPUT             = src
USE_MDFILE_AS_MAINPAGE = README.md
OUTPUT_DIRECTORY  = out
GENERATE_LATEX    = NO
HAVE_DOT          = YES
SOURCE_BROWSER    = YES
```

O resultado, aberto num navegador (`out\html\index.html`):

![A página principal](../images/main.png)

O título e a descrição de uma linha vêm de `PROJECT_NAME`, `PROJECT_NUMBER` e `PROJECT_BRIEF`; o texto da página é o
`README.md` (`USE_MDFILE_AS_MAINPAGE`).

## 2. Linha de comandos

| Comando | O que faz |
|---|---|
| `doxypas [Doxyfile]` | Lê a configuração (por omissão `Doxyfile`) e escreve a documentação. |
| `doxypas -g [Doxyfile]` | Escreve um Doxyfile com todas as opções e um comentário que explica cada uma. `-` escreve no ecrã. |
| `doxypas -s -g [Doxyfile]` | O mesmo, sem os comentários. |
| `doxypas -u [Doxyfile]` | Atualiza um Doxyfile antigo para esta versão (acrescenta as opções novas, retira as obsoletas). `-s` retira também os comentários. |
| `doxypas -x [Doxyfile]` | Mostra só as opções que são diferentes do valor por omissão. |
| `doxypas -l [Layout.xml]` | Escreve o ficheiro de disposição (por omissão `DoxygenLayout.xml`) que pode editar e indicar em `LAYOUT_FILE`. |
| `doxypas -v` / `-h` | Versão / ajuda. |

Comandos para quem desenvolve o DoxyPas: `--parse <caminho>` (mostra o que o analisador leu), `--model <caminho>` (mostra o
modelo) e `--doc <ficheiro>` (corre o analisador de Markdown e de comentários sobre um ficheiro de texto).

O código de saída é diferente de zero se a execução falhou; com `WARN_AS_ERROR = FAIL_ON_WARNINGS` também o é quando houve
avisos, o que é o que uma compilação de integração contínua quer.

## 3. O Doxyfile

Um Doxyfile é um ficheiro de texto com linhas `OPÇÃO = valor`:

```
# um comentário
PROJECT_NAME  = "A Minha Biblioteca"  # um valor com espaços precisa de aspas
RECURSIVE     = YES                   # YES / NO
INPUT         = src tests\helpers     # uma lista: valores separados por espaços
EXCLUDE      += src\old               # += acrescenta a uma lista
OUTPUT_DIRECTORY = $(DOCS_DIR)        # variáveis de ambiente
@INCLUDE      = comum.cfg             # outro ficheiro
```

* Os nomes distinguem maiúsculas e escrevem-se em maiúsculas. Se uma opção estiver escrita duas vezes, vale a última.
* Uma linha comprida pode continuar com `\` no fim.
* Há **221 opções**, em 14 grupos. A [referência](OPCOES.md) explica cada uma:

![Opções por grupo](../images/options_by_group.svg)

![Os grupos do Doxyfile](../images/structure.png)

As primeiras opções a mudar num projeto novo:

| Opção | Para quê |
|---|---|
| `PROJECT_NAME`, `PROJECT_NUMBER`, `PROJECT_BRIEF`, `PROJECT_LOGO` | Identificar a documentação. |
| `INPUT`, `RECURSIVE`, `FILE_PATTERNS`, `EXCLUDE_PATTERNS` | Que ficheiros. |
| `DELPHI_PROJECT` | Tirar os ficheiros e os símbolos de um `.dproj` / `.lpi`. |
| `EXTRACT_ALL` | Documentar também o que não tem comentário (primeira execução num projeto antigo). |
| `EXTRACT_PRIVATE`, `EXTRACT_STATIC` | Incluir os membros privados e a secção `implementation`. |
| `HAVE_DOT` | Desenhar os grafos. |
| `SOURCE_BROWSER` | Acrescentar a listagem dos fontes. |
| `OUTPUT_LANGUAGE`, `GENERATE_LATEX`, `GENERATE_XML` | Idioma e formatos. |

## 4. Escrever os comentários

O DoxyPas lê os comentários que começam de uma forma especial ("comentários de documentação") e liga cada um à declaração que
**vem a seguir** (ou que vem **antes**, com `<`).

| Estilo | Exemplo |
|---|---|
| Linha | `/// Descrição breve.` (várias linhas seguidas são um só comentário) |
| Bloco (Javadoc) | `{** Breve. Mais texto. }` ou `(** ... *)` |
| Depois da declaração | `FName: string; //!< o nome` ou `{!< o nome }` |
| XMLDoc (Delphi) | `/// <summary>Breve.</summary>` — com `PASCAL_XMLDOC = YES`, o valor por omissão |

A primeira frase é a descrição *breve* (aparece nas listas); o resto é a descrição *detalhada*. O texto pode usar Markdown
(`**negrito**`, listas, `` `código` ``, tabelas), HTML e os comandos do Doxygen que começam por `\` ou `@`.

A unit do exemplo, [`Shapes.pas`](../example/src/Shapes.pas):

```pascal
{** \file Shapes.pas
    Base types of the geometry library: the shape hierarchy and the drawing interface. }
unit Shapes;

{** \defgroup geometry Geometry
    Shapes and measures. }

interface
type
  /// Something that can paint itself.
  IDrawable = interface
    ['{6F1B3C52-8A0E-4C57-9D55-3B7B0C2D1A10}']
    /// Paints the object on the canvas.
    /// \param ACanvasName name of the canvas to paint on
    procedure Draw(const ACanvasName: string);
  end;

  /// <summary>Base class of all shapes.</summary>
  /// <remarks>Descendants override <see cref="Area"/> and <see cref="Perimeter"/>.</remarks>
  /// \ingroup geometry
  TShape = class(TInterfacedObject, IDrawable)
  public
    /// Creates a shape with a name.
    /// \param AName the name shown in the lists
    constructor Create(const AName: string);
    /// Area of the shape.
    /// \return the area in square units
    function Area: Double; virtual; abstract;
    /// The name of the shape.
    property Name: string read FName write FName;
  end;
```

Os comandos mais usados:

| Comando | Significado |
|---|---|
| `\brief texto` | A descrição breve (não é preciso quando a primeira frase é a breve: `JAVADOC_AUTOBRIEF`). |
| `\param Nome texto` | Descreve um parâmetro. `\param[in]`, `[out]`, `[in,out]` indicam a direção. |
| `\return texto` | Descreve o resultado de uma função. |
| `\sa Nome`, `\ref Nome` | "Ver também" e uma ligação para outra entidade ou página. |
| `\see`, `\note`, `\warning`, `\remark`, `\attention` | Parágrafos realçados. |
| `\todo`, `\bug`, `\test`, `\deprecated` | Acrescentam o item às páginas de listas de todo o projeto. |
| `\defgroup id Título`, `\ingroup id`, `\addtogroup` | Grupos ("Tópicos" no menu). |
| `\mainpage`, `\page id Título`, `\section`, `\subsection` | Páginas livres e as suas secções. |
| `\copydoc Nome`, `\copybrief`, `\copydetails`, `\inheritdoc` | Reutilizam a documentação de outra entidade. |
| `\code ... \endcode`, `\snippet`, `\include` | Código no texto (ou de um ficheiro de `EXAMPLE_PATH`). |
| `\image html ficheiro.png "legenda"` | Uma imagem (procurada em `IMAGE_PATH`). |
| `\dot ... \enddot` | Um grafo escrito no comentário (precisa do `dot`). |
| `\if etiqueta ... \endif`, `\cond` | Partes condicionais (`ENABLED_SECTIONS`). |
| `\cite chave` | Uma referência de um ficheiro `.bib` (`CITE_BIB_FILES`). |

A lista completa dos comandos é a do Doxygen; os que o DoxyPas não conhece aparecem como texto e dão um aviso. Os seus
próprios comandos fazem-se com `ALIASES`.

Um elemento documentado ganha, a partir da unit acima, esta página:

![A página de uma classe](../images/class.png)

A descrição breve está nas listas do topo, a detalhada e os `\param` / `\return` mais abaixo. As secções de visibilidade
usam as palavras do Pascal (*Public Methods*, *Protected Methods*, *Properties*...) e o painel da direita é o esquema da
página.

### O que não está documentado

Com os valores por omissão, um elemento sem comentário aparece nas listas mas não tem secção detalhada, e
`WARN_IF_UNDOCUMENTED = YES` dá-lhe um aviso:

```
src\Shapes.pas:30: warning: field Shapes.TShape.FName is not documented.
```

Use `HIDE_UNDOC_MEMBERS`, `HIDE_UNDOC_CLASSES` para os esconder, ou `EXTRACT_ALL = YES` para os aceitar. Os membros privados
não aparecem, a menos que `EXTRACT_PRIVATE = YES`:

![EXTRACT_PRIVATE = YES](../images/private.png)

## 5. A saída HTML, página a página

Abra o `index.html`. As páginas são:

| Página | Conteúdo |
|---|---|
| Main Page | O `\mainpage`, ou o ficheiro Markdown de `USE_MDFILE_AS_MAINPAGE`. |
| Related Pages | As páginas `\page`, as listas de todo / erros / obsoletos, a legenda dos grafos. |
| Topics | Os grupos (`\defgroup`). |
| Units | As units com as suas classes, tipos, constantes e rotinas; o "Uses" e o grafo de dependências. |
| Classes | A lista de classes, o **índice de classes** (alfabético, `ALPHABETICAL_INDEX`), a **hierarquia** e todos os membros. |
| Files | Os ficheiros e as pastas (*Directory Hierarchy*), com o grafo das pastas. |
| Forms | Uma página por cada `.dfm` / `.fmx`, com a árvore de componentes. |

(Os nomes das páginas aparecem traduzidos com `OUTPUT_LANGUAGE`.)

Uma unit, com o seu grafo de dependências, constantes e rotinas:

![A página de uma unit](../images/unit.png)

A hierarquia de classes (uma interface no topo, as classes por baixo):

![A hierarquia de classes](../images/hierarchy.png)

Com `SOURCE_BROWSER = YES` cada unit tem uma página de código; os nomes são ligações para a documentação e podem ser
dobrados (`HTML_CODE_FOLDING`):

![A página de código](../images/source.png)

`INLINE_SOURCES = YES` mostra o corpo de cada rotina na sua documentação:

![INLINE_SOURCES = YES](../images/inline.png)

A caixa de pesquisa (`SEARCHENGINE`) funciona no navegador, sem servidor. O painel da esquerda é `GENERATE_TREEVIEW`; o da
direita é `PAGE_OUTLINE_PANEL`.

### O aspeto

* **Cores:** `HTML_COLORSTYLE` (`LIGHT`, `DARK`, `AUTO_LIGHT`, `AUTO_DARK`, `TOGGLE`) e `HTML_COLORSTYLE_HUE`.

  ![HTML_COLORSTYLE = DARK](../images/dark.png)

  ![HTML_COLORSTYLE_HUE = 20](../images/hue.png)

* **Disposição:** `FULL_SIDEBAR`, `GENERATE_TREEVIEW`, `DISABLE_INDEX`, `LAYOUT_FILE`.

  ![FULL_SIDEBAR = YES](../images/sidebar.png)

  ![GENERATE_TREEVIEW = NO](../images/notree.png)

* **Os seus ficheiros:** `HTML_HEADER`, `HTML_FOOTER`, `HTML_EXTRA_STYLESHEET`, `HTML_EXTRA_FILES`. Comece por
  `resources\html\header.html` e `footer.html`.
* **Idioma dos textos fixos:** `OUTPUT_LANGUAGE`.

  ![OUTPUT_LANGUAGE = Portuguese](../images/pt.png)

## 6. Grafos

Com `HAVE_DOT = YES` (e o Graphviz instalado, ou `DOT_PATH` definido) o DoxyPas desenha:

| Grafo | Opção | Onde |
|---|---|---|
| Herança (antepassados e descendentes) | `CLASS_GRAPH` | Página da classe. |
| Colaboração (a que se refere a classe) | `COLLABORATION_GRAPH` | Página da classe. |
| `uses` de uma unit / units que a usam | `INCLUDE_GRAPH` / `INCLUDED_BY_GRAPH` | Página da unit. |
| Chamadas de uma rotina / quem a chama | `CALL_GRAPH` / `CALLER_GRAPH` | Página da unit ou da classe (desligado: é lento). |
| Dependências entre pastas | `DIRECTORY_GRAPH`, `DIR_GRAPH_MAX_DEPTH` | Página da pasta. |
| Dependências entre grupos | `GROUP_GRAPHS` | Página do grupo. |
| Hierarquia de todas as classes | `GRAPHICAL_HIERARCHY` | "Graphical class hierarchy". |

A imagem por omissão é SVG: mantém-se nítida ao ampliar e **as caixas são ligações**. `INTERACTIVE_SVG = YES` acrescenta
ampliar e mover com o rato. `DOT_IMAGE_FORMAT = png` faz bitmaps sem ligações.

Os grafos de classe de `TShape` (os da imagem da página da classe acima) mostram os antepassados em cima e os
descendentes em baixo. O mesmo com `UML_LOOK = YES` e `DOT_UML_DETAILS = YES`:

![Aspeto UML](../images/uml.png)

Sem `dot` (`HAVE_DOT = NO`) o diagrama de herança continua a ser desenhado pelo próprio DoxyPas, mas os outros grafos não:

![HAVE_DOT = NO](../images/nodot.png)

O grafo das rotinas que `TRectangle.Bounding` chama (`CALL_GRAPH`) e o de quem chama `TCircle.Create` (`CALLER_GRAPH`):

![Grafo de chamadas](../images/callgraph.png) ![Grafo de quem chama](../images/callergraph.png)

Para tornar mais pequenos os grafos grandes use `DOT_GRAPH_MAX_NODES`, `MAX_DOT_GRAPH_DEPTH` e `HIDE_UNDOC_RELATIONS`. Para
mudar os tipos de letra, cores e formas use `DOT_COMMON_ATTR`, `DOT_NODE_ATTR` e `DOT_EDGE_ATTR`.

Pode também desenhar um grafo seu num comentário:

```pascal
/// \dot
///   digraph G { Client -> Server -> Database }
/// \enddot
```

## 7. Formulários, projetos e compilação condicional

**Formulários.** Com `PASCAL_PARSE_DFM = YES` cada `.dfm` / `.fmx` (texto ou binário) torna-se uma página com a árvore de
componentes (classe, nome, título) e os tratadores de eventos (`OnClick = ButtonAreaClick`). Com
`PASCAL_DFM_PROPERTIES = YES` lista também os valores das propriedades.

**Projetos.** `DELPHI_PROJECT = MinhaApp.dproj` tira os ficheiros, os caminhos de pesquisa e os símbolos condicionais do
projeto (`.dpr`, `.dpk`, `.dproj`, `.groupproj`, e os `.lpi`, `.lpk` do Lazarus). Podem indicar-se vários.

**Compilação condicional.** O código entre `{$IFDEF}` / `{$ENDIF}` é o que o compilador veria:

| Opção | Papel |
|---|---|
| `PASCAL_DIALECT` | `Delphi` ou `FPC`: define `DELPHI` ou `FPC`, e o modo da linguagem. |
| `PASCAL_PLATFORM` | `Win32`, `Win64`, `Linux64`, `macOS`, `iOS`, `Android`: define `MSWINDOWS`, `LINUX`, `CPUX64`... |
| `PREDEFINED` | Os seus próprios símbolos (`DEBUG USE_SSL`). |
| `INCLUDE_PATH` | Onde se procura `{$I ficheiro.inc}`. |
| `PASCAL_UNIT_SCOPES` | Os nomes de âmbito de unit, para que `Classes` seja encontrada como `System.Classes`. |

Para documentar a versão Linux de uma biblioteca: `PASCAL_PLATFORM = Linux64`.

**Codificações.** Os fontes antigos do Delphi estão em ANSI. O DoxyPas lê um ficheiro que não é UTF-8 válido na página de
código ANSI do sistema; para outros casos use `INPUT_ENCODING` ou `INPUT_FILE_ENCODING = *.pas=windows-1250`.

## 8. As outras saídas

| Saída | Opção | Resultado |
|---|---|---|
| HTML | `GENERATE_HTML` (omissão) | `html\index.html` |
| LaTeX / PDF | `GENERATE_LATEX` | `latex\refman.tex`, `Makefile`, `make.bat`. Nessa pasta corra `make.bat` (ou `pdflatex refman` duas vezes, mais `makeindex`) com uma instalação de LaTeX (MiKTeX, TeX Live). |
| XML | `GENERATE_XML` | `xml\index.xml` e um ficheiro por unit, classe e página, com os esquemas `.xsd`; `XML_PROGRAMLISTING` acrescenta o código. Para as suas ferramentas. |
| SQLite | `GENERATE_SQLITE3` | `sqlite3\doxygen_sqlite3.sql`: um script que cria as tabelas; carregue-o com o programa `sqlite3` e consulte os símbolos com SQL. |
| Ficheiro de etiquetas | `GENERATE_TAGFILE = nome.tag` | A lista dos símbolos, para que outro projeto ligue a este com `TAGFILES = nome.tag=../caminho/html`. |
| CHM | `GENERATE_HTMLHELP`, `CHM_FILE`, `HHC_LOCATION` | Os ficheiros de projeto do HTML Help; com `HHC_LOCATION` o compilador é executado. Desligue `SEARCHENGINE`. |

## 9. A interface gráfica

O `DoxyPasGui.exe` (Windows) edita um Doxyfile sem o escrever à mão:

![DoxyPasGui](../images/gui.png)

* **À esquerda:** os grupos de opções. Um ponto azul marca um grupo que tem opções diferentes do valor por omissão.
* **Ao centro:** as opções do grupo. O nome e a descrição estão à esquerda; o valor é um interruptor (YES/NO), uma lista de
  escolhas, um número ou um texto, com um botão `...` para escolher um ficheiro ou uma pasta. Pare o rato sobre um nome
  para ver a explicação completa.
* **Search the options** (em cima à direita): pesquisa nos nomes e descrições de todas as opções.
* **Open...** / **Save as...:** o Doxyfile. O título mostra `*` quando há alterações por guardar.
* **Run:** executa o `DoxyPas.exe` (tem de estar na mesma pasta) com o ficheiro e mostra as mensagens em **Output**; o
  botão passa a **Stop** enquanto corre. **Open output** abre o resultado no navegador.
* **Dark / Light:** o tema da janela.

`DoxyPasGui.exe Doxyfile /run` abre o ficheiro e executa-o logo.

## 10. Receitas

**Um projeto antigo sem documentação.** Obter um primeiro resultado e a lista do que falta:

```
EXTRACT_ALL     = YES
RECURSIVE       = YES
SOURCE_BROWSER  = YES
HAVE_DOT        = YES
```

**Uma biblioteca para publicar.** Só o que é público, com avisos que fazem falhar a compilação:

```
EXTRACT_ALL           = NO
HIDE_UNDOC_MEMBERS    = YES
WARN_IF_UNDOCUMENTED  = YES
WARN_AS_ERROR         = FAIL_ON_WARNINGS
HTML_COLORSTYLE       = TOGGLE
SITEMAP_URL           = https://example.com/mylib/
```

**Documentação para quem mantém o código.** Tudo, com o código e os grafos de chamadas:

```
EXTRACT_ALL           = YES
EXTRACT_PRIVATE       = YES
EXTRACT_STATIC        = YES
INTERNAL_DOCS         = YES
SOURCE_BROWSER        = YES
REFERENCES_RELATION   = YES
REFERENCED_BY_RELATION = YES
CALL_GRAPH            = YES
CALLER_GRAPH          = YES
```

**Execuções mais rápidas num projeto grande.** `CALL_GRAPH = NO`, `DOT_GRAPH_MAX_NODES = 30`, `MAX_DOT_GRAPH_DEPTH = 2`,
`SOURCE_TOOLTIPS = NO`, `CREATE_SUBDIRS = YES`, `NUM_PROC_THREADS = 0`, `DOT_NUM_THREADS = 0`.

**Ligar dois projetos.** Na biblioteca: `GENERATE_TAGFILE = lib.tag`. Na aplicação:
`TAGFILES = ..\lib\lib.tag=..\..\lib\html`.

**Um PDF.** `GENERATE_LATEX = YES`, `GENERATE_HTML = NO`, `PAPER_TYPE = a4`, depois execute `make.bat` em `latex\`.

## 11. Problemas

| Sintoma | Causa e solução |
|---|---|
| Sem grafos, só o diagrama de herança | `HAVE_DOT = NO`, ou o `dot` não é encontrado: instale o Graphviz e ponha-o no `PATH`, ou defina `DOT_PATH`. |
| `warning: ... is not documented` em tudo | Normal sem comentários. Use `EXTRACT_ALL = YES` ou `WARN_IF_UNDOCUMENTED = NO`. |
| Um ficheiro não é lido | A extensão não está em `FILE_PATTERNS`, está em `EXCLUDE` / `EXCLUDE_PATTERNS`, ou `RECURSIVE = NO` e está numa subpasta. |
| `error: 'SemiColon' expected` num ficheiro | O ficheiro não é Pascal (um `.md` em `INPUT`: use `USE_MDFILE_AS_MAINPAGE`) ou os símbolos condicionais estão errados: defina `PASCAL_PLATFORM`, `PREDEFINED`, `DELPHI_PROJECT`. |
| Os acentos saem errados | O ficheiro não está na codificação esperada: defina `INPUT_ENCODING`. |
| Um `{$I ficheiro.inc}` não é encontrado | Acrescente a sua pasta a `INCLUDE_PATH`. |
| A classe de outra unit não é uma ligação | A unit não está em `INPUT`; use `TAGFILES` se está documentada noutro sítio. |
| Uma opção não tem efeito | Verifique a ortografia (as maiúsculas contam) e `doxypas -x Doxyfile`: lista o que o ficheiro define. Uma linha com uma opção desconhecida dá um aviso. |

## 12. Compilar o projeto e refazer as imagens

Delphi 13 (RAD Studio 37.0):

```
build.bat            # DoxyPas para Win32, Win64, Linux64 e a GUI para Win32, Win64
build.bat test       # compila e corre os testes DUnitX
build.bat gen        # regenera as opções e os recursos
```

O `build.bat` usa o `BDS` de uma linha de comandos do RAD Studio ou, se não estiver definido, `DELPHI_VER` (omissão `37.0`). Para
trabalhar no IDE abra o `DoxyPas.groupproj` (a ferramenta de linha de comandos, a GUI e os testes). Os estilos VCL da GUI não
estão no repositório: a compilação copia-os da instalação do RAD Studio (`src\Gui\prebuild.bat`).

A documentação desta pasta é feita por três programas, para poder ser refeita depois de uma alteração:

```
python tools\docs\gen_options.py              # docs\en\OPTIONS.md, docs\pt\OPCOES.md e os gráficos de barras
powershell tools\docs\make_images.ps1         # as capturas do HTML (precisa do Chrome e do Graphviz)
powershell tools\docs\shot_gui.ps1            # a captura da GUI
```

O `gen_options.py` pára se uma opção do Doxyfile não tem texto em `tools\docs\options_text.py` (ou ao contrário): uma
opção nova não pode ser esquecida. Os diagramas `docs\images\pipeline.png` e `structure.png` são feitos a partir dos
ficheiros `.dot` que estão ao lado (`dot -Tpng -Gdpi=110 pipeline.dot -o pipeline.png`).
