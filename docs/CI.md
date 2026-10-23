# Continuous integration and releases / Integração contínua e releases

## English

GitHub's hosted runners do not have Delphi, so the workflows in `.github/workflows` use two kinds of job:

* `docs` (hosted, `ubuntu-latest`): checks the links of the documentation (`tools/docs/check_links.py`).
* `delphi` and `release` (**self-hosted** runner with the labels `self-hosted`, `windows`, `delphi13`): `build.bat`,
  `build.bat test` and the release zip.

To set the runner up: in the repository, *Settings > Actions > Runners > New self-hosted runner* (Windows x64), install it on a
machine with RAD Studio 13 (and optionally the Linux64 SDK and Graphviz) and add the label `delphi13` when it asks for labels.
Pull requests from forks are not run on that machine on purpose.

**Making a release:** set `DoxyPasVersion` (`src/Core/DoxyPas.Core.Version.pas`), the version in `src/DoxyPas.rc`,
`src/Gui/Styles.rc`, the `.dproj` files and `boss.json`, write the notes in `CHANGELOG.md`, then

```
git tag v1.0.0
git push origin v1.0.0
```

The `release` workflow checks that the tag matches the version, builds, tests, and attaches `DoxyPas-<version>.zip` to a GitHub
release. Without the runner, build the zip by hand (`build.bat`, `powershell tools\release\make_zip.ps1`) and
`gh release create v1.0.0 build\release\DoxyPas-1.0.0.zip --notes-file CHANGELOG.md`.

## Português

Os *runners* alojados do GitHub não têm Delphi, por isso os fluxos de `.github/workflows` têm dois tipos de tarefa:

* `docs` (alojado, `ubuntu-latest`): verifica as ligações da documentação (`tools/docs/check_links.py`).
* `delphi` e `release` (*runner* **próprio**, com as etiquetas `self-hosted`, `windows`, `delphi13`): `build.bat`,
  `build.bat test` e o zip da release.

Para configurar o *runner*: no repositório, *Settings > Actions > Runners > New self-hosted runner* (Windows x64), instale-o
numa máquina com o RAD Studio 13 (e, se quiser, o SDK de Linux64 e o Graphviz) e acrescente a etiqueta `delphi13`. Os *pull
requests* de forks não correm nessa máquina, de propósito.

**Fazer uma release:** atualize `DoxyPasVersion` (`src/Core/DoxyPas.Core.Version.pas`), a versão em `src/DoxyPas.rc`,
`src/Gui/Styles.rc`, nos `.dproj` e no `boss.json`, escreva as notas no `CHANGELOG.md` e depois

```
git tag v1.0.0
git push origin v1.0.0
```

O fluxo `release` confirma que a etiqueta corresponde à versão, compila, testa e anexa o `DoxyPas-<versão>.zip` a uma release
do GitHub. Sem o *runner*, faça o zip à mão (`build.bat`, `powershell tools\release\make_zip.ps1`) e
`gh release create v1.0.0 build\release\DoxyPas-1.0.0.zip --notes-file CHANGELOG.md`.
