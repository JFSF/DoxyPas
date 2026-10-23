# DoxyPas — Referência das opções

[English](../en/OPTIONS.md) · [Guia do utilizador](GUIA_DO_UTILIZADOR.md) · [README](../../README.md)

O Doxyfile do DoxyPas tem **221 opções**, todas implementadas. Esta página explica cada uma. Para gerar um Doxyfile com todas e a sua documentação: `doxypas -g Doxyfile`; para ver só as que mudou: `doxypas -x Doxyfile`. Os valores por omissão abaixo são os do `doxypas -g`.

![Opções por grupo](../images/options_by_group.svg)

Cada linha do Doxyfile é `OPÇÃO = valor`. As opções do tipo *lista* aceitam vários valores separados por espaços (ou `+=` para acrescentar) e as do tipo *YES/NO* aceitam `YES` ou `NO`. Um `#` começa um comentário.

## Índice

* [Projeto](#projeto) (36)
* [Construção](#construção) (32)
* [Mensagens](#mensagens) (12)
* [Entrada](#entrada) (19)
* [Navegador de código](#navegador-de-código) (7)
* [Índice](#índice) (2)
* [Saída HTML](#saída-html) (45)
* [Saída LaTeX](#saída-latex) (17)
* [Saída XML](#saída-xml) (3)
* [Saída SQLite](#saída-sqlite) (2)
* [Pré-processador](#pré-processador) (2)
* [Documentação externa](#documentação-externa) (5)
* [Grafos (Graphviz dot)](#grafos-graphviz-dot) (32)
* [Object Pascal](#object-pascal) (7)

## Projeto

Nome, pasta de saída, idioma e o estilo geral dos comentários.

| Opção | Tipo | Omissão | O que faz |
|---|---|---|---|
| `DOXYFILE_ENCODING` | texto | `UTF-8` | Codificação do próprio Doxyfile, para o texto que vem a seguir a esta linha. O texto anterior é sempre UTF-8. |
| `PROJECT_NAME` | texto | `"My Project"` | Nome do projeto. É o título das páginas e do livro LaTeX. Use aspas se tiver espaços. |
| `PROJECT_NUMBER` | texto | — | Número de versão ou revisão, mostrado ao lado do nome. Útil para distinguir documentações arquivadas. |
| `PROJECT_BRIEF` | texto | — | Descrição de uma linha, mostrada por baixo do nome do projeto no topo de cada página. Mantenha-a curta. |
| `PROJECT_LOGO` | texto | — | Imagem mostrada no cabeçalho (no máximo 55 pixels de altura e 200 de largura). É copiada para a pasta de saída. |
| `PROJECT_ICON` | texto | — | Ícone do separador do navegador nas páginas HTML (favicon). É copiado para a pasta de saída. |
| `OUTPUT_DIRECTORY` | texto | — | Pasta onde tudo é escrito; cada formato vai para a sua subpasta (`html`, `latex`, `xml`, ...). Um caminho relativo é relativo a onde o DoxyPas é iniciado. Vazio significa a pasta atual. |
| `CREATE_SUBDIRS` | YES/NO | `NO` | Distribui os ficheiros gerados por até 4096 subpastas (`d0/d00/`...). Só para projetos enormes, quando uma pasta com dezenas de milhares de ficheiros torna o sistema de ficheiros lento. |
| `CREATE_SUBDIRS_LEVEL` | número | `8` | Quantas subpastas são criadas com `CREATE_SUBDIRS = YES`: o nível 0 são 16 pastas e cada nível duplica (8, o máximo, são 4096). |
| `ALLOW_UNICODE_NAMES` | YES/NO | `NO` | YES mantém as letras não ASCII nos nomes dos ficheiros gerados; NO escapa-as (`_xE3_x81_x84`). |
| `OUTPUT_LANGUAGE` | escolha | `English` | Idioma dos textos fixos das páginas ("Métodos públicos", "Referência da classe", ...). O DoxyPas tem tradução para inglês, português, brasileiro, espanhol, francês, alemão, italiano, holandês, polaco, russo, chinês e japonês; os textos que não estão traduzidos ficam em inglês. Valores: `Afrikaans`, `Arabic`, `Armenian`, `Brazilian`, `Bulgarian`, `Catalan` …. |
| `BRIEF_MEMBER_DESC` | YES/NO | `YES` | YES mostra a descrição breve de cada membro nas listas de membros (como no Javadoc). NO mostra só os nomes. |
| `REPEAT_BRIEF` | YES/NO | `YES` | YES coloca a descrição breve à frente da detalhada na documentação do membro. |
| `ABBREVIATE_BRIEF` | lista | `"The $name class" "The $name widget" "The $name file" …` | Frases que são removidas do início de uma descrição breve nas listas, para que "The TFoo class implements X" apareça como "implements X". `$name` representa o nome da entidade. |
| `ALWAYS_DETAILED_SEC` | YES/NO | `NO` | Com `REPEAT_BRIEF = YES`, cria também a secção "Descrição detalhada" quando só existe a descrição breve. |
| `INLINE_INHERITED_MEMB` | YES/NO | `NO` | Mostra os membros herdados na página de cada classe como se fossem seus, em vez da ligação "Lista de todos os membros". |
| `FULL_PATH_NAMES` | YES/NO | `YES` | YES escreve o caminho completo de um ficheiro nas listas; NO escreve o caminho mais curto que ainda seja único. |
| `STRIP_FROM_PATH` | lista | — | Caminhos que são cortados do início dos nomes de ficheiro mostrados nas listas (`STRIP_FROM_PATH = C:\src\` mostra `Core\Utils.pas`). Vazio significa a pasta onde o DoxyPas é executado. |
| `JAVADOC_AUTOBRIEF` | YES/NO | `YES` | A primeira frase (até ao primeiro ponto) de um comentário `{** ... }` ou `/** ... */` é a descrição breve; com NO é preciso `\brief`. |
| `JAVADOC_BANNER` | YES/NO | `NO` | YES trata uma linha como `{*****...` como o início de um comentário estilo Javadoc (um "banner"); NO deixa-a como comentário normal. |
| `QT_AUTOBRIEF` | YES/NO | `NO` | Igual a `JAVADOC_AUTOBRIEF`, para os comentários de estilo Qt (`//!`). |
| `INHERIT_DOCS` | YES/NO | `YES` | Um membro sem documentação que redefine um membro documentado recebe a documentação do antepassado. |
| `SEPARATE_MEMBER_PAGES` | YES/NO | `NO` | Escreve uma página para cada membro documentado, em vez de o pôr na página da sua unit ou classe. |
| `TAB_SIZE` | número | `4` | Número de espaços que substituem um tab nos fragmentos de código. |
| `ALIASES` | lista | — | Comandos seus: `"nome=texto"`. Com `"todoh=\todo (alta)"` pode escrever `\todoh` nos comentários. Use `^^` para uma nova linha e `\1`, `\2` para argumentos. |
| `MARKDOWN_SUPPORT` | YES/NO | `YES` | Os comentários são lidos como Markdown (listas, `código`, **negrito**, tabelas, títulos, ligações) e podem continuar a usar comandos Doxygen e HTML. |
| `MARKDOWN_STRICT` | YES/NO | `YES` | Nos conflitos entre o Markdown e a sintaxe do Doxygen (as plicas invertidas) ganha o Markdown. |
| `TOC_INCLUDE_HEADINGS` | número | `6` | Os títulos Markdown até este nível (1-6) entram no índice da página, mesmo sem id. 0 desliga. |
| `MARKDOWN_ID_STYLE` | escolha | `DOXYGEN` | Como são feitas as âncoras dos títulos Markdown: `DOXYGEN` ou `GITHUB` (como no GitHub, para que as ligações de um `README.md` funcionem nos dois). |
| `AUTOLINK_SUPPORT` | YES/NO | `YES` | As palavras que são o nome de uma classe, unit ou rotina documentada tornam-se ligações automaticamente. Ponha `%` antes de uma palavra (`%TList`) para evitar uma ligação. |
| `AUTOLINK_IGNORE_WORDS` | lista | — | Palavras que nunca se tornam ligações automáticas (por exemplo uma classe chamada `Name` ou `Item`). |
| `DISTRIBUTE_GROUP_DOC` | YES/NO | `NO` | Num grupo de membros, os membros sem documentação reutilizam a do primeiro membro que a tem. |
| `GROUP_NESTED_COMPOUNDS` | YES/NO | `NO` | Uma classe ou record aninhado vai para o mesmo grupo (`\ingroup`) da classe que o contém. |
| `SUBGROUPING` | YES/NO | `YES` | Os grupos de membros do mesmo tipo podem tornar-se subgrupos dessa secção (por exemplo dentro de "Métodos públicos"). |
| `NUM_PROC_THREADS` | número | `1` | Threads usadas para ler a entrada: 1 (omissão) é uma só, 0 é uma por núcleo. |
| `TIMESTAMP` | escolha | `NO` | Escreve a data e/ou hora da execução no rodapé: `NO`, `DATE`, `DATETIME` ou `YES`. Mantenha NO para comparar duas execuções com uma ferramenta de diferenças. |

![OUTPUT_LANGUAGE = Portuguese: os textos fixos da página são traduzidos.](../images/pt.png)

*OUTPUT_LANGUAGE = Portuguese: os textos fixos da página são traduzidos.*

## Construção

O que é extraído dos fontes, o que fica escondido e como as listas são ordenadas.

| Opção | Tipo | Omissão | O que faz |
|---|---|---|---|
| `EXTRACT_ALL` | YES/NO | `NO` | Documenta tudo, também o que não tem comentário. Use-o na primeira vez que corre o DoxyPas num projeto sem documentação. Desliga os avisos de membros não documentados. |
| `EXTRACT_PRIVATE` | YES/NO | `NO` | Inclui os membros `private` e `strict private` das classes. |
| `EXTRACT_STATIC` | YES/NO | `NO` | Inclui as rotinas, variáveis, constantes e tipos que existem só na secção `implementation` de uma unit. |
| `EXTRACT_LOCAL_CLASSES` | YES/NO | `YES` | Inclui as classes, records e interfaces declarados na secção `implementation`; NO mantém só as da secção `interface`. |
| `HIDE_UNDOC_MEMBERS` | YES/NO | `NO` | Esconde os membros que não têm documentação. Sem efeito com `EXTRACT_ALL = YES`. |
| `HIDE_UNDOC_CLASSES` | YES/NO | `NO` | Esconde as classes que não têm documentação (por exemplo na hierarquia de classes). Sem efeito com `EXTRACT_ALL = YES`. |
| `HIDE_UNDOC_NAMESPACES` | YES/NO | `YES` | Esconde as units que não têm documentação das listas de units. Sem efeito com `EXTRACT_ALL = YES`. |
| `HIDE_IN_BODY_DOCS` | YES/NO | `NO` | Esconde os blocos de documentação encontrados dentro do corpo de uma rotina. NO acrescenta-os à descrição detalhada. |
| `INTERNAL_DOCS` | YES/NO | `NO` | Inclui o texto que vem a seguir a `\internal` (notas para quem mantém o código). NO deixa-o fora do manual público. |
| `CASE_SENSE_NAMES` | escolha | `NO` | O Pascal não distingue maiúsculas, por isso o valor por omissão é `NO`: os nomes de ficheiro e as ligações não dependem das maiúsculas. `YES` separa ficheiros que só diferem nas maiúsculas; `SYSTEM` segue o sistema de ficheiros. |
| `HIDE_SCOPE_NAMES` | YES/NO | `NO` | YES mostra `Create` em vez de `TShape.Create`: o âmbito (unit, classe) não é repetido. |
| `HIDE_COMPOUND_REFERENCE` | YES/NO | `NO` | YES retira "Referência da classe" / "Referência da unit" dos títulos das páginas. |
| `SHOW_INCLUDE_FILES` | YES/NO | `YES` | A página de uma unit lista as units da sua cláusula `uses` (e as que a usam). |
| `INLINE_INFO` | YES/NO | `YES` | Marca as rotinas `inline` com `[inline]`. |
| `SORT_MEMBER_DOCS` | YES/NO | `YES` | Ordena a documentação detalhada dos membros por nome. NO mantém a ordem da declaração. |
| `SORT_BRIEF_DOCS` | YES/NO | `NO` | Ordena as listas breves de membros e de classes por nome. NO mantém a ordem da declaração. |
| `SORT_MEMBERS_CTORS_1ST` | YES/NO | `NO` | Põe os construtores e destrutores primeiro nas listas de membros. |
| `SORT_GROUP_NAMES` | YES/NO | `NO` | Ordena os grupos (`\defgroup`) por nome; NO mantém a ordem em que são definidos. |
| `SORT_BY_SCOPE_NAME` | YES/NO | `NO` | Ordena a lista de classes pelo nome completo (com a unit) em vez de só pelo nome da classe. |
| `GENERATE_TODOLIST` | YES/NO | `YES` | Cria a página "Lista de tarefas" com todos os comandos `\todo`. |
| `GENERATE_TESTLIST` | YES/NO | `YES` | Cria a página "Lista de testes" com todos os comandos `\test`. |
| `GENERATE_BUGLIST` | YES/NO | `YES` | Cria a página "Lista de erros" com todos os comandos `\bug`. |
| `GENERATE_DEPRECATEDLIST` | YES/NO | `YES` | Cria a página "Lista de obsoletos" com todos os comandos `\deprecated`. |
| `ENABLED_SECTIONS` | lista | — | Etiquetas das secções condicionais que são incluídas: o texto entre `\if etiqueta` e `\endif` (ou `\cond etiqueta` e `\endcond`). |
| `MAX_INITIALIZER_LINES` | número | `30` | As constantes e variáveis cujo valor inicial tem mais linhas do que este número não mostram o valor. 0 esconde todos. |
| `SHOW_USED_FILES` | YES/NO | `YES` | No fim da página de uma classe, lista os ficheiros que foram usados para a escrever. |
| `SHOW_FILES` | YES/NO | `YES` | Cria a página "Ficheiros" (e a sua entrada no menu e na árvore). NO retira-as. |
| `SHOW_NAMESPACES` | YES/NO | `YES` | Cria a página "Units" (e a sua entrada no menu e na árvore). NO retira-as. |
| `FILE_VERSION_FILTER` | texto | — | Programa que devolve a versão de um ficheiro (por exemplo um que chama `git log -1`). O DoxyPas executa `programa ficheiro` e usa o resultado; `$version` em `WARN_FORMAT` mostra-o. |
| `LAYOUT_FILE` | texto | — | Ficheiro XML que altera as páginas: que secções existem, a sua ordem e os seus títulos. Crie o ficheiro por omissão com `doxypas -l DoxygenLayout.xml` e edite-o. |
| `CITE_BIB_FILES` | lista | — | Os ficheiros `.bib` com as referências usadas por `\cite`. Precisa do `bibtex`. |
| `EXTERNAL_TOOL_PATH` | lista | — | Pastas acrescentadas à frente de `PATH` quando o DoxyPas executa ferramentas externas (`dot`, `latex`, `makeindex`, ...). |

![EXTRACT_PRIVATE = YES: o campo privado FRadius também fica documentado.](../images/private.png)

*EXTRACT_PRIVATE = YES: o campo privado FRadius também fica documentado.*

## Mensagens

Avisos e registo da execução.

| Opção | Tipo | Omissão | O que faz |
|---|---|---|---|
| `QUIET` | YES/NO | `NO` | Sem mensagens de progresso no ecrã (os avisos são controlados por `WARNINGS`). |
| `WARNINGS` | YES/NO | `YES` | Mostra os avisos (no erro padrão, ou em `WARN_LOGFILE`). Mantenha-o ligado enquanto escreve a documentação. |
| `WARN_IF_UNDOCUMENTED` | YES/NO | `YES` | Avisa de cada membro sem documentação. Desligado por `EXTRACT_ALL`. |
| `WARN_IF_DOC_ERROR` | YES/NO | `YES` | Avisa de erros nos comentários: um `\param` de um parâmetro que não existe, um parâmetro documentado duas vezes, um comando mal usado. |
| `WARN_IF_INCOMPLETE_DOC` | YES/NO | `YES` | Avisa quando só alguns dos parâmetros de uma rotina estão documentados. |
| `WARN_NO_PARAMDOC` | YES/NO | `NO` | Avisa das rotinas documentadas que não documentam nenhum dos parâmetros nem o resultado. |
| `WARN_IF_UNDOC_ENUM_VAL` | YES/NO | `NO` | Avisa dos valores de uma enumeração que não têm documentação. |
| `WARN_LAYOUT_FILE` | YES/NO | `YES` | Avisa de problemas no ficheiro de `LAYOUT_FILE` (um elemento em falta ou errado). |
| `WARN_AS_ERROR` | escolha | `NO` | `NO`: os avisos são só mensagens. `YES`: pára no primeiro aviso. `FAIL_ON_WARNINGS`: corre até ao fim e devolve um código de saída diferente de zero se houve algum aviso (bom para uma compilação de integração contínua). `FAIL_ON_WARNINGS_PRINT`: o mesmo, e imprime os avisos no fim. |
| `WARN_FORMAT` | texto | `"$file:$line: $text"` | Formato de um aviso, com `$file`, `$line`, `$text` (e `$version`). |
| `WARN_LINE_FORMAT` | texto | `"at line $line of file $file"` | Como é escrita uma referência a outro sítio dentro do texto de um aviso (`$file` e `$line`). |
| `WARN_LOGFILE` | texto | — | Ficheiro que recebe os avisos. Vazio é o erro padrão; `-` é a saída padrão. |

## Entrada

Que ficheiros são lidos e como.

| Opção | Tipo | Omissão | O que faz |
|---|---|---|---|
| `INPUT` | lista | — | Ficheiros e pastas que têm os fontes, separados por espaços. Vazio significa a pasta atual. |
| `INPUT_ENCODING` | texto | `UTF-8` | Codificação dos caracteres dos fontes. O valor por omissão é UTF-8; um ficheiro que não é UTF-8 válido é lido na página de código ANSI (os fontes antigos do Delphi). Uma marca de ordem de bytes ganha sempre. |
| `INPUT_FILE_ENCODING` | lista | — | Codificação por padrão de ficheiro, `padrão=codificação` (`*.pas=windows-1252`). Substitui `INPUT_ENCODING`. |
| `FILE_PATTERNS` | lista | `*.pas *.dpr *.dpk …` | Padrões dos ficheiros que são lidos quando `INPUT` tem pastas. O valor por omissão tem os fontes Pascal e os formulários (`*.pas *.dpr *.dpk *.pp *.p *.lpr *.dfm *.fmx`). |
| `RECURSIVE` | YES/NO | `NO` | Procura também nas subpastas das pastas de `INPUT`. |
| `EXCLUDE` | lista | — | Ficheiros e pastas que ficam de fora de `INPUT`. |
| `EXCLUDE_SYMLINKS` | YES/NO | `NO` | Deixa de fora os ficheiros e pastas que são ligações simbólicas (Linux). |
| `EXCLUDE_PATTERNS` | lista | `*/__history/* */__recovery/* */backup/*` | Padrões de ficheiros e pastas que ficam de fora, comparados com o caminho completo (`*/test/*`). O valor por omissão deixa de fora as pastas das versões anteriores do Delphi (`__history`, `__recovery`) e do Lazarus (`backup`). |
| `EXCLUDE_SYMBOLS` | lista | — | Nomes (unit, classe, rotina; `*` é um caráter universal) que ficam fora da saída. Exemplo: `TInternal*`. |
| `EXAMPLE_PATH` | lista | — | Pastas com os ficheiros que `\include`, `\snippet` e `\example` leem. |
| `EXAMPLE_PATTERNS` | lista | `*` | Padrões dos ficheiros de `EXAMPLE_PATH`. Vazio significa todos. |
| `EXAMPLE_RECURSIVE` | YES/NO | `NO` | Procura também nas subpastas de `EXAMPLE_PATH`. |
| `IMAGE_PATH` | lista | — | Pastas com as imagens usadas por `\image` (e pelo Markdown `![](x.png)`). |
| `INPUT_FILTER` | texto | — | Programa executado em cada ficheiro fonte antes de ser lido: `programa ficheiro`, e a sua saída padrão é o que o DoxyPas lê. Use-o para converter ou limpar os fontes. |
| `FILTER_PATTERNS` | lista | — | Filtros por padrão de ficheiro, `padrão=programa`. Ganham a `INPUT_FILTER` nos ficheiros que coincidem. |
| `FILTER_SOURCE_FILES` | YES/NO | `NO` | O filtro é aplicado também aos ficheiros fonte que o navegador de código mostra. |
| `FILTER_SOURCE_PATTERNS` | lista | — | Filtros por padrão só para o navegador de código; `*.ext=` (sem programa) desliga o filtro para ele. |
| `USE_MDFILE_AS_MAINPAGE` | texto | — | Um ficheiro Markdown (por exemplo o seu `README.md`) que passa a ser a página principal (`index.html`). Uma primeira linha `# Título` é o título da página. |
| `IMPLICIT_DIR_DOCS` | YES/NO | `YES` | Um `README.md` numa subpasta passa a ser a documentação dessa pasta (página "Hierarquia de pastas"), a menos que comece por `\dir`, `\page` ou `\mainpage`. |

## Navegador de código

A listagem dos fontes e as referências cruzadas.

| Opção | Tipo | Omissão | O que faz |
|---|---|---|---|
| `SOURCE_BROWSER` | YES/NO | `NO` | Escreve uma página com o fonte de cada ficheiro, com os nomes ligados à documentação e vice-versa ("Ir para o código fonte deste ficheiro"). |
| `INLINE_SOURCES` | YES/NO | `NO` | Mostra o corpo de cada rotina dentro da sua documentação. |
| `STRIP_CODE_COMMENTS` | YES/NO | `YES` | Retira os comentários de documentação dos fragmentos de código (já estão na página). |
| `REFERENCED_BY_RELATION` | YES/NO | `NO` | Para cada rotina, propriedade ou variável, lista as rotinas documentadas que a usam ("Referenciado por"). |
| `REFERENCES_RELATION` | YES/NO | `NO` | Para cada rotina, lista as entidades documentadas que ela usa ("Referências"). |
| `REFERENCES_LINK_SOURCE` | YES/NO | `YES` | As ligações das duas listas anteriores vão para o código fonte; NO envia-as para a documentação. |
| `SOURCE_TOOLTIPS` | YES/NO | `YES` | Os nomes nas páginas de código mostram uma dica com a declaração e a descrição breve. Desligue para tornar as páginas grandes mais pequenas. |

![SOURCE_BROWSER = YES: a listagem de uma unit, com ligações e dobragem.](../images/source.png)

*SOURCE_BROWSER = YES: a listagem de uma unit, com ligações e dobragem.*

![INLINE_SOURCES = YES: o corpo de cada rotina é mostrado na sua documentação.](../images/inline.png)

*INLINE_SOURCES = YES: o corpo de cada rotina é mostrado na sua documentação.*

## Índice

O índice alfabético das classes.

| Opção | Tipo | Omissão | O que faz |
|---|---|---|---|
| `ALPHABETICAL_INDEX` | YES/NO | `YES` | Cria o índice alfabético das classes ("Índice de classes"). Útil quando há muitas. |
| `IGNORE_PREFIX` | lista | — | Prefixos que são saltados no índice alfabético: com `T I E`, `TButton` fica listado em B. Um prefixo de uma letra só é removido antes de uma maiúscula. |

## Saída HTML

Aspeto e comportamento das páginas HTML, pesquisa, árvore de navegação, fórmulas e CHM.

| Opção | Tipo | Omissão | O que faz |
|---|---|---|---|
| `GENERATE_HTML` | YES/NO | `YES` | Escreve a saída HTML. |
| `HTML_OUTPUT` | texto | `html` | Subpasta de `OUTPUT_DIRECTORY` para os ficheiros HTML. |
| `HTML_FILE_EXTENSION` | texto | `.html` | Extensão das páginas (`.html`, `.htm`, `.php`...). |
| `HTML_HEADER` | texto | — | O seu próprio cabeçalho para todas as páginas (um ficheiro HTML com os marcadores do DoxyPas). Vazio é o normal. `resources\html\header.html` é um bom ponto de partida. |
| `HTML_FOOTER` | texto | — | O seu próprio rodapé para todas as páginas. Vazio é o normal. `resources\html\footer.html` é um bom ponto de partida. |
| `HTML_STYLESHEET` | texto | — | Substitui toda a folha de estilos. Prefira `HTML_EXTRA_STYLESHEET`, que não deixa de funcionar quando a normal muda. |
| `HTML_EXTRA_STYLESHEET` | lista | — | Folhas de estilos extra carregadas depois da normal, para mudar detalhes do aspeto. São copiadas para a saída. |
| `HTML_EXTRA_FILES` | lista | — | Outros ficheiros (imagens, scripts) que são copiados como estão para a pasta HTML. |
| `HTML_COLORSTYLE` | escolha | `AUTO_LIGHT` | `LIGHT` ou `DARK` fixos, `AUTO_LIGHT`/`AUTO_DARK` seguem a definição do sistema (e começam claro/escuro), `TOGGLE` acrescenta um botão para alternar. |
| `HTML_COLORSTYLE_HUE` | número | `220` | Cor principal das páginas como um ângulo da roda de cores: 0 vermelho, 60 amarelo, 120 verde, 180 ciano, 220 azul (omissão), 300 púrpura. |
| `HTML_COLORSTYLE_SAT` | número | `100` | Saturação das cores: 0 é cinzento, 255 o mais vivo. |
| `HTML_COLORSTYLE_GAMMA` | número | `80` | Gama da luminância: abaixo de 100 é mais claro, acima de 100 é mais escuro. |
| `HTML_DYNAMIC_MENUS` | YES/NO | `YES` | O menu do topo é feito com JavaScript (listas pendentes). NO escreve separadores estáticos em cada página, para navegadores sem JavaScript. |
| `HTML_DYNAMIC_SECTIONS` | YES/NO | `NO` | Algumas secções podem ser mostradas e escondidas depois de a página carregar. |
| `HTML_CODE_FOLDING` | YES/NO | `YES` | Nas páginas de código, as classes e rotinas podem ser dobradas e expandidas. |
| `HTML_COPY_CLIPBOARD` | YES/NO | `YES` | Mostra um botão no canto superior direito dos fragmentos de código que os copia. Funciona com `https:` e `file:`. |
| `HTML_PROJECT_COOKIE` | texto | — | Nome com que o navegador guarda as definições das páginas (largura da árvore, cor). Dê um a cada projeto para as manter separadas. |
| `HTML_INDEX_NUM_ENTRIES` | número | `100` | Número preferido de entradas com que as árvores abrem; 1 começa tudo fechado, 0 expande tudo. |
| `GENERATE_HTMLHELP` | YES/NO | `NO` | Escreve também os ficheiros de projeto do Microsoft HTML Help (`index.hhp`, `.hhc`, `.hhk`) para fazer um `.chm`. |
| `CHM_FILE` | texto | — | Nome do ficheiro `.chm`; com um caminho fica fora da pasta HTML. |
| `HHC_LOCATION` | texto | — | Caminho completo de `hhc.exe`. Se estiver definido, o DoxyPas executa o compilador sobre `index.hhp`. |
| `GENERATE_CHI` | YES/NO | `NO` | Escreve o índice do CHM num ficheiro `.chi` separado. |
| `CHM_INDEX_ENCODING` | texto | — | Codificação dos ficheiros de índice, conteúdo e projeto do CHM (por exemplo `windows-1252`). |
| `BINARY_TOC` | YES/NO | `NO` | Um índice binário no CHM, com os botões Anterior e Seguinte. |
| `TOC_EXPAND` | YES/NO | `NO` | Acrescenta os membros dos grupos ao índice do CHM e à árvore. |
| `SITEMAP_URL` | texto | — | Endereço público onde vai publicar o HTML. Se estiver definido, é escrito o `sitemap.xml` para os motores de pesquisa. |
| `DISABLE_INDEX` | YES/NO | `NO` | Retira os separadores/menu do topo. Faça-o só se mantiver a árvore ou se escrever a sua própria navegação. |
| `GENERATE_TREEVIEW` | YES/NO | `YES` | Mostra a árvore de navegação num painel à esquerda de todas as páginas. |
| `PAGE_OUTLINE_PANEL` | YES/NO | `YES` | Mostra um painel à direita com o esquema da página (secções e membros). Precisa de `GENERATE_TREEVIEW`. |
| `FULL_SIDEBAR` | YES/NO | `NO` | O painel da esquerda ocupa a altura toda da janela (como no Read the Docs); o título e o logótipo ficam no painel. Precisa de `GENERATE_TREEVIEW`. |
| `ENUM_VALUES_PER_LINE` | número | `4` | Quantos valores de enumeração são postos numa linha da visão geral; 0 esconde os valores aí. |
| `SHOW_ENUM_VALUES` | YES/NO | `NO` | Mostra o valor numérico (`= 2`) ao lado de cada nome de enumeração. |
| `TREEVIEW_WIDTH` | número | `250` | Largura inicial em pixels do painel da árvore (o utilizador pode arrastá-lo). |
| `EXT_LINKS_IN_WINDOW` | YES/NO | `NO` | As ligações para símbolos de outros projetos (ficheiros de etiquetas) abrem numa janela nova. |
| `OBFUSCATE_EMAILS` | YES/NO | `YES` | Esconde os endereços de e-mail dos robôs que os recolhem. |
| `HTML_FORMULA_FORMAT` | escolha | `png` | Fórmulas como imagens `png` ou `svg` (SVG precisa de `pdf2svg` ou do Inkscape). Ignorado com MathJax. |
| `FORMULA_FONTSIZE` | número | `10` | Tamanho do tipo de letra das fórmulas que são imagens. |
| `FORMULA_MACROFILE` | texto | — | Ficheiro com definições `\newcommand` para usar nas fórmulas. |
| `USE_MATHJAX` | YES/NO | `NO` | As fórmulas (`\f$ ... \f$`) são desenhadas pelo navegador com MathJax em vez de imagens pré-geradas. Não precisa de LaTeX. |
| `MATHJAX_VERSION` | escolha | `MathJax_2` | Versão do MathJax: 2, 3 ou 4. Valores: `MathJax_2`, `MathJax_3`, `MathJax_4`. |
| `MATHJAX_FORMAT` | escolha | `HTML-CSS` | Formato de saída do MathJax (`HTML-CSS`, `NativeMML`, `chtml`, `SVG`). |
| `MATHJAX_RELPATH` | texto | — | Onde está o MathJax, relativo à pasta HTML, ou um URL de uma CDN. |
| `MATHJAX_EXTENSIONS` | lista | — | Extensões do MathJax a carregar (por exemplo `ams`). |
| `MATHJAX_CODEFILE` | texto | — | Ficheiro JavaScript com código que corre quando o MathJax arranca. |
| `SEARCHENGINE` | YES/NO | `YES` | Acrescenta a caixa de pesquisa. Funciona no navegador, sem servidor. Desligue-a para o CHM (que tem a sua). |

![HTML_COLORSTYLE = DARK.](../images/dark.png)

*HTML_COLORSTYLE = DARK.*

![HTML_COLORSTYLE_HUE = 20 (laranja em vez de azul).](../images/hue.png)

*HTML_COLORSTYLE_HUE = 20 (laranja em vez de azul).*

![GENERATE_TREEVIEW = NO: sem árvore de navegação.](../images/notree.png)

*GENERATE_TREEVIEW = NO: sem árvore de navegação.*

![FULL_SIDEBAR = YES: o painel da esquerda ocupa a altura toda.](../images/sidebar.png)

*FULL_SIDEBAR = YES: o painel da esquerda ocupa a altura toda.*

## Saída LaTeX

Os fontes LaTeX e o PDF.

| Opção | Tipo | Omissão | O que faz |
|---|---|---|---|
| `GENERATE_LATEX` | YES/NO | `YES` | Escreve a saída LaTeX (`refman.tex`, um ficheiro `.tex` por unit e classe, os grafos em PDF) e um `Makefile` e `make.bat` para construir o PDF. |
| `LATEX_OUTPUT` | texto | `latex` | Subpasta de `OUTPUT_DIRECTORY` para os ficheiros LaTeX. |
| `LATEX_CMD_NAME` | texto | — | Programa LaTeX a executar (`latex`, `pdflatex`, `xelatex`...). Vazio escolhe conforme `USE_PDFLATEX`. |
| `MAKEINDEX_CMD_NAME` | texto | `makeindex` | Programa que faz o índice, como escrito no `make.bat`/`Makefile`. |
| `LATEX_MAKEINDEX_CMD` | texto | `makeindex` | O mesmo programa, como escrito dentro do ficheiro `.tex`. |
| `COMPACT_LATEX` | YES/NO | `NO` | Um documento mais compacto (tipo artigo, sem partes), para projetos pequenos. |
| `PAPER_TYPE` | escolha | `a4` | Papel: `a4`, `a3`, `letter`, `legal` ou `executive`. |
| `EXTRA_PACKAGES` | lista | — | Pacotes LaTeX acrescentados ao documento (`times`, `amsmath`, ...). |
| `LATEX_HEADER` | texto | — | O seu próprio cabeçalho LaTeX (tudo até ao primeiro capítulo). Vazio é o normal. |
| `LATEX_FOOTER` | texto | — | O seu próprio rodapé LaTeX (tudo depois do último capítulo). Vazio é o normal. |
| `LATEX_EXTRA_STYLESHEET` | lista | — | Ficheiros `.sty` extra que são copiados e carregados depois dos normais. |
| `LATEX_EXTRA_FILES` | lista | — | Outros ficheiros (imagens, ...) copiados como estão para a pasta LaTeX. |
| `PDF_HYPERLINKS` | YES/NO | `YES` | O LaTeX é preparado para fazer um PDF com ligações, em vez de referências de páginas. |
| `USE_PDFLATEX` | YES/NO | `YES` | O PDF é feito diretamente com o `pdflatex` (melhor qualidade) em vez de `latex` + `dvips` + `ps2pdf`. |
| `LATEX_BATCHMODE` | escolha | `NO` | O que o LaTeX faz perante um erro: `NO` pergunta, `YES`/`BATCH` não pára, `NON_STOP`, `SCROLL`, `ERROR_STOP`. |
| `LATEX_HIDE_INDICES` | YES/NO | `NO` | Deixa fora do livro os capítulos de índices (índice de ficheiros, de classes, ...). |
| `LATEX_BIB_STYLE` | texto | `plainnat` | Estilo BibTeX da bibliografia (`plainnat`, `ieeetr`, ...). |

## Saída XML

Os ficheiros XML com toda a estrutura do código.

| Opção | Tipo | Omissão | O que faz |
|---|---|---|---|
| `GENERATE_XML` | YES/NO | `NO` | Escreve a saída XML: um ficheiro por unit, classe e página, mais `index.xml`, com os esquemas `.xsd`. |
| `XML_OUTPUT` | texto | `xml` | Subpasta de `OUTPUT_DIRECTORY` para os ficheiros XML. |
| `XML_PROGRAMLISTING` | YES/NO | `YES` | Inclui as listagens de código (com realce e ligações) no XML. Torna-o muito maior. |

## Saída SQLite

O script SQL com os símbolos.

| Opção | Tipo | Omissão | O que faz |
|---|---|---|---|
| `GENERATE_SQLITE3` | YES/NO | `NO` | Escreve um script SQL (`doxygen_sqlite3.sql`) que cria as tabelas SQLite com os símbolos e as suas relações; carregue-o com a ferramenta `sqlite3` e consulte com SQL. |
| `SQLITE3_OUTPUT` | texto | `sqlite3` | Subpasta de `OUTPUT_DIRECTORY` para o script SQL. |

## Pré-processador

Compilação condicional: símbolos definidos e ficheiros incluídos.

| Opção | Tipo | Omissão | O que faz |
|---|---|---|---|
| `INCLUDE_PATH` | lista | — | Pastas onde se procuram os ficheiros de `{$I ficheiro}` e `{$INCLUDE ficheiro}`, depois da pasta do ficheiro que inclui. As pastas de `DELPHI_PROJECT` são acrescentadas. Não é recursivo. |
| `PREDEFINED` | lista | — | Símbolos condicionais que são definidos antes de cada ficheiro ser lido (como os "conditional defines" do Delphi ou o `-d` do Free Pascal): `DEBUG`, `USE_SSL`. O código de `{$IFDEF}` é o que o compilador veria. |

## Documentação externa

Ficheiros de etiquetas ("tag files"), para ligar à documentação de outros projetos.

| Opção | Tipo | Omissão | O que faz |
|---|---|---|---|
| `TAGFILES` | lista | — | Ficheiros de etiquetas de outros projetos, `ficheiro=localização` (uma pasta ou URL), para que os nomes desses projetos se tornem ligações. |
| `GENERATE_TAGFILE` | texto | — | Escreve um ficheiro de etiquetas com este nome, para que outros projetos possam ligar a este. |
| `ALLEXTERNALS` | YES/NO | `NO` | Lista todas as classes externas no índice de classes; NO lista só as herdadas. |
| `EXTERNAL_GROUPS` | YES/NO | `YES` | Lista os grupos dos projetos externos no índice de tópicos. |
| `EXTERNAL_PAGES` | YES/NO | `YES` | Lista as páginas dos projetos externos no índice de páginas relacionadas. |

## Grafos (Graphviz dot)

Grafos de classes, de colaboração, de units, de chamadas e de pastas.

| Opção | Tipo | Omissão | O que faz |
|---|---|---|---|
| `HIDE_UNDOC_RELATIONS` | YES/NO | `YES` | Os grafos não mostram as relações cujo destino não tem documentação. |
| `HAVE_DOT` | YES/NO | `NO` | Usa o `dot` do Graphviz para desenhar os grafos. Sem ele, só se fazem os diagramas de herança (pelo próprio DoxyPas, ver `CLASS_GRAPH`). Todas as outras opções deste grupo precisam dele. |
| `DOT_NUM_THREADS` | número | `0` | Quantos processos `dot` correm ao mesmo tempo; 0 é um por processador. |
| `DOT_BATCH_SIZE` | número | `50` | Quantos grafos um só `dot` desenha. 1 inicia um processo por grafo (lento com muitos núcleos). |
| `DOT_COMMON_ATTR` | texto | `"fontname=Helvetica,fontsize=10"` | Atributos dos nós, arestas e etiquetas de todos os grafos (`fontname=Helvetica,fontsize=10`). |
| `DOT_EDGE_ATTR` | texto | `"labelfontname=Helvetica,labelfontsize=10"` | Atributos acrescentados às arestas (setas): `arrowhead=open,arrowsize=0.5`. |
| `DOT_NODE_ATTR` | texto | `"shape=box,height=0.2,width=0.4"` | Atributos acrescentados aos nós: `shape=box,height=0.2,width=0.4`, ou `shape=plain` para não ter caixa. |
| `DOT_FONTPATH` | texto | — | Pasta onde o `dot` encontra os tipos de letra indicados nos atributos. |
| `CLASS_GRAPH` | escolha | `YES` | O diagrama de herança de cada classe. `YES`/`GRAPH` usam o `dot` (se `HAVE_DOT`), `BUILTIN` o gerador do DoxyPas, `TEXT` uma lista de texto, `NO` nenhum. |
| `COLLABORATION_GRAPH` | YES/NO | `YES` | O diagrama de colaboração de cada classe: herança e os campos e propriedades que se referem a outras classes. |
| `GROUP_GRAPHS` | YES/NO | `YES` | O grafo de dependências entre grupos (`\defgroup`). |
| `UML_LOOK` | YES/NO | `NO` | Diagramas de classes ao estilo UML: caixas com os campos e métodos e setas abertas. |
| `UML_LIMIT_NUM_FIELDS` | número | `10` | Com `UML_LOOK`, no máximo este número de campos e métodos por caixa (0 é sem limite; pode exceder em 50%). |
| `UML_MAX_EDGE_LABELS` | número | `10` | Com `UML_LOOK`, no máximo este número de etiquetas nas arestas (0 é sem limite). |
| `DOT_UML_DETAILS` | escolha | `NO` | Com `UML_LOOK`: `NO` mostra só os nomes, `YES` acrescenta os tipos e parâmetros, `NONE` não mostra membros. |
| `DOT_WRAP_THRESHOLD` | número | `17` | Comprimento de uma linha de texto num nó antes de ser quebrada. |
| `TEMPLATE_RELATIONS` | YES/NO | `NO` | Os grafos mostram as relações entre tipos genéricos e as suas instâncias. |
| `INCLUDE_GRAPH` | YES/NO | `YES` | O grafo das units que uma unit usa (a sua cláusula `uses`), direta e indiretamente. |
| `INCLUDED_BY_GRAPH` | YES/NO | `YES` | O grafo das units que usam uma unit. |
| `CALL_GRAPH` | YES/NO | `NO` | Para cada rotina, o grafo das rotinas que ela chama. Torna a execução muito mais lenta. |
| `CALLER_GRAPH` | YES/NO | `NO` | Para cada rotina, o grafo das rotinas que a chamam. Tão lento como `CALL_GRAPH`. |
| `GRAPHICAL_HIERARCHY` | YES/NO | `YES` | Escreve também a hierarquia de classes como um grafo ("hierarquia gráfica de classes"). |
| `DIRECTORY_GRAPH` | YES/NO | `YES` | O grafo das dependências entre as pastas do projeto. |
| `DIR_GRAPH_MAX_DEPTH` | número | `1` | Quantos níveis de subpastas o grafo de pastas desenha, aninhadas dentro das pastas-mãe. |
| `DOT_IMAGE_FORMAT` | escolha | `svg` | `svg` (omissão): vetorial, e os nós são ligações. `png`, `jpg`, `gif`: bitmaps sem ligações; as formas com `:` escolhem o renderizador do `dot`. |
| `INTERACTIVE_SVG` | YES/NO | `NO` | Com SVG, os grafos podem ser ampliados e movidos com o rato (`svgpan.js`). |
| `DOT_PATH` | texto | — | Pasta do `dot.exe` (`C:\Program Files\Graphviz\bin`). Vazio significa que está no `PATH`. |
| `DOTFILE_DIRS` | lista | — | Pastas com ficheiros `.dot` que `\dotfile` inclui. |
| `DOT_GRAPH_MAX_NODES` | número | `50` | Número máximo de nós de um grafo; um grafo maior é cortado e uma caixa vermelha di-lo. |
| `MAX_DOT_GRAPH_DEPTH` | número | `0` | Distância máxima ao nó raiz (0 é sem limite). 1 ou 2 acelera projetos grandes. |
| `GENERATE_LEGEND` | YES/NO | `YES` | Escreve a página "Legenda dos grafos" que explica as caixas e as setas. |
| `DOT_CLEANUP` | YES/NO | `YES` | Apaga os ficheiros `.dot` depois de as imagens estarem feitas. NO mantém-nos para depurar. |

![Por omissão: grafos de herança e de colaboração feitos pelo dot (um SVG, por isso as caixas são ligações).](../images/class.png)

*Por omissão: grafos de herança e de colaboração feitos pelo dot (um SVG, por isso as caixas são ligações).*

![UML_LOOK = YES e DOT_UML_DETAILS = YES.](../images/uml.png)

*UML_LOOK = YES e DOT_UML_DETAILS = YES.*

![HAVE_DOT = NO: só o diagrama de herança interno.](../images/nodot.png)

*HAVE_DOT = NO: só o diagrama de herança interno.*

![CALL_GRAPH = YES: o que TRectangle.Bounding chama.](../images/callgraph.png)

*CALL_GRAPH = YES: o que TRectangle.Bounding chama.*

![CALLER_GRAPH = YES: quem chama TCircle.Create.](../images/callergraph.png)

*CALLER_GRAPH = YES: quem chama TCircle.Create.*

## Object Pascal

As opções do DoxyPas que o Doxygen não tem: dialeto, plataforma, formulários e projetos.

| Opção | Tipo | Omissão | O que faz |
|---|---|---|---|
| `PASCAL_DIALECT` | escolha | `Delphi` | Delphi ou FPC: os símbolos que ficam definidos (`DELPHI`, `FPC`, `UNICODE`...), o modo da linguagem e as palavras-chave. |
| `PASCAL_PLATFORM` | escolha | `Win64` | Plataforma de destino (`Win32`, `Win64`, `Linux64`, `macOS`, `iOS`, `Android`): define `MSWINDOWS`, `LINUX`, `CPUX64`, ... para que o código entre `{$IFDEF}` seja o dessa plataforma. |
| `PASCAL_UNIT_SCOPES` | lista | `System System.Win Winapi …` | Os nomes de âmbito de unit tentados à frente do nome de uma unit (`UNITSCOPENAME` do compilador): `Classes` refere-se a `System.Classes`. |
| `PASCAL_XMLDOC` | YES/NO | `YES` | Lê também a documentação XML do Delphi: `/// <summary>`, `<param>`, `<returns>`, `<see cref>`. |
| `PASCAL_PARSE_DFM` | YES/NO | `YES` | Lê os formulários `.dfm` e `.fmx` (texto e binário) e escreve uma página com a árvore de componentes de cada um. |
| `PASCAL_DFM_PROPERTIES` | YES/NO | `YES` | A página de um formulário tem também os valores das propriedades de cada componente; NO lista só a classe, o título e os tratadores de eventos. Precisa de `PASCAL_PARSE_DFM`. |
| `DELPHI_PROJECT` | lista | — | Ficheiros Delphi `.dpr`, `.dpk`, `.dproj`, `.groupproj` ou Lazarus `.lpi`, `.lpk`: os ficheiros fonte, caminhos de pesquisa e símbolos condicionais são tirados deles. |

