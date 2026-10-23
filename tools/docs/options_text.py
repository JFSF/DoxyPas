# Text of the option reference: ID -> (English, Portuguese). tools/docs/gen_options.py checks that every option of the
# Doxyfile has an entry (and the other way around), so a new option cannot be forgotten.
# Types, defaults and allowed values are NOT here: they are read from config.xml and from `doxypas -g`.

GROUPS = {
    'Project': ('Project', 'Projeto',
                'Name, output folder, language and the general style of the comments.',
                'Nome, pasta de saída, idioma e o estilo geral dos comentários.'),
    'Build': ('Build', 'Construção',
              'What is extracted from the sources, what is hidden and how the lists are sorted.',
              'O que é extraído dos fontes, o que fica escondido e como as listas são ordenadas.'),
    'Messages': ('Messages', 'Mensagens',
                 'Warnings and the log of the run.',
                 'Avisos e registo da execução.'),
    'Input': ('Input', 'Entrada',
              'Which files are read and how.',
              'Que ficheiros são lidos e como.'),
    'Source_Browser': ('Source browser', 'Navegador de código',
                       'The listing of the sources and the cross references.',
                       'A listagem dos fontes e as referências cruzadas.'),
    'Index': ('Index', 'Índice',
              'The alphabetical index of the classes.',
              'O índice alfabético das classes.'),
    'HTML': ('HTML output', 'Saída HTML',
             'Look and behaviour of the HTML pages, search, tree view, formulas and CHM.',
             'Aspeto e comportamento das páginas HTML, pesquisa, árvore de navegação, fórmulas e CHM.'),
    'LaTeX': ('LaTeX output', 'Saída LaTeX',
              'The LaTeX sources and the PDF.',
              'Os fontes LaTeX e o PDF.'),
    'XML': ('XML output', 'Saída XML',
            'The XML files with the whole structure of the code.',
            'Os ficheiros XML com toda a estrutura do código.'),
    'Sqlite3': ('SQLite output', 'Saída SQLite',
                'The SQL script with the symbols.',
                'O script SQL com os símbolos.'),
    'Preprocessor': ('Preprocessor', 'Pré-processador',
                     'Conditional compilation: defines and include files.',
                     'Compilação condicional: símbolos definidos e ficheiros incluídos.'),
    'External': ('External documentation', 'Documentação externa',
                 'Tag files, to link to the documentation of other projects.',
                 'Ficheiros de etiquetas ("tag files"), para ligar à documentação de outros projetos.'),
    'Dot': ('Graphs (Graphviz dot)', 'Grafos (Graphviz dot)',
            'Class, collaboration, unit, call and directory graphs.',
            'Grafos de classes, de colaboração, de units, de chamadas e de pastas.'),
    'Pascal': ('Object Pascal', 'Object Pascal',
               'The options of DoxyPas that Doxygen does not have: dialect, platform, forms and projects.',
               'As opções do DoxyPas que o Doxygen não tem: dialeto, plataforma, formulários e projetos.'),
}

T = {
    # ---------------------------------------------------------------- Project
    'DOXYFILE_ENCODING': (
        'Encoding of the Doxyfile itself, for the text that follows this line. Text before it is always UTF-8.',
        'Codificação do próprio Doxyfile, para o texto que vem a seguir a esta linha. O texto anterior é sempre UTF-8.'),
    'PROJECT_NAME': (
        'Name of the project. It is the title of the pages and of the LaTeX book. Use quotes if it has spaces.',
        'Nome do projeto. É o título das páginas e do livro LaTeX. Use aspas se tiver espaços.'),
    'PROJECT_NUMBER': (
        'Version or revision number, shown next to the name. Useful to tell archived documentations apart.',
        'Número de versão ou revisão, mostrado ao lado do nome. Útil para distinguir documentações arquivadas.'),
    'PROJECT_BRIEF': (
        'One-line description shown under the project name at the top of every page. Keep it short.',
        'Descrição de uma linha, mostrada por baixo do nome do projeto no topo de cada página. Mantenha-a curta.'),
    'PROJECT_LOGO': (
        'Image shown in the header (at most 55 pixels high and 200 wide). It is copied to the output folder.',
        'Imagem mostrada no cabeçalho (no máximo 55 pixels de altura e 200 de largura). É copiada para a pasta de saída.'),
    'PROJECT_ICON': (
        'Icon of the browser tab of the HTML pages (favicon). It is copied to the output folder.',
        'Ícone do separador do navegador nas páginas HTML (favicon). É copiado para a pasta de saída.'),
    'OUTPUT_DIRECTORY': (
        'Folder where everything is written; each format goes into its own sub-folder (`html`, `latex`, `xml`, ...). '
        'A relative path is relative to where DoxyPas is started. Empty means the current folder.',
        'Pasta onde tudo é escrito; cada formato vai para a sua subpasta (`html`, `latex`, `xml`, ...). '
        'Um caminho relativo é relativo a onde o DoxyPas é iniciado. Vazio significa a pasta atual.'),
    'CREATE_SUBDIRS': (
        'Spreads the generated files over up to 4096 sub-folders (`d0/d00/`...). Only for huge projects, when one folder '
        'with tens of thousands of files makes the file system slow.',
        'Distribui os ficheiros gerados por até 4096 subpastas (`d0/d00/`...). Só para projetos enormes, quando uma pasta '
        'com dezenas de milhares de ficheiros torna o sistema de ficheiros lento.'),
    'CREATE_SUBDIRS_LEVEL': (
        'How many sub-folders are made when `CREATE_SUBDIRS = YES`: level 0 is 16 folders and every level doubles it '
        '(8, the maximum, is 4096).',
        'Quantas subpastas são criadas com `CREATE_SUBDIRS = YES`: o nível 0 são 16 pastas e cada nível duplica '
        '(8, o máximo, são 4096).'),
    'ALLOW_UNICODE_NAMES': (
        'YES keeps non-ASCII letters in the names of the generated files; NO escapes them (`_xE3_x81_x84`).',
        'YES mantém as letras não ASCII nos nomes dos ficheiros gerados; NO escapa-as (`_xE3_x81_x84`).'),
    'OUTPUT_LANGUAGE': (
        'Language of the fixed texts of the pages ("Public Methods", "Class Reference", ...). DoxyPas has translations '
        'for English, Portuguese, Brazilian, Spanish, French, German, Italian, Dutch, Polish, Russian, Chinese and Japanese; '
        'the texts that are not translated stay in English.',
        'Idioma dos textos fixos das páginas ("Métodos públicos", "Referência da classe", ...). O DoxyPas tem tradução '
        'para inglês, português, brasileiro, espanhol, francês, alemão, italiano, holandês, polaco, russo, chinês e japonês; '
        'os textos que não estão traduzidos ficam em inglês.'),
    'BRIEF_MEMBER_DESC': (
        'YES shows the brief description of each member in the lists of members (like Javadoc). NO shows only the names.',
        'YES mostra a descrição breve de cada membro nas listas de membros (como no Javadoc). NO mostra só os nomes.'),
    'REPEAT_BRIEF': (
        'YES puts the brief description in front of the detailed one in the member documentation.',
        'YES coloca a descrição breve à frente da detalhada na documentação do membro.'),
    'ABBREVIATE_BRIEF': (
        'Phrases that are removed from the start of a brief description in the lists, so "The TFoo class implements X" is '
        'listed as "implements X". `$name` stands for the name of the entity.',
        'Frases que são removidas do início de uma descrição breve nas listas, para que "The TFoo class implements X" '
        'apareça como "implements X". `$name` representa o nome da entidade.'),
    'ALWAYS_DETAILED_SEC': (
        'With `REPEAT_BRIEF = YES`, also creates the "Detailed Description" section when there is only a brief one.',
        'Com `REPEAT_BRIEF = YES`, cria também a secção "Descrição detalhada" quando só existe a descrição breve.'),
    'INLINE_INHERITED_MEMB': (
        'Shows the inherited members in the page of each class as if they were its own, instead of the link '
        '"List of all members".',
        'Mostra os membros herdados na página de cada classe como se fossem seus, em vez da ligação '
        '"Lista de todos os membros".'),
    'FULL_PATH_NAMES': (
        'YES writes the full path of a file in the lists; NO writes the shortest path that is still unique.',
        'YES escreve o caminho completo de um ficheiro nas listas; NO escreve o caminho mais curto que ainda seja único.'),
    'STRIP_FROM_PATH': (
        'Paths that are cut from the start of the file names shown in the lists (`STRIP_FROM_PATH = C:\\src\\` shows '
        '`Core\\Utils.pas`). Empty means the folder where DoxyPas is run.',
        'Caminhos que são cortados do início dos nomes de ficheiro mostrados nas listas (`STRIP_FROM_PATH = C:\\src\\` '
        'mostra `Core\\Utils.pas`). Vazio significa a pasta onde o DoxyPas é executado.'),
    'JAVADOC_AUTOBRIEF': (
        'The first sentence (up to the first dot) of a `{** ... }` or `/** ... */` comment is the brief description; '
        'with NO you need `\\brief`.',
        'A primeira frase (até ao primeiro ponto) de um comentário `{** ... }` ou `/** ... */` é a descrição breve; '
        'com NO é preciso `\\brief`.'),
    'JAVADOC_BANNER': (
        'YES treats a line such as `{*****...` as the start of a Javadoc-style comment (a "banner"); NO leaves it as a '
        'normal comment.',
        'YES trata uma linha como `{*****...` como o início de um comentário estilo Javadoc (um "banner"); NO deixa-a '
        'como comentário normal.'),
    'QT_AUTOBRIEF': (
        'Same as `JAVADOC_AUTOBRIEF` for the Qt style comments (`//!`).',
        'Igual a `JAVADOC_AUTOBRIEF`, para os comentários de estilo Qt (`//!`).'),
    'INHERIT_DOCS': (
        'A member without documentation that overrides a documented one gets the documentation of the ancestor.',
        'Um membro sem documentação que redefine um membro documentado recebe a documentação do antepassado.'),
    'SEPARATE_MEMBER_PAGES': (
        'Writes one page for each documented member instead of putting it in the page of its unit or class.',
        'Escreve uma página para cada membro documentado, em vez de o pôr na página da sua unit ou classe.'),
    'TAB_SIZE': (
        'Number of spaces that replace a tab in the code fragments.',
        'Número de espaços que substituem um tab nos fragmentos de código.'),
    'ALIASES': (
        'Your own commands: `"name=text"`. With `"todoh=\\todo (high)"` you can write `\\todoh` in the comments. Use `^^` for '
        'a new line and `\\1`, `\\2` for arguments.',
        'Comandos seus: `"nome=texto"`. Com `"todoh=\\todo (alta)"` pode escrever `\\todoh` nos comentários. Use `^^` para '
        'uma nova linha e `\\1`, `\\2` para argumentos.'),
    'MARKDOWN_SUPPORT': (
        'The comments are read as Markdown (lists, `code`, **bold**, tables, headings, links) and can still use Doxygen '
        'commands and HTML.',
        'Os comentários são lidos como Markdown (listas, `código`, **negrito**, tabelas, títulos, ligações) e podem '
        'continuar a usar comandos Doxygen e HTML.'),
    'MARKDOWN_STRICT': (
        'In the conflicts between Markdown and the Doxygen syntax (the backticks) the Markdown wins.',
        'Nos conflitos entre o Markdown e a sintaxe do Doxygen (as plicas invertidas) ganha o Markdown.'),
    'TOC_INCLUDE_HEADINGS': (
        'The Markdown headings up to this level (1-6) go into the table of contents of the page, even without an id. '
        '0 turns it off.',
        'Os títulos Markdown até este nível (1-6) entram no índice da página, mesmo sem id. 0 desliga.'),
    'MARKDOWN_ID_STYLE': (
        'How the anchors of the Markdown headings are made: `DOXYGEN` or `GITHUB` (like the GitHub rendering, so that '
        'links of a `README.md` work in both).',
        'Como são feitas as âncoras dos títulos Markdown: `DOXYGEN` ou `GITHUB` (como no GitHub, para que as ligações de '
        'um `README.md` funcionem nos dois).'),
    'AUTOLINK_SUPPORT': (
        'Words that are the name of a documented class, unit or routine become links by themselves. Put `%` before a word '
        '(`%TList`) to avoid one link.',
        'As palavras que são o nome de uma classe, unit ou rotina documentada tornam-se ligações automaticamente. Ponha `%` '
        'antes de uma palavra (`%TList`) para evitar uma ligação.'),
    'AUTOLINK_IGNORE_WORDS': (
        'Words that never become automatic links (for instance a class called `Name` or `Item`).',
        'Palavras que nunca se tornam ligações automáticas (por exemplo uma classe chamada `Name` ou `Item`).'),
    'DISTRIBUTE_GROUP_DOC': (
        'In a member group, the members without documentation reuse the one of the first member that has it.',
        'Num grupo de membros, os membros sem documentação reutilizam a do primeiro membro que a tem.'),
    'GROUP_NESTED_COMPOUNDS': (
        'A nested class or record goes to the same group (`\\ingroup`) as the class that contains it.',
        'Uma classe ou record aninhado vai para o mesmo grupo (`\\ingroup`) da classe que o contém.'),
    'SUBGROUPING': (
        'Member groups of the same kind may become sub-groups of that section (for example inside "Public Methods").',
        'Os grupos de membros do mesmo tipo podem tornar-se subgrupos dessa secção (por exemplo dentro de "Métodos '
        'públicos").'),
    'NUM_PROC_THREADS': (
        'Threads used to read the input: 1 (default) is single-threaded, 0 is one per core.',
        'Threads usadas para ler a entrada: 1 (omissão) é uma só, 0 é uma por núcleo.'),
    'TIMESTAMP': (
        'Writes the date and/or time of the run in the footer: `NO`, `DATE`, `DATETIME` or `YES`. Keep NO to compare '
        'two runs with a diff tool.',
        'Escreve a data e/ou hora da execução no rodapé: `NO`, `DATE`, `DATETIME` ou `YES`. Mantenha NO para comparar '
        'duas execuções com uma ferramenta de diferenças.'),

    # ------------------------------------------------------------------ Build
    'EXTRACT_ALL': (
        'Documents everything, also what has no comment. Use it the first time you run DoxyPas on a project without '
        'documentation. It turns off the warnings of undocumented members.',
        'Documenta tudo, também o que não tem comentário. Use-o na primeira vez que corre o DoxyPas num projeto sem '
        'documentação. Desliga os avisos de membros não documentados.'),
    'EXTRACT_PRIVATE': (
        'Includes the `private` and `strict private` members of the classes.',
        'Inclui os membros `private` e `strict private` das classes.'),
    'EXTRACT_STATIC': (
        'Includes the routines, variables, constants and types that exist only in the `implementation` section of a unit.',
        'Inclui as rotinas, variáveis, constantes e tipos que existem só na secção `implementation` de uma unit.'),
    'EXTRACT_LOCAL_CLASSES': (
        'Includes the classes, records and interfaces declared in the `implementation` section; NO keeps only the ones '
        'of the `interface` section.',
        'Inclui as classes, records e interfaces declarados na secção `implementation`; NO mantém só as da secção '
        '`interface`.'),
    'HIDE_UNDOC_MEMBERS': (
        'Hides the members that have no documentation. Without effect with `EXTRACT_ALL = YES`.',
        'Esconde os membros que não têm documentação. Sem efeito com `EXTRACT_ALL = YES`.'),
    'HIDE_UNDOC_CLASSES': (
        'Hides the classes that have no documentation (for example in the class hierarchy). Without effect with '
        '`EXTRACT_ALL = YES`.',
        'Esconde as classes que não têm documentação (por exemplo na hierarquia de classes). Sem efeito com '
        '`EXTRACT_ALL = YES`.'),
    'HIDE_UNDOC_NAMESPACES': (
        'Hides the units that have no documentation from the lists of units. Without effect with `EXTRACT_ALL = YES`.',
        'Esconde as units que não têm documentação das listas de units. Sem efeito com `EXTRACT_ALL = YES`.'),
    'HIDE_IN_BODY_DOCS': (
        'Hides the documentation blocks found inside the body of a routine. NO appends them to the detailed description.',
        'Esconde os blocos de documentação encontrados dentro do corpo de uma rotina. NO acrescenta-os à descrição '
        'detalhada.'),
    'INTERNAL_DOCS': (
        'Includes the text that follows `\\internal` (notes for the maintainers). NO leaves it out of the public manual.',
        'Inclui o texto que vem a seguir a `\\internal` (notas para quem mantém o código). NO deixa-o fora do manual '
        'público.'),
    'CASE_SENSE_NAMES': (
        'Pascal is not case sensitive, so the default is `NO`: file names and links do not depend on the casing. '
        '`YES` keeps files that differ only in casing apart; `SYSTEM` follows the file system.',
        'O Pascal não distingue maiúsculas, por isso o valor por omissão é `NO`: os nomes de ficheiro e as ligações não '
        'dependem das maiúsculas. `YES` separa ficheiros que só diferem nas maiúsculas; `SYSTEM` segue o sistema de ficheiros.'),
    'HIDE_SCOPE_NAMES': (
        'YES shows `Create` instead of `TShape.Create`: the scope (unit, class) is not repeated.',
        'YES mostra `Create` em vez de `TShape.Create`: o âmbito (unit, classe) não é repetido.'),
    'HIDE_COMPOUND_REFERENCE': (
        'YES removes "Class Reference" / "Unit Reference" from the titles of the pages.',
        'YES retira "Referência da classe" / "Referência da unit" dos títulos das páginas.'),
    'SHOW_INCLUDE_FILES': (
        'The page of a unit lists the units of its `uses` clause (and the ones that use it).',
        'A página de uma unit lista as units da sua cláusula `uses` (e as que a usam).'),
    'INLINE_INFO': (
        'Marks the inline routines with `[inline]`.',
        'Marca as rotinas `inline` com `[inline]`.'),
    'SORT_MEMBER_DOCS': (
        'Sorts the detailed documentation of the members by name. NO keeps the order of the declaration.',
        'Ordena a documentação detalhada dos membros por nome. NO mantém a ordem da declaração.'),
    'SORT_BRIEF_DOCS': (
        'Sorts the brief lists of members and of classes by name. NO keeps the order of the declaration.',
        'Ordena as listas breves de membros e de classes por nome. NO mantém a ordem da declaração.'),
    'SORT_MEMBERS_CTORS_1ST': (
        'Puts the constructors and destructors first in the lists of members.',
        'Põe os construtores e destrutores primeiro nas listas de membros.'),
    'SORT_GROUP_NAMES': (
        'Sorts the groups (`\\defgroup`) by name; NO keeps the order in which they are defined.',
        'Ordena os grupos (`\\defgroup`) por nome; NO mantém a ordem em que são definidos.'),
    'SORT_BY_SCOPE_NAME': (
        'Sorts the class list by the full name (with the unit) instead of the class name only.',
        'Ordena a lista de classes pelo nome completo (com a unit) em vez de só pelo nome da classe.'),
    'GENERATE_TODOLIST': (
        'Creates the "Todo List" page with all the `\\todo` commands.',
        'Cria a página "Lista de tarefas" com todos os comandos `\\todo`.'),
    'GENERATE_TESTLIST': (
        'Creates the "Test List" page with all the `\\test` commands.',
        'Cria a página "Lista de testes" com todos os comandos `\\test`.'),
    'GENERATE_BUGLIST': (
        'Creates the "Bug List" page with all the `\\bug` commands.',
        'Cria a página "Lista de erros" com todos os comandos `\\bug`.'),
    'GENERATE_DEPRECATEDLIST': (
        'Creates the "Deprecated List" page with all the `\\deprecated` commands.',
        'Cria a página "Lista de obsoletos" com todos os comandos `\\deprecated`.'),
    'ENABLED_SECTIONS': (
        'Labels of the conditional sections that are included: the text between `\\if label` and `\\endif` (or '
        '`\\cond label` and `\\endcond`).',
        'Etiquetas das secções condicionais que são incluídas: o texto entre `\\if etiqueta` e `\\endif` (ou '
        '`\\cond etiqueta` e `\\endcond`).'),
    'MAX_INITIALIZER_LINES': (
        'Constants and variables whose initial value is longer than this number of lines show no value. 0 hides all of them.',
        'As constantes e variáveis cujo valor inicial tem mais linhas do que este número não mostram o valor. 0 esconde todos.'),
    'SHOW_USED_FILES': (
        'At the end of the page of a class, lists the files that were used to write it.',
        'No fim da página de uma classe, lista os ficheiros que foram usados para a escrever.'),
    'SHOW_FILES': (
        'Creates the "Files" page (and its entry in the menu and in the tree). NO removes them.',
        'Cria a página "Ficheiros" (e a sua entrada no menu e na árvore). NO retira-as.'),
    'SHOW_NAMESPACES': (
        'Creates the "Units" page (and its entry in the menu and in the tree). NO removes them.',
        'Cria a página "Units" (e a sua entrada no menu e na árvore). NO retira-as.'),
    'FILE_VERSION_FILTER': (
        'Program that gives the version of a file (for example one that calls `git log -1`). DoxyPas runs '
        '`program file` and uses the output; `$version` in `WARN_FORMAT` shows it.',
        'Programa que devolve a versão de um ficheiro (por exemplo um que chama `git log -1`). O DoxyPas executa '
        '`programa ficheiro` e usa o resultado; `$version` em `WARN_FORMAT` mostra-o.'),
    'LAYOUT_FILE': (
        'XML file that changes the pages: which sections exist, their order and their titles. Create the default one with '
        '`doxypas -l DoxygenLayout.xml` and edit it.',
        'Ficheiro XML que altera as páginas: que secções existem, a sua ordem e os seus títulos. Crie o ficheiro por '
        'omissão com `doxypas -l DoxygenLayout.xml` e edite-o.'),
    'CITE_BIB_FILES': (
        'The `.bib` files with the references used by `\\cite`. Needs `bibtex`.',
        'Os ficheiros `.bib` com as referências usadas por `\\cite`. Precisa do `bibtex`.'),
    'EXTERNAL_TOOL_PATH': (
        'Folders added in front of `PATH` when DoxyPas runs external tools (`dot`, `latex`, `makeindex`, ...).',
        'Pastas acrescentadas à frente de `PATH` quando o DoxyPas executa ferramentas externas (`dot`, `latex`, `makeindex`, ...).'),

    # --------------------------------------------------------------- Messages
    'QUIET': (
        'No progress messages on the screen (warnings are controlled by `WARNINGS`).',
        'Sem mensagens de progresso no ecrã (os avisos são controlados por `WARNINGS`).'),
    'WARNINGS': (
        'Shows the warnings (on standard error, or in `WARN_LOGFILE`). Keep it on while you write the documentation.',
        'Mostra os avisos (no erro padrão, ou em `WARN_LOGFILE`). Mantenha-o ligado enquanto escreve a documentação.'),
    'WARN_IF_UNDOCUMENTED': (
        'Warns about each member without documentation. Turned off by `EXTRACT_ALL`.',
        'Avisa de cada membro sem documentação. Desligado por `EXTRACT_ALL`.'),
    'WARN_IF_DOC_ERROR': (
        'Warns about errors in the comments: a `\\param` for a parameter that does not exist, one parameter documented '
        'twice, a command used wrongly.',
        'Avisa de erros nos comentários: um `\\param` de um parâmetro que não existe, um parâmetro documentado duas '
        'vezes, um comando mal usado.'),
    'WARN_IF_INCOMPLETE_DOC': (
        'Warns when only some of the parameters of a routine are documented.',
        'Avisa quando só alguns dos parâmetros de uma rotina estão documentados.'),
    'WARN_NO_PARAMDOC': (
        'Warns about documented routines that document none of their parameters or the result.',
        'Avisa das rotinas documentadas que não documentam nenhum dos parâmetros nem o resultado.'),
    'WARN_IF_UNDOC_ENUM_VAL': (
        'Warns about the values of an enumeration that have no documentation.',
        'Avisa dos valores de uma enumeração que não têm documentação.'),
    'WARN_LAYOUT_FILE': (
        'Warns about problems in the file of `LAYOUT_FILE` (an element that is missing or wrong).',
        'Avisa de problemas no ficheiro de `LAYOUT_FILE` (um elemento em falta ou errado).'),
    'WARN_AS_ERROR': (
        '`NO`: warnings are only messages. `YES`: stops at the first warning. `FAIL_ON_WARNINGS`: runs to the end and '
        'returns a non-zero exit code if there was any warning (good for a CI build). `FAIL_ON_WARNINGS_PRINT`: the same, '
        'and prints the warnings at the end.',
        '`NO`: os avisos são só mensagens. `YES`: pára no primeiro aviso. `FAIL_ON_WARNINGS`: corre até ao fim e devolve '
        'um código de saída diferente de zero se houve algum aviso (bom para uma compilação de integração contínua). '
        '`FAIL_ON_WARNINGS_PRINT`: o mesmo, e imprime os avisos no fim.'),
    'WARN_FORMAT': (
        'Format of a warning, with `$file`, `$line`, `$text` (and `$version`).',
        'Formato de um aviso, com `$file`, `$line`, `$text` (e `$version`).'),
    'WARN_LINE_FORMAT': (
        'How a reference to another place is written inside the text of a warning (`$file` and `$line`).',
        'Como é escrita uma referência a outro sítio dentro do texto de um aviso (`$file` e `$line`).'),
    'WARN_LOGFILE': (
        'File that receives the warnings. Empty is standard error; `-` is standard output.',
        'Ficheiro que recebe os avisos. Vazio é o erro padrão; `-` é a saída padrão.'),

    # ------------------------------------------------------------------ Input
    'INPUT': (
        'Files and folders that have the sources, separated by spaces. Empty means the current folder.',
        'Ficheiros e pastas que têm os fontes, separados por espaços. Vazio significa a pasta atual.'),
    'INPUT_ENCODING': (
        'Character encoding of the sources. The default is UTF-8; a file that is not valid UTF-8 is read in the ANSI '
        'code page (the old Delphi sources). A byte order mark always wins.',
        'Codificação dos caracteres dos fontes. O valor por omissão é UTF-8; um ficheiro que não é UTF-8 válido é lido na '
        'página de código ANSI (os fontes antigos do Delphi). Uma marca de ordem de bytes ganha sempre.'),
    'INPUT_FILE_ENCODING': (
        'Encoding by file pattern, `pattern=encoding` (`*.pas=windows-1252`). It overrides `INPUT_ENCODING`.',
        'Codificação por padrão de ficheiro, `padrão=codificação` (`*.pas=windows-1252`). Substitui `INPUT_ENCODING`.'),
    'FILE_PATTERNS': (
        'Patterns of the files that are read when `INPUT` has folders. The default has the Pascal sources and the forms '
        '(`*.pas *.dpr *.dpk *.pp *.p *.lpr *.dfm *.fmx`).',
        'Padrões dos ficheiros que são lidos quando `INPUT` tem pastas. O valor por omissão tem os fontes Pascal e os '
        'formulários (`*.pas *.dpr *.dpk *.pp *.p *.lpr *.dfm *.fmx`).'),
    'RECURSIVE': (
        'Also searches the sub-folders of the folders of `INPUT`.',
        'Procura também nas subpastas das pastas de `INPUT`.'),
    'EXCLUDE': (
        'Files and folders that are left out of `INPUT`.',
        'Ficheiros e pastas que ficam de fora de `INPUT`.'),
    'EXCLUDE_SYMLINKS': (
        'Leaves out the files and folders that are symbolic links (Linux).',
        'Deixa de fora os ficheiros e pastas que são ligações simbólicas (Linux).'),
    'EXCLUDE_PATTERNS': (
        'Patterns of files and folders that are left out, compared with the full path (`*/test/*`). The default leaves '
        'out the folders of the previous versions of Delphi (`__history`, `__recovery`) and Lazarus (`backup`).',
        'Padrões de ficheiros e pastas que ficam de fora, comparados com o caminho completo (`*/test/*`). O valor por '
        'omissão deixa de fora as pastas das versões anteriores do Delphi (`__history`, `__recovery`) e do Lazarus (`backup`).'),
    'EXCLUDE_SYMBOLS': (
        'Names (unit, class, routine; `*` is a wildcard) that are left out of the output. Example: `TInternal*`.',
        'Nomes (unit, classe, rotina; `*` é um caráter universal) que ficam fora da saída. Exemplo: `TInternal*`.'),
    'EXAMPLE_PATH': (
        'Folders with the files that `\\include`, `\\snippet` and `\\example` read.',
        'Pastas com os ficheiros que `\\include`, `\\snippet` e `\\example` leem.'),
    'EXAMPLE_PATTERNS': (
        'Patterns of the files of `EXAMPLE_PATH`. Empty means all.',
        'Padrões dos ficheiros de `EXAMPLE_PATH`. Vazio significa todos.'),
    'EXAMPLE_RECURSIVE': (
        'Also searches the sub-folders of `EXAMPLE_PATH`.',
        'Procura também nas subpastas de `EXAMPLE_PATH`.'),
    'IMAGE_PATH': (
        'Folders with the images used by `\\image` (and by Markdown `![](x.png)`).',
        'Pastas com as imagens usadas por `\\image` (e pelo Markdown `![](x.png)`).'),
    'INPUT_FILTER': (
        'Program run on every source file before it is read: `program file`, and its standard output is what DoxyPas '
        'reads. Use it to convert or clean the sources.',
        'Programa executado em cada ficheiro fonte antes de ser lido: `programa ficheiro`, e a sua saída padrão é o que '
        'o DoxyPas lê. Use-o para converter ou limpar os fontes.'),
    'FILTER_PATTERNS': (
        'Filters by file pattern, `pattern=program`. They win over `INPUT_FILTER` for the files that match.',
        'Filtros por padrão de ficheiro, `padrão=programa`. Ganham a `INPUT_FILTER` nos ficheiros que coincidem.'),
    'FILTER_SOURCE_FILES': (
        'The filter is also applied to the source files that the source browser shows.',
        'O filtro é aplicado também aos ficheiros fonte que o navegador de código mostra.'),
    'FILTER_SOURCE_PATTERNS': (
        'Filters by pattern for the source browser only; `*.ext=` (no program) turns the filter off for it.',
        'Filtros por padrão só para o navegador de código; `*.ext=` (sem programa) desliga o filtro para ele.'),
    'USE_MDFILE_AS_MAINPAGE': (
        'A Markdown file (for instance your `README.md`) that becomes the main page (`index.html`). A first line '
        '`# Title` is the title of the page.',
        'Um ficheiro Markdown (por exemplo o seu `README.md`) que passa a ser a página principal (`index.html`). Uma '
        'primeira linha `# Título` é o título da página.'),
    'IMPLICIT_DIR_DOCS': (
        'A `README.md` in a sub-folder becomes the documentation of that folder (page "Directory Hierarchy"), unless it '
        'starts with `\\dir`, `\\page` or `\\mainpage`.',
        'Um `README.md` numa subpasta passa a ser a documentação dessa pasta (página "Hierarquia de pastas"), a menos que '
        'comece por `\\dir`, `\\page` ou `\\mainpage`.'),

    # --------------------------------------------------------- Source browser
    'SOURCE_BROWSER': (
        'Writes a page with the source of every file, with the names linked to the documentation and the other way '
        'round ("Go to the source code of this file").',
        'Escreve uma página com o fonte de cada ficheiro, com os nomes ligados à documentação e vice-versa ("Ir para o '
        'código fonte deste ficheiro").'),
    'INLINE_SOURCES': (
        'Shows the body of each routine inside its documentation.',
        'Mostra o corpo de cada rotina dentro da sua documentação.'),
    'STRIP_CODE_COMMENTS': (
        'Removes the documentation comments from the source fragments (they are already in the page).',
        'Retira os comentários de documentação dos fragmentos de código (já estão na página).'),
    'REFERENCED_BY_RELATION': (
        'For each routine, property or variable, lists the documented routines that use it ("Referenced by").',
        'Para cada rotina, propriedade ou variável, lista as rotinas documentadas que a usam ("Referenciado por").'),
    'REFERENCES_RELATION': (
        'For each routine, lists the documented entities that it uses ("References").',
        'Para cada rotina, lista as entidades documentadas que ela usa ("Referências").'),
    'REFERENCES_LINK_SOURCE': (
        'The links of the two lists above go to the source code; NO sends them to the documentation.',
        'As ligações das duas listas anteriores vão para o código fonte; NO envia-as para a documentação.'),
    'SOURCE_TOOLTIPS': (
        'The names in the source pages show a tooltip with the declaration and the brief description. Turn it off to '
        'make big pages smaller.',
        'Os nomes nas páginas de código mostram uma dica com a declaração e a descrição breve. Desligue para tornar as '
        'páginas grandes mais pequenas.'),

    # ------------------------------------------------------------------ Index
    'ALPHABETICAL_INDEX': (
        'Creates the alphabetical index of the classes ("Class Index"). Useful when there are many.',
        'Cria o índice alfabético das classes ("Índice de classes"). Útil quando há muitas.'),
    'IGNORE_PREFIX': (
        'Prefixes that are skipped in the alphabetical index: with `T I E`, `TButton` is listed under B. A one-letter '
        'prefix is removed only before an upper case letter.',
        'Prefixos que são saltados no índice alfabético: com `T I E`, `TButton` fica listado em B. Um prefixo de uma '
        'letra só é removido antes de uma maiúscula.'),

    # ------------------------------------------------------------------- HTML
    'GENERATE_HTML': (
        'Writes the HTML output.',
        'Escreve a saída HTML.'),
    'HTML_OUTPUT': (
        'Sub-folder of `OUTPUT_DIRECTORY` for the HTML files.',
        'Subpasta de `OUTPUT_DIRECTORY` para os ficheiros HTML.'),
    'HTML_FILE_EXTENSION': (
        'Extension of the pages (`.html`, `.htm`, `.php`...).',
        'Extensão das páginas (`.html`, `.htm`, `.php`...).'),
    'HTML_HEADER': (
        'Your own header for every page (an HTML file with the markers of DoxyPas). Empty is the standard one. '
        '`resources\\html\\header.html` is a good start.',
        'O seu próprio cabeçalho para todas as páginas (um ficheiro HTML com os marcadores do DoxyPas). Vazio é o '
        'normal. `resources\\html\\header.html` é um bom ponto de partida.'),
    'HTML_FOOTER': (
        'Your own footer for every page. Empty is the standard one. `resources\\html\\footer.html` is a good start.',
        'O seu próprio rodapé para todas as páginas. Vazio é o normal. `resources\\html\\footer.html` é um bom ponto de partida.'),
    'HTML_STYLESHEET': (
        'Replaces the whole style sheet. Prefer `HTML_EXTRA_STYLESHEET`, which does not break when the standard one changes.',
        'Substitui toda a folha de estilos. Prefira `HTML_EXTRA_STYLESHEET`, que não deixa de funcionar quando a normal muda.'),
    'HTML_EXTRA_STYLESHEET': (
        'Extra style sheets loaded after the standard one, to change details of the look. They are copied to the output.',
        'Folhas de estilos extra carregadas depois da normal, para mudar detalhes do aspeto. São copiadas para a saída.'),
    'HTML_EXTRA_FILES': (
        'Other files (images, scripts) that are copied to the HTML folder as they are.',
        'Outros ficheiros (imagens, scripts) que são copiados como estão para a pasta HTML.'),
    'HTML_COLORSTYLE': (
        '`LIGHT` or `DARK` fixed, `AUTO_LIGHT`/`AUTO_DARK` follow the setting of the system (and start light/dark), '
        '`TOGGLE` adds a button to switch.',
        '`LIGHT` ou `DARK` fixos, `AUTO_LIGHT`/`AUTO_DARK` seguem a definição do sistema (e começam claro/escuro), '
        '`TOGGLE` acrescenta um botão para alternar.'),
    'HTML_COLORSTYLE_HUE': (
        'Main color of the pages as an angle of the color wheel: 0 red, 60 yellow, 120 green, 180 cyan, 220 blue (default), '
        '300 purple.',
        'Cor principal das páginas como um ângulo da roda de cores: 0 vermelho, 60 amarelo, 120 verde, 180 ciano, 220 azul '
        '(omissão), 300 púrpura.'),
    'HTML_COLORSTYLE_SAT': (
        'Saturation of the colors: 0 is gray, 255 the most vivid.',
        'Saturação das cores: 0 é cinzento, 255 o mais vivo.'),
    'HTML_COLORSTYLE_GAMMA': (
        'Gamma of the luminance: below 100 is lighter, above 100 is darker.',
        'Gama da luminância: abaixo de 100 é mais claro, acima de 100 é mais escuro.'),
    'HTML_DYNAMIC_MENUS': (
        'The menu at the top is made with JavaScript (drop-down lists). NO writes static tabs in every page, for browsers '
        'without JavaScript.',
        'O menu do topo é feito com JavaScript (listas pendentes). NO escreve separadores estáticos em cada página, para '
        'navegadores sem JavaScript.'),
    'HTML_DYNAMIC_SECTIONS': (
        'Some sections can be shown and hidden after the page loads.',
        'Algumas secções podem ser mostradas e escondidas depois de a página carregar.'),
    'HTML_CODE_FOLDING': (
        'In the source pages, the classes and routines can be folded and expanded.',
        'Nas páginas de código, as classes e rotinas podem ser dobradas e expandidas.'),
    'HTML_COPY_CLIPBOARD': (
        'Shows a button at the top right of the code fragments that copies them. Works with `https:` and `file:`.',
        'Mostra um botão no canto superior direito dos fragmentos de código que os copia. Funciona com `https:` e `file:`.'),
    'HTML_PROJECT_COOKIE': (
        'Name under which the browser stores the settings of the pages (tree width, color). Give each project its own to '
        'keep them apart.',
        'Nome com que o navegador guarda as definições das páginas (largura da árvore, cor). Dê um a cada projeto para as '
        'manter separadas.'),
    'HTML_INDEX_NUM_ENTRIES': (
        'Preferred number of entries that the trees open with; 1 starts all collapsed, 0 expands all.',
        'Número preferido de entradas com que as árvores abrem; 1 começa tudo fechado, 0 expande tudo.'),
    'GENERATE_HTMLHELP': (
        'Also writes the project files for Microsoft HTML Help (`index.hhp`, `.hhc`, `.hhk`) to make a `.chm`.',
        'Escreve também os ficheiros de projeto do Microsoft HTML Help (`index.hhp`, `.hhc`, `.hhk`) para fazer um `.chm`.'),
    'CHM_FILE': (
        'Name of the `.chm` file; a path puts it outside the HTML folder.',
        'Nome do ficheiro `.chm`; com um caminho fica fora da pasta HTML.'),
    'HHC_LOCATION': (
        'Full path of `hhc.exe`. If it is set, DoxyPas runs the compiler on `index.hhp`.',
        'Caminho completo de `hhc.exe`. Se estiver definido, o DoxyPas executa o compilador sobre `index.hhp`.'),
    'GENERATE_CHI': (
        'Writes the index of the CHM in a separate `.chi` file.',
        'Escreve o índice do CHM num ficheiro `.chi` separado.'),
    'CHM_INDEX_ENCODING': (
        'Encoding of the index, contents and project files of the CHM (for example `windows-1252`).',
        'Codificação dos ficheiros de índice, conteúdo e projeto do CHM (por exemplo `windows-1252`).'),
    'BINARY_TOC': (
        'A binary table of contents in the CHM, with the Previous and Next buttons.',
        'Um índice binário no CHM, com os botões Anterior e Seguinte.'),
    'TOC_EXPAND': (
        'Adds the members of the groups to the table of contents of the CHM and to the tree.',
        'Acrescenta os membros dos grupos ao índice do CHM e à árvore.'),
    'SITEMAP_URL': (
        'Public address where you will publish the HTML. If it is set, `sitemap.xml` is written for the search engines.',
        'Endereço público onde vai publicar o HTML. Se estiver definido, é escrito o `sitemap.xml` para os motores de pesquisa.'),
    'DISABLE_INDEX': (
        'Removes the tabs/menu at the top. Do it only if you keep the tree view or if you write your own navigation.',
        'Retira os separadores/menu do topo. Faça-o só se mantiver a árvore ou se escrever a sua própria navegação.'),
    'GENERATE_TREEVIEW': (
        'Shows the navigation tree in a panel at the left of every page.',
        'Mostra a árvore de navegação num painel à esquerda de todas as páginas.'),
    'PAGE_OUTLINE_PANEL': (
        'Shows a panel at the right with the outline of the page (sections and members). Needs `GENERATE_TREEVIEW`.',
        'Mostra um painel à direita com o esquema da página (secções e membros). Precisa de `GENERATE_TREEVIEW`.'),
    'FULL_SIDEBAR': (
        'The left panel takes the full height of the window (like Read the Docs); the title and logo stay in the panel. '
        'Needs `GENERATE_TREEVIEW`.',
        'O painel da esquerda ocupa a altura toda da janela (como no Read the Docs); o título e o logótipo ficam no painel. '
        'Precisa de `GENERATE_TREEVIEW`.'),
    'ENUM_VALUES_PER_LINE': (
        'How many enumeration values are put on one line of the overview; 0 hides the values there.',
        'Quantos valores de enumeração são postos numa linha da visão geral; 0 esconde os valores aí.'),
    'SHOW_ENUM_VALUES': (
        'Shows the numeric value (`= 2`) next to each enumeration name.',
        'Mostra o valor numérico (`= 2`) ao lado de cada nome de enumeração.'),
    'TREEVIEW_WIDTH': (
        'Initial width in pixels of the tree panel (the user can drag it).',
        'Largura inicial em pixels do painel da árvore (o utilizador pode arrastá-lo).'),
    'EXT_LINKS_IN_WINDOW': (
        'Links to symbols of other projects (tag files) open in a new window.',
        'As ligações para símbolos de outros projetos (ficheiros de etiquetas) abrem numa janela nova.'),
    'OBFUSCATE_EMAILS': (
        'Hides the e-mail addresses from the robots that harvest them.',
        'Esconde os endereços de e-mail dos robôs que os recolhem.'),
    'HTML_FORMULA_FORMAT': (
        'Formulas as `png` or `svg` images (SVG needs `pdf2svg` or Inkscape). Ignored with MathJax.',
        'Fórmulas como imagens `png` ou `svg` (SVG precisa de `pdf2svg` ou do Inkscape). Ignorado com MathJax.'),
    'FORMULA_FONTSIZE': (
        'Font size of the formulas that are images.',
        'Tamanho do tipo de letra das fórmulas que são imagens.'),
    'FORMULA_MACROFILE': (
        'File with `\\newcommand` definitions to use in the formulas.',
        'Ficheiro com definições `\\newcommand` para usar nas fórmulas.'),
    'USE_MATHJAX': (
        'Formulas (`\\f$ ... \\f$`) are drawn by the browser with MathJax instead of pre-rendered images. Does not need LaTeX.',
        'As fórmulas (`\\f$ ... \\f$`) são desenhadas pelo navegador com MathJax em vez de imagens pré-geradas. Não precisa de LaTeX.'),
    'MATHJAX_VERSION': (
        'MathJax version: 2, 3 or 4.',
        'Versão do MathJax: 2, 3 ou 4.'),
    'MATHJAX_FORMAT': (
        'Output format of MathJax (`HTML-CSS`, `NativeMML`, `chtml`, `SVG`).',
        'Formato de saída do MathJax (`HTML-CSS`, `NativeMML`, `chtml`, `SVG`).'),
    'MATHJAX_RELPATH': (
        'Where MathJax is, relative to the HTML folder, or a URL of a CDN.',
        'Onde está o MathJax, relativo à pasta HTML, ou um URL de uma CDN.'),
    'MATHJAX_EXTENSIONS': (
        'MathJax extensions to load (for example `ams`).',
        'Extensões do MathJax a carregar (por exemplo `ams`).'),
    'MATHJAX_CODEFILE': (
        'JavaScript file with code that runs when MathJax starts.',
        'Ficheiro JavaScript com código que corre quando o MathJax arranca.'),
    'SEARCHENGINE': (
        'Adds the search box. It works in the browser, without a server. Turn it off for the CHM (it has its own).',
        'Acrescenta a caixa de pesquisa. Funciona no navegador, sem servidor. Desligue-a para o CHM (que tem a sua).'),

    # ------------------------------------------------------------------ LaTeX
    'GENERATE_LATEX': (
        'Writes the LaTeX output (`refman.tex`, one `.tex` file per unit and class, the graphs as PDF) and a `Makefile` and `make.bat` to build the PDF.',
        'Escreve a saída LaTeX (`refman.tex`, um ficheiro `.tex` por unit e classe, os grafos em PDF) e um `Makefile` e `make.bat` para construir o PDF.'),
    'LATEX_OUTPUT': (
        'Sub-folder of `OUTPUT_DIRECTORY` for the LaTeX files.',
        'Subpasta de `OUTPUT_DIRECTORY` para os ficheiros LaTeX.'),
    'LATEX_CMD_NAME': (
        'LaTeX program to run (`latex`, `pdflatex`, `xelatex`...). Empty chooses by `USE_PDFLATEX`.',
        'Programa LaTeX a executar (`latex`, `pdflatex`, `xelatex`...). Vazio escolhe conforme `USE_PDFLATEX`.'),
    'MAKEINDEX_CMD_NAME': (
        'Program that makes the index, as written in the `make.bat`/`Makefile`.',
        'Programa que faz o índice, como escrito no `make.bat`/`Makefile`.'),
    'LATEX_MAKEINDEX_CMD': (
        'The same program, as written inside the `.tex` file.',
        'O mesmo programa, como escrito dentro do ficheiro `.tex`.'),
    'COMPACT_LATEX': (
        'A more compact document (article-like, without parts), for small projects.',
        'Um documento mais compacto (tipo artigo, sem partes), para projetos pequenos.'),
    'PAPER_TYPE': (
        'Paper: `a4`, `a3`, `letter`, `legal` or `executive`.',
        'Papel: `a4`, `a3`, `letter`, `legal` ou `executive`.'),
    'EXTRA_PACKAGES': (
        'LaTeX packages added to the document (`times`, `amsmath`, ...).',
        'Pacotes LaTeX acrescentados ao documento (`times`, `amsmath`, ...).'),
    'LATEX_HEADER': (
        'Your own LaTeX header (everything up to the first chapter). Empty is the standard one.',
        'O seu próprio cabeçalho LaTeX (tudo até ao primeiro capítulo). Vazio é o normal.'),
    'LATEX_FOOTER': (
        'Your own LaTeX footer (everything after the last chapter). Empty is the standard one.',
        'O seu próprio rodapé LaTeX (tudo depois do último capítulo). Vazio é o normal.'),
    'LATEX_EXTRA_STYLESHEET': (
        'Extra `.sty` files that are copied and loaded after the standard ones.',
        'Ficheiros `.sty` extra que são copiados e carregados depois dos normais.'),
    'LATEX_EXTRA_FILES': (
        'Other files (images, ...) copied as they are to the LaTeX folder.',
        'Outros ficheiros (imagens, ...) copiados como estão para a pasta LaTeX.'),
    'PDF_HYPERLINKS': (
        'The LaTeX is prepared to make a PDF with links, instead of page references.',
        'O LaTeX é preparado para fazer um PDF com ligações, em vez de referências de páginas.'),
    'USE_PDFLATEX': (
        'The PDF is made directly with `pdflatex` (better quality) instead of `latex` + `dvips` + `ps2pdf`.',
        'O PDF é feito diretamente com o `pdflatex` (melhor qualidade) em vez de `latex` + `dvips` + `ps2pdf`.'),
    'LATEX_BATCHMODE': (
        'What LaTeX does on an error: `NO` asks, `YES`/`BATCH` does not stop, `NON_STOP`, `SCROLL`, `ERROR_STOP`.',
        'O que o LaTeX faz perante um erro: `NO` pergunta, `YES`/`BATCH` não pára, `NON_STOP`, `SCROLL`, `ERROR_STOP`.'),
    'LATEX_HIDE_INDICES': (
        'Leaves out the index chapters (file index, class index, ...) from the book.',
        'Deixa fora do livro os capítulos de índices (índice de ficheiros, de classes, ...).'),
    'LATEX_BIB_STYLE': (
        'BibTeX style of the bibliography (`plainnat`, `ieeetr`, ...).',
        'Estilo BibTeX da bibliografia (`plainnat`, `ieeetr`, ...).'),

    # ------------------------------------------------------------ XML, SQLite
    'GENERATE_XML': (
        'Writes the XML output: one file per unit, class and page, plus `index.xml`, with the schemas `.xsd`.',
        'Escreve a saída XML: um ficheiro por unit, classe e página, mais `index.xml`, com os esquemas `.xsd`.'),
    'XML_OUTPUT': (
        'Sub-folder of `OUTPUT_DIRECTORY` for the XML files.',
        'Subpasta de `OUTPUT_DIRECTORY` para os ficheiros XML.'),
    'XML_PROGRAMLISTING': (
        'Includes the source listings (with highlighting and links) in the XML. It makes it much bigger.',
        'Inclui as listagens de código (com realce e ligações) no XML. Torna-o muito maior.'),
    'GENERATE_SQLITE3': (
        'Writes an SQL script (`doxygen_sqlite3.sql`) that creates the SQLite tables with the symbols and their relations; load it with the `sqlite3` tool and query with SQL.',
        'Escreve um script SQL (`doxygen_sqlite3.sql`) que cria as tabelas SQLite com os símbolos e as suas relações; carregue-o com a ferramenta `sqlite3` e consulte com SQL.'),
    'SQLITE3_OUTPUT': (
        'Sub-folder of `OUTPUT_DIRECTORY` for the SQL script.',
        'Subpasta de `OUTPUT_DIRECTORY` para o script SQL.'),

    # ----------------------------------------------------------- Preprocessor
    'INCLUDE_PATH': (
        'Folders searched for `{$I file}` and `{$INCLUDE file}`, after the folder of the file that includes. The folders of '
        '`DELPHI_PROJECT` are added. Not recursive.',
        'Pastas onde se procuram os ficheiros de `{$I ficheiro}` e `{$INCLUDE ficheiro}`, depois da pasta do ficheiro que '
        'inclui. As pastas de `DELPHI_PROJECT` são acrescentadas. Não é recursivo.'),
    'PREDEFINED': (
        'Conditional symbols that are defined before each file is read (like the conditional defines of Delphi or `-d` of '
        'Free Pascal): `DEBUG`, `USE_SSL`. The code of `{$IFDEF}` is the one the compiler would see.',
        'Símbolos condicionais que são definidos antes de cada ficheiro ser lido (como os "conditional defines" do Delphi '
        'ou o `-d` do Free Pascal): `DEBUG`, `USE_SSL`. O código de `{$IFDEF}` é o que o compilador veria.'),

    # --------------------------------------------------------------- External
    'TAGFILES': (
        'Tag files of other projects, `file=location` (a folder or URL), so that names of those projects become links.',
        'Ficheiros de etiquetas de outros projetos, `ficheiro=localização` (uma pasta ou URL), para que os nomes desses '
        'projetos se tornem ligações.'),
    'GENERATE_TAGFILE': (
        'Writes a tag file with this name, so that other projects can link to this one.',
        'Escreve um ficheiro de etiquetas com este nome, para que outros projetos possam ligar a este.'),
    'ALLEXTERNALS': (
        'Lists all the external classes in the class index; NO lists only the inherited ones.',
        'Lista todas as classes externas no índice de classes; NO lista só as herdadas.'),
    'EXTERNAL_GROUPS': (
        'Lists the groups of the external projects in the index of topics.',
        'Lista os grupos dos projetos externos no índice de tópicos.'),
    'EXTERNAL_PAGES': (
        'Lists the pages of the external projects in the index of related pages.',
        'Lista as páginas dos projetos externos no índice de páginas relacionadas.'),

    # -------------------------------------------------------------------- Dot
    'HIDE_UNDOC_RELATIONS': (
        'The graphs do not show the relations whose target has no documentation.',
        'Os grafos não mostram as relações cujo destino não tem documentação.'),
    'HAVE_DOT': (
        'Uses Graphviz `dot` to draw the graphs. Without it, only the inheritance diagrams are made (by DoxyPas itself, '
        'see `CLASS_GRAPH`). All the other options of this group need it.',
        'Usa o `dot` do Graphviz para desenhar os grafos. Sem ele, só se fazem os diagramas de herança (pelo próprio '
        'DoxyPas, ver `CLASS_GRAPH`). Todas as outras opções deste grupo precisam dele.'),
    'DOT_NUM_THREADS': (
        'How many `dot` processes run at the same time; 0 is one per processor.',
        'Quantos processos `dot` correm ao mesmo tempo; 0 é um por processador.'),
    'DOT_BATCH_SIZE': (
        'How many graphs one run of `dot` draws. 1 starts a process per graph (slow with many cores).',
        'Quantos grafos um só `dot` desenha. 1 inicia um processo por grafo (lento com muitos núcleos).'),
    'DOT_COMMON_ATTR': (
        'Attributes of nodes, edges and labels of all graphs (`fontname=Helvetica,fontsize=10`).',
        'Atributos dos nós, arestas e etiquetas de todos os grafos (`fontname=Helvetica,fontsize=10`).'),
    'DOT_EDGE_ATTR': (
        'Attributes added to the edges (arrows): `arrowhead=open,arrowsize=0.5`.',
        'Atributos acrescentados às arestas (setas): `arrowhead=open,arrowsize=0.5`.'),
    'DOT_NODE_ATTR': (
        'Attributes added to the nodes: `shape=box,height=0.2,width=0.4`, or `shape=plain` for no box.',
        'Atributos acrescentados aos nós: `shape=box,height=0.2,width=0.4`, ou `shape=plain` para não ter caixa.'),
    'DOT_FONTPATH': (
        'Folder where `dot` finds the fonts named in the attributes.',
        'Pasta onde o `dot` encontra os tipos de letra indicados nos atributos.'),
    'CLASS_GRAPH': (
        'The inheritance diagram of each class. `YES`/`GRAPH` use `dot` (if `HAVE_DOT`), `BUILTIN` the generator of '
        'DoxyPas, `TEXT` a list of text, `NO` none.',
        'O diagrama de herança de cada classe. `YES`/`GRAPH` usam o `dot` (se `HAVE_DOT`), `BUILTIN` o gerador do '
        'DoxyPas, `TEXT` uma lista de texto, `NO` nenhum.'),
    'COLLABORATION_GRAPH': (
        'The collaboration diagram of each class: inheritance and the fields and properties that refer to other classes.',
        'O diagrama de colaboração de cada classe: herança e os campos e propriedades que se referem a outras classes.'),
    'GROUP_GRAPHS': (
        'The dependency graph between groups (`\\defgroup`).',
        'O grafo de dependências entre grupos (`\\defgroup`).'),
    'UML_LOOK': (
        'Class diagrams in UML style: boxes with the fields and methods and open arrows.',
        'Diagramas de classes ao estilo UML: caixas com os campos e métodos e setas abertas.'),
    'UML_LIMIT_NUM_FIELDS': (
        'With `UML_LOOK`, at most this number of fields and methods per box (0 is no limit; it may exceed by 50%).',
        'Com `UML_LOOK`, no máximo este número de campos e métodos por caixa (0 é sem limite; pode exceder em 50%).'),
    'UML_MAX_EDGE_LABELS': (
        'With `UML_LOOK`, at most this number of labels on the edges (0 is no limit).',
        'Com `UML_LOOK`, no máximo este número de etiquetas nas arestas (0 é sem limite).'),
    'DOT_UML_DETAILS': (
        'With `UML_LOOK`: `NO` shows names only, `YES` adds the types and parameters, `NONE` shows no members.',
        'Com `UML_LOOK`: `NO` mostra só os nomes, `YES` acrescenta os tipos e parâmetros, `NONE` não mostra membros.'),
    'DOT_WRAP_THRESHOLD': (
        'Length of a line of text in a node before it is wrapped.',
        'Comprimento de uma linha de texto num nó antes de ser quebrada.'),
    'TEMPLATE_RELATIONS': (
        'The graphs show the relations between generic types and their instances.',
        'Os grafos mostram as relações entre tipos genéricos e as suas instâncias.'),
    'INCLUDE_GRAPH': (
        'The graph of the units that a unit uses (its `uses` clause), directly and indirectly.',
        'O grafo das units que uma unit usa (a sua cláusula `uses`), direta e indiretamente.'),
    'INCLUDED_BY_GRAPH': (
        'The graph of the units that use a unit.',
        'O grafo das units que usam uma unit.'),
    'CALL_GRAPH': (
        'For each routine, the graph of the routines that it calls. Makes the run much slower.',
        'Para cada rotina, o grafo das rotinas que ela chama. Torna a execução muito mais lenta.'),
    'CALLER_GRAPH': (
        'For each routine, the graph of the routines that call it. As slow as `CALL_GRAPH`.',
        'Para cada rotina, o grafo das rotinas que a chamam. Tão lento como `CALL_GRAPH`.'),
    'GRAPHICAL_HIERARCHY': (
        'Also writes the class hierarchy as a graph ("graphical class hierarchy").',
        'Escreve também a hierarquia de classes como um grafo ("hierarquia gráfica de classes").'),
    'DIRECTORY_GRAPH': (
        'The graph of dependencies between the folders of the project.',
        'O grafo das dependências entre as pastas do projeto.'),
    'DIR_GRAPH_MAX_DEPTH': (
        'How many levels of sub-folders the directory graph draws, nested inside their parents.',
        'Quantos níveis de subpastas o grafo de pastas desenha, aninhadas dentro das pastas-mãe.'),
    'DOT_IMAGE_FORMAT': (
        '`svg` (default): vector, and the nodes are links. `png`, `jpg`, `gif`: bitmaps without links; the forms with `:` '
        'choose the renderer of `dot`.',
        '`svg` (omissão): vetorial, e os nós são ligações. `png`, `jpg`, `gif`: bitmaps sem ligações; as formas com `:` '
        'escolhem o renderizador do `dot`.'),
    'INTERACTIVE_SVG': (
        'With SVG, the graphs can be zoomed and moved with the mouse (`svgpan.js`).',
        'Com SVG, os grafos podem ser ampliados e movidos com o rato (`svgpan.js`).'),
    'DOT_PATH': (
        'Folder of `dot.exe` (`C:\\Program Files\\Graphviz\\bin`). Empty means it is on the `PATH`.',
        'Pasta do `dot.exe` (`C:\\Program Files\\Graphviz\\bin`). Vazio significa que está no `PATH`.'),
    'DOTFILE_DIRS': (
        'Folders with `.dot` files that `\\dotfile` includes.',
        'Pastas com ficheiros `.dot` que `\\dotfile` inclui.'),
    'DOT_GRAPH_MAX_NODES': (
        'Maximum number of nodes of a graph; a bigger graph is cut and a red box says so.',
        'Número máximo de nós de um grafo; um grafo maior é cortado e uma caixa vermelha di-lo.'),
    'MAX_DOT_GRAPH_DEPTH': (
        'Maximum distance from the root node (0 is no limit). 1 or 2 speeds up big projects.',
        'Distância máxima ao nó raiz (0 é sem limite). 1 ou 2 acelera projetos grandes.'),
    'GENERATE_LEGEND': (
        'Writes the "Graph Legend" page that explains the boxes and arrows.',
        'Escreve a página "Legenda dos grafos" que explica as caixas e as setas.'),
    'DOT_CLEANUP': (
        'Deletes the `.dot` files after the images are made. NO keeps them to debug.',
        'Apaga os ficheiros `.dot` depois de as imagens estarem feitas. NO mantém-nos para depurar.'),

    # ----------------------------------------------------------------- Pascal
    'PASCAL_DIALECT': (
        'Delphi or FPC: the symbols that are defined (`DELPHI`, `FPC`, `UNICODE`...), the language mode and the keywords.',
        'Delphi ou FPC: os símbolos que ficam definidos (`DELPHI`, `FPC`, `UNICODE`...), o modo da linguagem e as palavras-chave.'),
    'PASCAL_PLATFORM': (
        'Target platform (`Win32`, `Win64`, `Linux64`, `macOS`, `iOS`, `Android`): defines `MSWINDOWS`, `LINUX`, `CPUX64`, ... '
        'so the code between `{$IFDEF}` is the one of that platform.',
        'Plataforma de destino (`Win32`, `Win64`, `Linux64`, `macOS`, `iOS`, `Android`): define `MSWINDOWS`, `LINUX`, `CPUX64`, ... '
        'para que o código entre `{$IFDEF}` seja o dessa plataforma.'),
    'PASCAL_UNIT_SCOPES': (
        'The unit scope names tried in front of a unit name (`UNITSCOPENAME` of the compiler): `Classes` refers to '
        '`System.Classes`.',
        'Os nomes de âmbito de unit tentados à frente do nome de uma unit (`UNITSCOPENAME` do compilador): `Classes` refere-se a '
        '`System.Classes`.'),
    'PASCAL_XMLDOC': (
        'Also reads the XML documentation of Delphi: `/// <summary>`, `<param>`, `<returns>`, `<see cref>`.',
        'Lê também a documentação XML do Delphi: `/// <summary>`, `<param>`, `<returns>`, `<see cref>`.'),
    'PASCAL_PARSE_DFM': (
        'Reads the forms `.dfm` and `.fmx` (text and binary) and writes a page with the component tree of each.',
        'Lê os formulários `.dfm` e `.fmx` (texto e binário) e escreve uma página com a árvore de componentes de cada um.'),
    'PASCAL_DFM_PROPERTIES': (
        'The page of a form also has the values of the properties of each component; NO lists only the class, caption and '
        'event handlers. Needs `PASCAL_PARSE_DFM`.',
        'A página de um formulário tem também os valores das propriedades de cada componente; NO lista só a classe, o '
        'título e os tratadores de eventos. Precisa de `PASCAL_PARSE_DFM`.'),
    'DELPHI_PROJECT': (
        'Delphi `.dpr`, `.dpk`, `.dproj`, `.groupproj` or Lazarus `.lpi`, `.lpk` files: the source files, search paths '
        'and conditional defines are taken from them.',
        'Ficheiros Delphi `.dpr`, `.dpk`, `.dproj`, `.groupproj` ou Lazarus `.lpi`, `.lpk`: os ficheiros fonte, caminhos de '
        'pesquisa e símbolos condicionais são tirados deles.'),
}
