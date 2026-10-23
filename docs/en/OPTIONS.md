# DoxyPas — Options reference

[Português](../pt/OPCOES.md) · [User guide](USER_GUIDE.md) · [README](../../README.md)

The DoxyPas Doxyfile has **221 options**, all of them implemented. This page explains each one. To write a Doxyfile with all of them and their documentation: `doxypas -g Doxyfile`; to list only the ones you changed: `doxypas -x Doxyfile`. The defaults below are the ones of `doxypas -g`.

![Options per group](../images/options_by_group.svg)

Each line of the Doxyfile is `OPTION = value`. The options of type *list* take several values separated by spaces (or `+=` to append) and the ones of type *YES/NO* take `YES` or `NO`. A `#` starts a comment.

## Contents

* [Project](#project) (36)
* [Build](#build) (32)
* [Messages](#messages) (12)
* [Input](#input) (19)
* [Source browser](#source-browser) (7)
* [Index](#index) (2)
* [HTML output](#html-output) (45)
* [LaTeX output](#latex-output) (17)
* [XML output](#xml-output) (3)
* [SQLite output](#sqlite-output) (2)
* [Preprocessor](#preprocessor) (2)
* [External documentation](#external-documentation) (5)
* [Graphs (Graphviz dot)](#graphs-graphviz-dot) (32)
* [Object Pascal](#object-pascal) (7)

## Project

Name, output folder, language and the general style of the comments.

| Option | Type | Default | What it does |
|---|---|---|---|
| `DOXYFILE_ENCODING` | text | `UTF-8` | Encoding of the Doxyfile itself, for the text that follows this line. Text before it is always UTF-8. |
| `PROJECT_NAME` | text | `"My Project"` | Name of the project. It is the title of the pages and of the LaTeX book. Use quotes if it has spaces. |
| `PROJECT_NUMBER` | text | — | Version or revision number, shown next to the name. Useful to tell archived documentations apart. |
| `PROJECT_BRIEF` | text | — | One-line description shown under the project name at the top of every page. Keep it short. |
| `PROJECT_LOGO` | text | — | Image shown in the header (at most 55 pixels high and 200 wide). It is copied to the output folder. |
| `PROJECT_ICON` | text | — | Icon of the browser tab of the HTML pages (favicon). It is copied to the output folder. |
| `OUTPUT_DIRECTORY` | text | — | Folder where everything is written; each format goes into its own sub-folder (`html`, `latex`, `xml`, ...). A relative path is relative to where DoxyPas is started. Empty means the current folder. |
| `CREATE_SUBDIRS` | YES/NO | `NO` | Spreads the generated files over up to 4096 sub-folders (`d0/d00/`...). Only for huge projects, when one folder with tens of thousands of files makes the file system slow. |
| `CREATE_SUBDIRS_LEVEL` | number | `8` | How many sub-folders are made when `CREATE_SUBDIRS = YES`: level 0 is 16 folders and every level doubles it (8, the maximum, is 4096). |
| `ALLOW_UNICODE_NAMES` | YES/NO | `NO` | YES keeps non-ASCII letters in the names of the generated files; NO escapes them (`_xE3_x81_x84`). |
| `OUTPUT_LANGUAGE` | choice | `English` | Language of the fixed texts of the pages ("Public Methods", "Class Reference", ...). DoxyPas has translations for English, Portuguese, Brazilian, Spanish, French, German, Italian, Dutch, Polish, Russian, Chinese and Japanese; the texts that are not translated stay in English. Values: `Afrikaans`, `Arabic`, `Armenian`, `Brazilian`, `Bulgarian`, `Catalan` …. |
| `BRIEF_MEMBER_DESC` | YES/NO | `YES` | YES shows the brief description of each member in the lists of members (like Javadoc). NO shows only the names. |
| `REPEAT_BRIEF` | YES/NO | `YES` | YES puts the brief description in front of the detailed one in the member documentation. |
| `ABBREVIATE_BRIEF` | list | `"The $name class" "The $name widget" "The $name file" …` | Phrases that are removed from the start of a brief description in the lists, so "The TFoo class implements X" is listed as "implements X". `$name` stands for the name of the entity. |
| `ALWAYS_DETAILED_SEC` | YES/NO | `NO` | With `REPEAT_BRIEF = YES`, also creates the "Detailed Description" section when there is only a brief one. |
| `INLINE_INHERITED_MEMB` | YES/NO | `NO` | Shows the inherited members in the page of each class as if they were its own, instead of the link "List of all members". |
| `FULL_PATH_NAMES` | YES/NO | `YES` | YES writes the full path of a file in the lists; NO writes the shortest path that is still unique. |
| `STRIP_FROM_PATH` | list | — | Paths that are cut from the start of the file names shown in the lists (`STRIP_FROM_PATH = C:\src\` shows `Core\Utils.pas`). Empty means the folder where DoxyPas is run. |
| `JAVADOC_AUTOBRIEF` | YES/NO | `YES` | The first sentence (up to the first dot) of a `{** ... }` or `/** ... */` comment is the brief description; with NO you need `\brief`. |
| `JAVADOC_BANNER` | YES/NO | `NO` | YES treats a line such as `{*****...` as the start of a Javadoc-style comment (a "banner"); NO leaves it as a normal comment. |
| `QT_AUTOBRIEF` | YES/NO | `NO` | Same as `JAVADOC_AUTOBRIEF` for the Qt style comments (`//!`). |
| `INHERIT_DOCS` | YES/NO | `YES` | A member without documentation that overrides a documented one gets the documentation of the ancestor. |
| `SEPARATE_MEMBER_PAGES` | YES/NO | `NO` | Writes one page for each documented member instead of putting it in the page of its unit or class. |
| `TAB_SIZE` | number | `4` | Number of spaces that replace a tab in the code fragments. |
| `ALIASES` | list | — | Your own commands: `"name=text"`. With `"todoh=\todo (high)"` you can write `\todoh` in the comments. Use `^^` for a new line and `\1`, `\2` for arguments. |
| `MARKDOWN_SUPPORT` | YES/NO | `YES` | The comments are read as Markdown (lists, `code`, **bold**, tables, headings, links) and can still use Doxygen commands and HTML. |
| `MARKDOWN_STRICT` | YES/NO | `YES` | In the conflicts between Markdown and the Doxygen syntax (the backticks) the Markdown wins. |
| `TOC_INCLUDE_HEADINGS` | number | `6` | The Markdown headings up to this level (1-6) go into the table of contents of the page, even without an id. 0 turns it off. |
| `MARKDOWN_ID_STYLE` | choice | `DOXYGEN` | How the anchors of the Markdown headings are made: `DOXYGEN` or `GITHUB` (like the GitHub rendering, so that links of a `README.md` work in both). |
| `AUTOLINK_SUPPORT` | YES/NO | `YES` | Words that are the name of a documented class, unit or routine become links by themselves. Put `%` before a word (`%TList`) to avoid one link. |
| `AUTOLINK_IGNORE_WORDS` | list | — | Words that never become automatic links (for instance a class called `Name` or `Item`). |
| `DISTRIBUTE_GROUP_DOC` | YES/NO | `NO` | In a member group, the members without documentation reuse the one of the first member that has it. |
| `GROUP_NESTED_COMPOUNDS` | YES/NO | `NO` | A nested class or record goes to the same group (`\ingroup`) as the class that contains it. |
| `SUBGROUPING` | YES/NO | `YES` | Member groups of the same kind may become sub-groups of that section (for example inside "Public Methods"). |
| `NUM_PROC_THREADS` | number | `1` | Threads used to read the input: 1 (default) is single-threaded, 0 is one per core. |
| `TIMESTAMP` | choice | `NO` | Writes the date and/or time of the run in the footer: `NO`, `DATE`, `DATETIME` or `YES`. Keep NO to compare two runs with a diff tool. |

![OUTPUT_LANGUAGE = Portuguese: the fixed texts of the page are translated.](../images/pt.png)

*OUTPUT_LANGUAGE = Portuguese: the fixed texts of the page are translated.*

## Build

What is extracted from the sources, what is hidden and how the lists are sorted.

| Option | Type | Default | What it does |
|---|---|---|---|
| `EXTRACT_ALL` | YES/NO | `NO` | Documents everything, also what has no comment. Use it the first time you run DoxyPas on a project without documentation. It turns off the warnings of undocumented members. |
| `EXTRACT_PRIVATE` | YES/NO | `NO` | Includes the `private` and `strict private` members of the classes. |
| `EXTRACT_STATIC` | YES/NO | `NO` | Includes the routines, variables, constants and types that exist only in the `implementation` section of a unit. |
| `EXTRACT_LOCAL_CLASSES` | YES/NO | `YES` | Includes the classes, records and interfaces declared in the `implementation` section; NO keeps only the ones of the `interface` section. |
| `HIDE_UNDOC_MEMBERS` | YES/NO | `NO` | Hides the members that have no documentation. Without effect with `EXTRACT_ALL = YES`. |
| `HIDE_UNDOC_CLASSES` | YES/NO | `NO` | Hides the classes that have no documentation (for example in the class hierarchy). Without effect with `EXTRACT_ALL = YES`. |
| `HIDE_UNDOC_NAMESPACES` | YES/NO | `YES` | Hides the units that have no documentation from the lists of units. Without effect with `EXTRACT_ALL = YES`. |
| `HIDE_IN_BODY_DOCS` | YES/NO | `NO` | Hides the documentation blocks found inside the body of a routine. NO appends them to the detailed description. |
| `INTERNAL_DOCS` | YES/NO | `NO` | Includes the text that follows `\internal` (notes for the maintainers). NO leaves it out of the public manual. |
| `CASE_SENSE_NAMES` | choice | `NO` | Pascal is not case sensitive, so the default is `NO`: file names and links do not depend on the casing. `YES` keeps files that differ only in casing apart; `SYSTEM` follows the file system. |
| `HIDE_SCOPE_NAMES` | YES/NO | `NO` | YES shows `Create` instead of `TShape.Create`: the scope (unit, class) is not repeated. |
| `HIDE_COMPOUND_REFERENCE` | YES/NO | `NO` | YES removes "Class Reference" / "Unit Reference" from the titles of the pages. |
| `SHOW_INCLUDE_FILES` | YES/NO | `YES` | The page of a unit lists the units of its `uses` clause (and the ones that use it). |
| `INLINE_INFO` | YES/NO | `YES` | Marks the inline routines with `[inline]`. |
| `SORT_MEMBER_DOCS` | YES/NO | `YES` | Sorts the detailed documentation of the members by name. NO keeps the order of the declaration. |
| `SORT_BRIEF_DOCS` | YES/NO | `NO` | Sorts the brief lists of members and of classes by name. NO keeps the order of the declaration. |
| `SORT_MEMBERS_CTORS_1ST` | YES/NO | `NO` | Puts the constructors and destructors first in the lists of members. |
| `SORT_GROUP_NAMES` | YES/NO | `NO` | Sorts the groups (`\defgroup`) by name; NO keeps the order in which they are defined. |
| `SORT_BY_SCOPE_NAME` | YES/NO | `NO` | Sorts the class list by the full name (with the unit) instead of the class name only. |
| `GENERATE_TODOLIST` | YES/NO | `YES` | Creates the "Todo List" page with all the `\todo` commands. |
| `GENERATE_TESTLIST` | YES/NO | `YES` | Creates the "Test List" page with all the `\test` commands. |
| `GENERATE_BUGLIST` | YES/NO | `YES` | Creates the "Bug List" page with all the `\bug` commands. |
| `GENERATE_DEPRECATEDLIST` | YES/NO | `YES` | Creates the "Deprecated List" page with all the `\deprecated` commands. |
| `ENABLED_SECTIONS` | list | — | Labels of the conditional sections that are included: the text between `\if label` and `\endif` (or `\cond label` and `\endcond`). |
| `MAX_INITIALIZER_LINES` | number | `30` | Constants and variables whose initial value is longer than this number of lines show no value. 0 hides all of them. |
| `SHOW_USED_FILES` | YES/NO | `YES` | At the end of the page of a class, lists the files that were used to write it. |
| `SHOW_FILES` | YES/NO | `YES` | Creates the "Files" page (and its entry in the menu and in the tree). NO removes them. |
| `SHOW_NAMESPACES` | YES/NO | `YES` | Creates the "Units" page (and its entry in the menu and in the tree). NO removes them. |
| `FILE_VERSION_FILTER` | text | — | Program that gives the version of a file (for example one that calls `git log -1`). DoxyPas runs `program file` and uses the output; `$version` in `WARN_FORMAT` shows it. |
| `LAYOUT_FILE` | text | — | XML file that changes the pages: which sections exist, their order and their titles. Create the default one with `doxypas -l DoxygenLayout.xml` and edit it. |
| `CITE_BIB_FILES` | list | — | The `.bib` files with the references used by `\cite`. Needs `bibtex`. |
| `EXTERNAL_TOOL_PATH` | list | — | Folders added in front of `PATH` when DoxyPas runs external tools (`dot`, `latex`, `makeindex`, ...). |

![EXTRACT_PRIVATE = YES: the private field FRadius is documented too.](../images/private.png)

*EXTRACT_PRIVATE = YES: the private field FRadius is documented too.*

## Messages

Warnings and the log of the run.

| Option | Type | Default | What it does |
|---|---|---|---|
| `QUIET` | YES/NO | `NO` | No progress messages on the screen (warnings are controlled by `WARNINGS`). |
| `WARNINGS` | YES/NO | `YES` | Shows the warnings (on standard error, or in `WARN_LOGFILE`). Keep it on while you write the documentation. |
| `WARN_IF_UNDOCUMENTED` | YES/NO | `YES` | Warns about each member without documentation. Turned off by `EXTRACT_ALL`. |
| `WARN_IF_DOC_ERROR` | YES/NO | `YES` | Warns about errors in the comments: a `\param` for a parameter that does not exist, one parameter documented twice, a command used wrongly. |
| `WARN_IF_INCOMPLETE_DOC` | YES/NO | `YES` | Warns when only some of the parameters of a routine are documented. |
| `WARN_NO_PARAMDOC` | YES/NO | `NO` | Warns about documented routines that document none of their parameters or the result. |
| `WARN_IF_UNDOC_ENUM_VAL` | YES/NO | `NO` | Warns about the values of an enumeration that have no documentation. |
| `WARN_LAYOUT_FILE` | YES/NO | `YES` | Warns about problems in the file of `LAYOUT_FILE` (an element that is missing or wrong). |
| `WARN_AS_ERROR` | choice | `NO` | `NO`: warnings are only messages. `YES`: stops at the first warning. `FAIL_ON_WARNINGS`: runs to the end and returns a non-zero exit code if there was any warning (good for a CI build). `FAIL_ON_WARNINGS_PRINT`: the same, and prints the warnings at the end. |
| `WARN_FORMAT` | text | `"$file:$line: $text"` | Format of a warning, with `$file`, `$line`, `$text` (and `$version`). |
| `WARN_LINE_FORMAT` | text | `"at line $line of file $file"` | How a reference to another place is written inside the text of a warning (`$file` and `$line`). |
| `WARN_LOGFILE` | text | — | File that receives the warnings. Empty is standard error; `-` is standard output. |

## Input

Which files are read and how.

| Option | Type | Default | What it does |
|---|---|---|---|
| `INPUT` | list | — | Files and folders that have the sources, separated by spaces. Empty means the current folder. |
| `INPUT_ENCODING` | text | `UTF-8` | Character encoding of the sources. The default is UTF-8; a file that is not valid UTF-8 is read in the ANSI code page (the old Delphi sources). A byte order mark always wins. |
| `INPUT_FILE_ENCODING` | list | — | Encoding by file pattern, `pattern=encoding` (`*.pas=windows-1252`). It overrides `INPUT_ENCODING`. |
| `FILE_PATTERNS` | list | `*.pas *.dpr *.dpk …` | Patterns of the files that are read when `INPUT` has folders. The default has the Pascal sources and the forms (`*.pas *.dpr *.dpk *.pp *.p *.lpr *.dfm *.fmx`). |
| `RECURSIVE` | YES/NO | `NO` | Also searches the sub-folders of the folders of `INPUT`. |
| `EXCLUDE` | list | — | Files and folders that are left out of `INPUT`. |
| `EXCLUDE_SYMLINKS` | YES/NO | `NO` | Leaves out the files and folders that are symbolic links (Linux). |
| `EXCLUDE_PATTERNS` | list | `*/__history/* */__recovery/* */backup/*` | Patterns of files and folders that are left out, compared with the full path (`*/test/*`). The default leaves out the folders of the previous versions of Delphi (`__history`, `__recovery`) and Lazarus (`backup`). |
| `EXCLUDE_SYMBOLS` | list | — | Names (unit, class, routine; `*` is a wildcard) that are left out of the output. Example: `TInternal*`. |
| `EXAMPLE_PATH` | list | — | Folders with the files that `\include`, `\snippet` and `\example` read. |
| `EXAMPLE_PATTERNS` | list | `*` | Patterns of the files of `EXAMPLE_PATH`. Empty means all. |
| `EXAMPLE_RECURSIVE` | YES/NO | `NO` | Also searches the sub-folders of `EXAMPLE_PATH`. |
| `IMAGE_PATH` | list | — | Folders with the images used by `\image` (and by Markdown `![](x.png)`). |
| `INPUT_FILTER` | text | — | Program run on every source file before it is read: `program file`, and its standard output is what DoxyPas reads. Use it to convert or clean the sources. |
| `FILTER_PATTERNS` | list | — | Filters by file pattern, `pattern=program`. They win over `INPUT_FILTER` for the files that match. |
| `FILTER_SOURCE_FILES` | YES/NO | `NO` | The filter is also applied to the source files that the source browser shows. |
| `FILTER_SOURCE_PATTERNS` | list | — | Filters by pattern for the source browser only; `*.ext=` (no program) turns the filter off for it. |
| `USE_MDFILE_AS_MAINPAGE` | text | — | A Markdown file (for instance your `README.md`) that becomes the main page (`index.html`). A first line `# Title` is the title of the page. |
| `IMPLICIT_DIR_DOCS` | YES/NO | `YES` | A `README.md` in a sub-folder becomes the documentation of that folder (page "Directory Hierarchy"), unless it starts with `\dir`, `\page` or `\mainpage`. |

## Source browser

The listing of the sources and the cross references.

| Option | Type | Default | What it does |
|---|---|---|---|
| `SOURCE_BROWSER` | YES/NO | `NO` | Writes a page with the source of every file, with the names linked to the documentation and the other way round ("Go to the source code of this file"). |
| `INLINE_SOURCES` | YES/NO | `NO` | Shows the body of each routine inside its documentation. |
| `STRIP_CODE_COMMENTS` | YES/NO | `YES` | Removes the documentation comments from the source fragments (they are already in the page). |
| `REFERENCED_BY_RELATION` | YES/NO | `NO` | For each routine, property or variable, lists the documented routines that use it ("Referenced by"). |
| `REFERENCES_RELATION` | YES/NO | `NO` | For each routine, lists the documented entities that it uses ("References"). |
| `REFERENCES_LINK_SOURCE` | YES/NO | `YES` | The links of the two lists above go to the source code; NO sends them to the documentation. |
| `SOURCE_TOOLTIPS` | YES/NO | `YES` | The names in the source pages show a tooltip with the declaration and the brief description. Turn it off to make big pages smaller. |

![SOURCE_BROWSER = YES: the listing of a unit, with links and folding.](../images/source.png)

*SOURCE_BROWSER = YES: the listing of a unit, with links and folding.*

![INLINE_SOURCES = YES: the body of each routine is shown in its documentation.](../images/inline.png)

*INLINE_SOURCES = YES: the body of each routine is shown in its documentation.*

## Index

The alphabetical index of the classes.

| Option | Type | Default | What it does |
|---|---|---|---|
| `ALPHABETICAL_INDEX` | YES/NO | `YES` | Creates the alphabetical index of the classes ("Class Index"). Useful when there are many. |
| `IGNORE_PREFIX` | list | — | Prefixes that are skipped in the alphabetical index: with `T I E`, `TButton` is listed under B. A one-letter prefix is removed only before an upper case letter. |

## HTML output

Look and behaviour of the HTML pages, search, tree view, formulas and CHM.

| Option | Type | Default | What it does |
|---|---|---|---|
| `GENERATE_HTML` | YES/NO | `YES` | Writes the HTML output. |
| `HTML_OUTPUT` | text | `html` | Sub-folder of `OUTPUT_DIRECTORY` for the HTML files. |
| `HTML_FILE_EXTENSION` | text | `.html` | Extension of the pages (`.html`, `.htm`, `.php`...). |
| `HTML_HEADER` | text | — | Your own header for every page (an HTML file with the markers of DoxyPas). Empty is the standard one. `resources\html\header.html` is a good start. |
| `HTML_FOOTER` | text | — | Your own footer for every page. Empty is the standard one. `resources\html\footer.html` is a good start. |
| `HTML_STYLESHEET` | text | — | Replaces the whole style sheet. Prefer `HTML_EXTRA_STYLESHEET`, which does not break when the standard one changes. |
| `HTML_EXTRA_STYLESHEET` | list | — | Extra style sheets loaded after the standard one, to change details of the look. They are copied to the output. |
| `HTML_EXTRA_FILES` | list | — | Other files (images, scripts) that are copied to the HTML folder as they are. |
| `HTML_COLORSTYLE` | choice | `AUTO_LIGHT` | `LIGHT` or `DARK` fixed, `AUTO_LIGHT`/`AUTO_DARK` follow the setting of the system (and start light/dark), `TOGGLE` adds a button to switch. |
| `HTML_COLORSTYLE_HUE` | number | `220` | Main color of the pages as an angle of the color wheel: 0 red, 60 yellow, 120 green, 180 cyan, 220 blue (default), 300 purple. |
| `HTML_COLORSTYLE_SAT` | number | `100` | Saturation of the colors: 0 is gray, 255 the most vivid. |
| `HTML_COLORSTYLE_GAMMA` | number | `80` | Gamma of the luminance: below 100 is lighter, above 100 is darker. |
| `HTML_DYNAMIC_MENUS` | YES/NO | `YES` | The menu at the top is made with JavaScript (drop-down lists). NO writes static tabs in every page, for browsers without JavaScript. |
| `HTML_DYNAMIC_SECTIONS` | YES/NO | `NO` | Some sections can be shown and hidden after the page loads. |
| `HTML_CODE_FOLDING` | YES/NO | `YES` | In the source pages, the classes and routines can be folded and expanded. |
| `HTML_COPY_CLIPBOARD` | YES/NO | `YES` | Shows a button at the top right of the code fragments that copies them. Works with `https:` and `file:`. |
| `HTML_PROJECT_COOKIE` | text | — | Name under which the browser stores the settings of the pages (tree width, color). Give each project its own to keep them apart. |
| `HTML_INDEX_NUM_ENTRIES` | number | `100` | Preferred number of entries that the trees open with; 1 starts all collapsed, 0 expands all. |
| `GENERATE_HTMLHELP` | YES/NO | `NO` | Also writes the project files for Microsoft HTML Help (`index.hhp`, `.hhc`, `.hhk`) to make a `.chm`. |
| `CHM_FILE` | text | — | Name of the `.chm` file; a path puts it outside the HTML folder. |
| `HHC_LOCATION` | text | — | Full path of `hhc.exe`. If it is set, DoxyPas runs the compiler on `index.hhp`. |
| `GENERATE_CHI` | YES/NO | `NO` | Writes the index of the CHM in a separate `.chi` file. |
| `CHM_INDEX_ENCODING` | text | — | Encoding of the index, contents and project files of the CHM (for example `windows-1252`). |
| `BINARY_TOC` | YES/NO | `NO` | A binary table of contents in the CHM, with the Previous and Next buttons. |
| `TOC_EXPAND` | YES/NO | `NO` | Adds the members of the groups to the table of contents of the CHM and to the tree. |
| `SITEMAP_URL` | text | — | Public address where you will publish the HTML. If it is set, `sitemap.xml` is written for the search engines. |
| `DISABLE_INDEX` | YES/NO | `NO` | Removes the tabs/menu at the top. Do it only if you keep the tree view or if you write your own navigation. |
| `GENERATE_TREEVIEW` | YES/NO | `YES` | Shows the navigation tree in a panel at the left of every page. |
| `PAGE_OUTLINE_PANEL` | YES/NO | `YES` | Shows a panel at the right with the outline of the page (sections and members). Needs `GENERATE_TREEVIEW`. |
| `FULL_SIDEBAR` | YES/NO | `NO` | The left panel takes the full height of the window (like Read the Docs); the title and logo stay in the panel. Needs `GENERATE_TREEVIEW`. |
| `ENUM_VALUES_PER_LINE` | number | `4` | How many enumeration values are put on one line of the overview; 0 hides the values there. |
| `SHOW_ENUM_VALUES` | YES/NO | `NO` | Shows the numeric value (`= 2`) next to each enumeration name. |
| `TREEVIEW_WIDTH` | number | `250` | Initial width in pixels of the tree panel (the user can drag it). |
| `EXT_LINKS_IN_WINDOW` | YES/NO | `NO` | Links to symbols of other projects (tag files) open in a new window. |
| `OBFUSCATE_EMAILS` | YES/NO | `YES` | Hides the e-mail addresses from the robots that harvest them. |
| `HTML_FORMULA_FORMAT` | choice | `png` | Formulas as `png` or `svg` images (SVG needs `pdf2svg` or Inkscape). Ignored with MathJax. |
| `FORMULA_FONTSIZE` | number | `10` | Font size of the formulas that are images. |
| `FORMULA_MACROFILE` | text | — | File with `\newcommand` definitions to use in the formulas. |
| `USE_MATHJAX` | YES/NO | `NO` | Formulas (`\f$ ... \f$`) are drawn by the browser with MathJax instead of pre-rendered images. Does not need LaTeX. |
| `MATHJAX_VERSION` | choice | `MathJax_2` | MathJax version: 2, 3 or 4. Values: `MathJax_2`, `MathJax_3`, `MathJax_4`. |
| `MATHJAX_FORMAT` | choice | `HTML-CSS` | Output format of MathJax (`HTML-CSS`, `NativeMML`, `chtml`, `SVG`). |
| `MATHJAX_RELPATH` | text | — | Where MathJax is, relative to the HTML folder, or a URL of a CDN. |
| `MATHJAX_EXTENSIONS` | list | — | MathJax extensions to load (for example `ams`). |
| `MATHJAX_CODEFILE` | text | — | JavaScript file with code that runs when MathJax starts. |
| `SEARCHENGINE` | YES/NO | `YES` | Adds the search box. It works in the browser, without a server. Turn it off for the CHM (it has its own). |

![HTML_COLORSTYLE = DARK.](../images/dark.png)

*HTML_COLORSTYLE = DARK.*

![HTML_COLORSTYLE_HUE = 20 (orange instead of blue).](../images/hue.png)

*HTML_COLORSTYLE_HUE = 20 (orange instead of blue).*

![GENERATE_TREEVIEW = NO: no navigation tree.](../images/notree.png)

*GENERATE_TREEVIEW = NO: no navigation tree.*

![FULL_SIDEBAR = YES: the left panel takes the full height.](../images/sidebar.png)

*FULL_SIDEBAR = YES: the left panel takes the full height.*

## LaTeX output

The LaTeX sources and the PDF.

| Option | Type | Default | What it does |
|---|---|---|---|
| `GENERATE_LATEX` | YES/NO | `YES` | Writes the LaTeX output (`refman.tex`, one `.tex` file per unit and class, the graphs as PDF) and a `Makefile` and `make.bat` to build the PDF. |
| `LATEX_OUTPUT` | text | `latex` | Sub-folder of `OUTPUT_DIRECTORY` for the LaTeX files. |
| `LATEX_CMD_NAME` | text | — | LaTeX program to run (`latex`, `pdflatex`, `xelatex`...). Empty chooses by `USE_PDFLATEX`. |
| `MAKEINDEX_CMD_NAME` | text | `makeindex` | Program that makes the index, as written in the `make.bat`/`Makefile`. |
| `LATEX_MAKEINDEX_CMD` | text | `makeindex` | The same program, as written inside the `.tex` file. |
| `COMPACT_LATEX` | YES/NO | `NO` | A more compact document (article-like, without parts), for small projects. |
| `PAPER_TYPE` | choice | `a4` | Paper: `a4`, `a3`, `letter`, `legal` or `executive`. |
| `EXTRA_PACKAGES` | list | — | LaTeX packages added to the document (`times`, `amsmath`, ...). |
| `LATEX_HEADER` | text | — | Your own LaTeX header (everything up to the first chapter). Empty is the standard one. |
| `LATEX_FOOTER` | text | — | Your own LaTeX footer (everything after the last chapter). Empty is the standard one. |
| `LATEX_EXTRA_STYLESHEET` | list | — | Extra `.sty` files that are copied and loaded after the standard ones. |
| `LATEX_EXTRA_FILES` | list | — | Other files (images, ...) copied as they are to the LaTeX folder. |
| `PDF_HYPERLINKS` | YES/NO | `YES` | The LaTeX is prepared to make a PDF with links, instead of page references. |
| `USE_PDFLATEX` | YES/NO | `YES` | The PDF is made directly with `pdflatex` (better quality) instead of `latex` + `dvips` + `ps2pdf`. |
| `LATEX_BATCHMODE` | choice | `NO` | What LaTeX does on an error: `NO` asks, `YES`/`BATCH` does not stop, `NON_STOP`, `SCROLL`, `ERROR_STOP`. |
| `LATEX_HIDE_INDICES` | YES/NO | `NO` | Leaves out the index chapters (file index, class index, ...) from the book. |
| `LATEX_BIB_STYLE` | text | `plainnat` | BibTeX style of the bibliography (`plainnat`, `ieeetr`, ...). |

## XML output

The XML files with the whole structure of the code.

| Option | Type | Default | What it does |
|---|---|---|---|
| `GENERATE_XML` | YES/NO | `NO` | Writes the XML output: one file per unit, class and page, plus `index.xml`, with the schemas `.xsd`. |
| `XML_OUTPUT` | text | `xml` | Sub-folder of `OUTPUT_DIRECTORY` for the XML files. |
| `XML_PROGRAMLISTING` | YES/NO | `YES` | Includes the source listings (with highlighting and links) in the XML. It makes it much bigger. |

## SQLite output

The SQL script with the symbols.

| Option | Type | Default | What it does |
|---|---|---|---|
| `GENERATE_SQLITE3` | YES/NO | `NO` | Writes an SQL script (`doxygen_sqlite3.sql`) that creates the SQLite tables with the symbols and their relations; load it with the `sqlite3` tool and query with SQL. |
| `SQLITE3_OUTPUT` | text | `sqlite3` | Sub-folder of `OUTPUT_DIRECTORY` for the SQL script. |

## Preprocessor

Conditional compilation: defines and include files.

| Option | Type | Default | What it does |
|---|---|---|---|
| `INCLUDE_PATH` | list | — | Folders searched for `{$I file}` and `{$INCLUDE file}`, after the folder of the file that includes. The folders of `DELPHI_PROJECT` are added. Not recursive. |
| `PREDEFINED` | list | — | Conditional symbols that are defined before each file is read (like the conditional defines of Delphi or `-d` of Free Pascal): `DEBUG`, `USE_SSL`. The code of `{$IFDEF}` is the one the compiler would see. |

## External documentation

Tag files, to link to the documentation of other projects.

| Option | Type | Default | What it does |
|---|---|---|---|
| `TAGFILES` | list | — | Tag files of other projects, `file=location` (a folder or URL), so that names of those projects become links. |
| `GENERATE_TAGFILE` | text | — | Writes a tag file with this name, so that other projects can link to this one. |
| `ALLEXTERNALS` | YES/NO | `NO` | Lists all the external classes in the class index; NO lists only the inherited ones. |
| `EXTERNAL_GROUPS` | YES/NO | `YES` | Lists the groups of the external projects in the index of topics. |
| `EXTERNAL_PAGES` | YES/NO | `YES` | Lists the pages of the external projects in the index of related pages. |

## Graphs (Graphviz dot)

Class, collaboration, unit, call and directory graphs.

| Option | Type | Default | What it does |
|---|---|---|---|
| `HIDE_UNDOC_RELATIONS` | YES/NO | `YES` | The graphs do not show the relations whose target has no documentation. |
| `HAVE_DOT` | YES/NO | `NO` | Uses Graphviz `dot` to draw the graphs. Without it, only the inheritance diagrams are made (by DoxyPas itself, see `CLASS_GRAPH`). All the other options of this group need it. |
| `DOT_NUM_THREADS` | number | `0` | How many `dot` processes run at the same time; 0 is one per processor. |
| `DOT_BATCH_SIZE` | number | `50` | How many graphs one run of `dot` draws. 1 starts a process per graph (slow with many cores). |
| `DOT_COMMON_ATTR` | text | `"fontname=Helvetica,fontsize=10"` | Attributes of nodes, edges and labels of all graphs (`fontname=Helvetica,fontsize=10`). |
| `DOT_EDGE_ATTR` | text | `"labelfontname=Helvetica,labelfontsize=10"` | Attributes added to the edges (arrows): `arrowhead=open,arrowsize=0.5`. |
| `DOT_NODE_ATTR` | text | `"shape=box,height=0.2,width=0.4"` | Attributes added to the nodes: `shape=box,height=0.2,width=0.4`, or `shape=plain` for no box. |
| `DOT_FONTPATH` | text | — | Folder where `dot` finds the fonts named in the attributes. |
| `CLASS_GRAPH` | choice | `YES` | The inheritance diagram of each class. `YES`/`GRAPH` use `dot` (if `HAVE_DOT`), `BUILTIN` the generator of DoxyPas, `TEXT` a list of text, `NO` none. |
| `COLLABORATION_GRAPH` | YES/NO | `YES` | The collaboration diagram of each class: inheritance and the fields and properties that refer to other classes. |
| `GROUP_GRAPHS` | YES/NO | `YES` | The dependency graph between groups (`\defgroup`). |
| `UML_LOOK` | YES/NO | `NO` | Class diagrams in UML style: boxes with the fields and methods and open arrows. |
| `UML_LIMIT_NUM_FIELDS` | number | `10` | With `UML_LOOK`, at most this number of fields and methods per box (0 is no limit; it may exceed by 50%). |
| `UML_MAX_EDGE_LABELS` | number | `10` | With `UML_LOOK`, at most this number of labels on the edges (0 is no limit). |
| `DOT_UML_DETAILS` | choice | `NO` | With `UML_LOOK`: `NO` shows names only, `YES` adds the types and parameters, `NONE` shows no members. |
| `DOT_WRAP_THRESHOLD` | number | `17` | Length of a line of text in a node before it is wrapped. |
| `TEMPLATE_RELATIONS` | YES/NO | `NO` | The graphs show the relations between generic types and their instances. |
| `INCLUDE_GRAPH` | YES/NO | `YES` | The graph of the units that a unit uses (its `uses` clause), directly and indirectly. |
| `INCLUDED_BY_GRAPH` | YES/NO | `YES` | The graph of the units that use a unit. |
| `CALL_GRAPH` | YES/NO | `NO` | For each routine, the graph of the routines that it calls. Makes the run much slower. |
| `CALLER_GRAPH` | YES/NO | `NO` | For each routine, the graph of the routines that call it. As slow as `CALL_GRAPH`. |
| `GRAPHICAL_HIERARCHY` | YES/NO | `YES` | Also writes the class hierarchy as a graph ("graphical class hierarchy"). |
| `DIRECTORY_GRAPH` | YES/NO | `YES` | The graph of dependencies between the folders of the project. |
| `DIR_GRAPH_MAX_DEPTH` | number | `1` | How many levels of sub-folders the directory graph draws, nested inside their parents. |
| `DOT_IMAGE_FORMAT` | choice | `svg` | `svg` (default): vector, and the nodes are links. `png`, `jpg`, `gif`: bitmaps without links; the forms with `:` choose the renderer of `dot`. |
| `INTERACTIVE_SVG` | YES/NO | `NO` | With SVG, the graphs can be zoomed and moved with the mouse (`svgpan.js`). |
| `DOT_PATH` | text | — | Folder of `dot.exe` (`C:\Program Files\Graphviz\bin`). Empty means it is on the `PATH`. |
| `DOTFILE_DIRS` | list | — | Folders with `.dot` files that `\dotfile` includes. |
| `DOT_GRAPH_MAX_NODES` | number | `50` | Maximum number of nodes of a graph; a bigger graph is cut and a red box says so. |
| `MAX_DOT_GRAPH_DEPTH` | number | `0` | Maximum distance from the root node (0 is no limit). 1 or 2 speeds up big projects. |
| `GENERATE_LEGEND` | YES/NO | `YES` | Writes the "Graph Legend" page that explains the boxes and arrows. |
| `DOT_CLEANUP` | YES/NO | `YES` | Deletes the `.dot` files after the images are made. NO keeps them to debug. |

![The default: inheritance and collaboration graphs made by dot (an SVG, so the boxes are links).](../images/class.png)

*The default: inheritance and collaboration graphs made by dot (an SVG, so the boxes are links).*

![UML_LOOK = YES and DOT_UML_DETAILS = YES.](../images/uml.png)

*UML_LOOK = YES and DOT_UML_DETAILS = YES.*

![HAVE_DOT = NO: only the built-in inheritance diagram.](../images/nodot.png)

*HAVE_DOT = NO: only the built-in inheritance diagram.*

![CALL_GRAPH = YES: what TRectangle.Bounding calls.](../images/callgraph.png)

*CALL_GRAPH = YES: what TRectangle.Bounding calls.*

![CALLER_GRAPH = YES: who calls TCircle.Create.](../images/callergraph.png)

*CALLER_GRAPH = YES: who calls TCircle.Create.*

## Object Pascal

The options of DoxyPas that Doxygen does not have: dialect, platform, forms and projects.

| Option | Type | Default | What it does |
|---|---|---|---|
| `PASCAL_DIALECT` | choice | `Delphi` | Delphi or FPC: the symbols that are defined (`DELPHI`, `FPC`, `UNICODE`...), the language mode and the keywords. |
| `PASCAL_PLATFORM` | choice | `Win64` | Target platform (`Win32`, `Win64`, `Linux64`, `macOS`, `iOS`, `Android`): defines `MSWINDOWS`, `LINUX`, `CPUX64`, ... so the code between `{$IFDEF}` is the one of that platform. |
| `PASCAL_UNIT_SCOPES` | list | `System System.Win Winapi …` | The unit scope names tried in front of a unit name (`UNITSCOPENAME` of the compiler): `Classes` refers to `System.Classes`. |
| `PASCAL_XMLDOC` | YES/NO | `YES` | Also reads the XML documentation of Delphi: `/// <summary>`, `<param>`, `<returns>`, `<see cref>`. |
| `PASCAL_PARSE_DFM` | YES/NO | `YES` | Reads the forms `.dfm` and `.fmx` (text and binary) and writes a page with the component tree of each. |
| `PASCAL_DFM_PROPERTIES` | YES/NO | `YES` | The page of a form also has the values of the properties of each component; NO lists only the class, caption and event handlers. Needs `PASCAL_PARSE_DFM`. |
| `DELPHI_PROJECT` | list | — | Delphi `.dpr`, `.dpk`, `.dproj`, `.groupproj` or Lazarus `.lpi`, `.lpk` files: the source files, search paths and conditional defines are taken from them. |

