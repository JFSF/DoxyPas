# DoxyPas

Gerador de documentação para **Object Pascal**: fontes Delphi, Free Pascal e Lazarus. É escrito inteiramente em Delphi e
baseia-se no [Doxygen](https://github.com/doxygen/doxygen) (o Doxyfile, os comentários de documentação e o aspeto da
saída são os do Doxygen), mas lê Pascal: units, classes, records, interfaces, object types, helpers, genéricos, rotinas,
propriedades, constantes, enumerações e os formulários (`.dfm`, `.fmx`). Licença GPL-2.0 (ver `LICENSE`).
English: [README.md](README.md).

![Exemplo de uma página gerada](docs/images/class.png)

## Documentação

* Guia do utilizador: [Português](docs/pt/GUIA_DO_UTILIZADOR.md) · [English](docs/en/USER_GUIDE.md)
* Referência das 221 opções: [Português](docs/pt/OPCOES.md) · [English](docs/en/OPTIONS.md)
* Projeto de exemplo usado nas imagens: [`docs/example`](docs/example)

## O que lê

* Ficheiros fonte `*.pas *.dpr *.dpk *.pp *.p *.lpr` (opção `FILE_PATTERNS`) e os formulários `*.dfm *.fmx` (texto e
  binário) com `PASCAL_PARSE_DFM`.
* Projetos Delphi (`.dproj`, `.groupproj`) e Lazarus (`.lpi`, `.lpk`) com `DELPHI_PROJECT`: os ficheiros, os símbolos
  condicionais e os caminhos de pesquisa vêm do projeto.
* Comentários de documentação do Doxygen (`///`, `{**` ... `}`, `(**` ... `*)`, `//!<`, `{!<` ... `}`, `\brief`, `\param`, ...)
  e o XMLDoc do Delphi (`/// <summary>`, ...) com `PASCAL_XMLDOC`.
* Compilação condicional: `PASCAL_DIALECT` e `PASCAL_PLATFORM` escolhem os símbolos definidos; `PREDEFINED` acrescenta
  outros; `INCLUDE_PATH` é onde se procura `{$I ficheiro}`.

## O que escreve

HTML (com pesquisa, árvore de navegação, navegador de código e grafos de chamadas e dependências através do `dot`),
LaTeX/PDF, XML (o do Doxygen), SQLite, ficheiros de etiquetas e os ficheiros para um CHM. O texto das páginas pode estar
em inglês, português, brasileiro, espanhol, francês, alemão, italiano, holandês, polaco, russo, chinês ou japonês
(`OUTPUT_LANGUAGE`). As secções usam os termos do Pascal: units, tipos, constantes, rotinas, métodos, métodos de classe,
campos, propriedades e as visibilidades public, published, protected, strict protected, private e strict private.
`LAYOUT_FILE` (ver `doxypas -l`) altera as páginas.

## Utilização

    doxypas -g Doxyfile        # um Doxyfile com as opções do Pascal e a sua documentação
    doxypas Doxyfile           # gera a documentação
    DoxyPasGui.exe Doxyfile    # Windows: editar as opções, executar, abrir o resultado (acrescente /run para executar logo)

As pastas `__history`, `__recovery` (Delphi) e `backup` (Lazarus) ficam de fora por omissão.

## Compilar

Precisa do Delphi 13 (RAD Studio 37.0). Numa linha de comandos:

    build.bat            # compila src\DoxyPas.dpr para Win32, Win64 e Linux64, e a GUI para Win32, Win64
    build.bat test       # compila e corre os testes DUnitX (Win32, Win64)
    build.bat gen        # regenera as opções e os recursos

A saída vai para `build\<plataforma>\`.

## Opções e recursos

`resources\config\config.xml` é a tabela de opções (a do Doxygen, sem as opções de C/C++ e de outras linguagens, e com os
valores por omissão do Pascal); `build.bat gen` regenera `src\Config\DoxyPas.Config.Options.pas` a partir dela e de
`config_pascal.xml` (as opções do DoxyPas: `PASCAL_*`, `DELPHI_PROJECT`). As opções que foram retiradas são obsoletas: um
Doxyfile que as tenha recebe um aviso e `doxypas -u` retira-as.
