"""Writes docs/en/OPTIONS.md, docs/pt/OPCOES.md and the charts docs/images/options_by_*.svg.

Types, defaults and values come from resources/config/*.xml and from `doxypas -s -g`; the explanations are in
options_text.py. Run from anywhere:  python tools/docs/gen_options.py   (needs build/Win64/DoxyPas.exe)
"""
import re
import subprocess
import sys
import tempfile
import os
import xml.etree.ElementTree as ET
from collections import Counter

sys.path.insert(0, os.path.dirname(__file__))
from options_text import T, GROUPS

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ORDER = ['Project', 'Build', 'Messages', 'Input', 'Source_Browser', 'Index', 'HTML', 'LaTeX', 'XML', 'Sqlite3',
         'Preprocessor', 'External', 'Dot', 'Pascal']

# images shown at the end of a group: (file, caption en, caption pt)
FIGURES = {
    'Project': [('pt.png', 'OUTPUT_LANGUAGE = Portuguese: the fixed texts of the page are translated.',
                 'OUTPUT_LANGUAGE = Portuguese: os textos fixos da página são traduzidos.')],
    'Build': [('private.png', 'EXTRACT_PRIVATE = YES: the private field FRadius is documented too.',
               'EXTRACT_PRIVATE = YES: o campo privado FRadius também fica documentado.')],
    'Source_Browser': [('source.png', 'SOURCE_BROWSER = YES: the listing of a unit, with links and folding.',
                        'SOURCE_BROWSER = YES: a listagem de uma unit, com ligações e dobragem.'),
                       ('inline.png', 'INLINE_SOURCES = YES: the body of each routine is shown in its documentation.',
                        'INLINE_SOURCES = YES: o corpo de cada rotina é mostrado na sua documentação.')],
    'HTML': [('dark.png', 'HTML_COLORSTYLE = DARK.', 'HTML_COLORSTYLE = DARK.'),
             ('hue.png', 'HTML_COLORSTYLE_HUE = 20 (orange instead of blue).',
              'HTML_COLORSTYLE_HUE = 20 (laranja em vez de azul).'),
             ('notree.png', 'GENERATE_TREEVIEW = NO: no navigation tree.',
              'GENERATE_TREEVIEW = NO: sem árvore de navegação.'),
             ('sidebar.png', 'FULL_SIDEBAR = YES: the left panel takes the full height.',
              'FULL_SIDEBAR = YES: o painel da esquerda ocupa a altura toda.')],
    'Dot': [('class.png', 'The default: inheritance and collaboration graphs made by dot (an SVG, so the boxes are links).',
             'Por omissão: grafos de herança e de colaboração feitos pelo dot (um SVG, por isso as caixas são ligações).'),
            ('uml.png', 'UML_LOOK = YES and DOT_UML_DETAILS = YES.', 'UML_LOOK = YES e DOT_UML_DETAILS = YES.'),
            ('nodot.png', 'HAVE_DOT = NO: only the built-in inheritance diagram.',
             'HAVE_DOT = NO: só o diagrama de herança interno.'),
            ('callgraph.png', 'CALL_GRAPH = YES: what TRectangle.Bounding calls.',
             'CALL_GRAPH = YES: o que TRectangle.Bounding chama.'),
            ('callergraph.png', 'CALLER_GRAPH = YES: who calls TCircle.Create.',
             'CALLER_GRAPH = YES: quem chama TCircle.Create.')],
}


def read_options():
    out = []
    for f in ('config.xml', 'config_pascal.xml'):
        for g in ET.parse(os.path.join(ROOT, 'resources', 'config', f)).getroot().iter('group'):
            for o in g.iter('option'):
                if o.get('type') == 'obsolete':
                    continue
                out.append(dict(id=o.get('id'), type=o.get('type'), group=g.get('name'),
                                values=[v.get('name') for v in o.findall('value')]))
    return out


def read_defaults():
    exe = os.path.join(ROOT, 'build', 'Win64', 'DoxyPas.exe')
    with tempfile.TemporaryDirectory() as d:
        cfg = os.path.join(d, 'Doxyfile')
        subprocess.run([exe, '-s', '-g', cfg], check=True, capture_output=True)
        text = open(cfg, encoding='utf-8-sig').read().replace('\\\n', '\x00')
    res = {}
    for line in text.split('\n'):
        m = re.match(r'^([A-Z0-9_]+)\s*=\s*(.*)$', line)
        if m:
            res[m.group(1)] = [x.strip() for x in m.group(2).split('\x00') if x.strip()]
    return res


def md(s):
    return s.replace('|', '\\|')


def type_name(o, pt):
    t = {'bool': ('YES/NO', 'YES/NO'), 'int': ('number', 'número'), 'string': ('text', 'texto'),
         'list': ('list', 'lista'), 'enum': ('choice', 'escolha')}[o['type']]
    return t[1 if pt else 0]


def default_text(o, defaults):
    d = defaults.get(o['id'], [])
    if not d:
        return '—'
    if len(d) > 3:
        d = d[:3] + ['…']
    return '`' + md(' '.join(d)) + '`'


def write_chart(path, title, data, color):
    w, row = 560, 26
    h = 56 + row * len(data)
    mx = max(v for _, v in data)
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" font-family="Segoe UI, Helvetica, Arial, sans-serif" font-size="13">',
         f'<rect width="{w}" height="{h}" fill="#ffffff" rx="8"/>',
         f'<text x="16" y="28" font-size="15" font-weight="bold" fill="#222">{title}</text>']
    for i, (k, v) in enumerate(data):
        y = 48 + i * row
        bw = 300 * v / mx
        s.append(f'<text x="16" y="{y + 14}" fill="#333">{k}</text>')
        s.append(f'<rect x="190" y="{y}" width="{bw:.1f}" height="18" fill="{color}" rx="3"/>')
        s.append(f'<text x="{196 + bw:.1f}" y="{y + 14}" fill="#333">{v}</text>')
    s.append('</svg>')
    open(path, 'w', encoding='utf-8').write('\n'.join(s))


def render(pt, opts, defaults):
    by = {g: [o for o in opts if o['group'] == g] for g in ORDER}
    L = []
    a = L.append
    if pt:
        a('# DoxyPas — Referência das opções\n')
        a('[English](../en/OPTIONS.md) · [Guia do utilizador](GUIA_DO_UTILIZADOR.md) · [README](../../README.md)\n')
        a(f'O Doxyfile do DoxyPas tem **{len(opts)} opções**, todas implementadas. Esta página explica cada uma. '
          'Para gerar um Doxyfile com todas e a sua documentação: `doxypas -g Doxyfile`; para ver só as que mudou: '
          '`doxypas -x Doxyfile`. Os valores por omissão abaixo são os do `doxypas -g`.\n')
        a('![Opções por grupo](../images/options_by_group.svg)\n')
        a('Cada linha do Doxyfile é `OPÇÃO = valor`. As opções do tipo *lista* aceitam vários valores separados por '
          'espaços (ou `+=` para acrescentar) e as do tipo *YES/NO* aceitam `YES` ou `NO`. Um `#` começa um comentário.\n')
        a('## Índice\n')
    else:
        a('# DoxyPas — Options reference\n')
        a('[Português](../pt/OPCOES.md) · [User guide](USER_GUIDE.md) · [README](../../README.md)\n')
        a(f'The DoxyPas Doxyfile has **{len(opts)} options**, all of them implemented. This page explains each one. '
          'To write a Doxyfile with all of them and their documentation: `doxypas -g Doxyfile`; to list only the ones '
          'you changed: `doxypas -x Doxyfile`. The defaults below are the ones of `doxypas -g`.\n')
        a('![Options per group](../images/options_by_group.svg)\n')
        a('Each line of the Doxyfile is `OPTION = value`. The options of type *list* take several values separated by '
          'spaces (or `+=` to append) and the ones of type *YES/NO* take `YES` or `NO`. A `#` starts a comment.\n')
        a('## Contents\n')
    for g in ORDER:
        a(f'* [{GROUPS[g][1 if pt else 0]}](#{anchor(g, pt)}) ({len(by[g])})')
    a('')
    for g in ORDER:
        a(f'## {GROUPS[g][1 if pt else 0]}\n')
        a(GROUPS[g][3 if pt else 2] + '\n')
        a('| ' + ('Opção | Tipo | Omissão | O que faz' if pt else 'Option | Type | Default | What it does') + ' |')
        a('|---|---|---|---|')
        for o in by[g]:
            txt = T[o['id']][1 if pt else 0]
            if o['type'] == 'enum':
                v = o['values']
                shown = ', '.join(f'`{x}`' for x in v[:6]) + (' …' if len(v) > 6 else '')
                if all(f'`{x}`' not in txt for x in v[:3]):
                    txt += (' Valores: ' if pt else ' Values: ') + shown + '.'
            a(f"| `{o['id']}` | {type_name(o, pt)} | {default_text(o, defaults)} | {md(txt)} |")
        a('')
        for f, en, ptc in FIGURES.get(g, []):
            a(f'![{(ptc if pt else en)}](../images/{f})\n')
            a(f'*{ptc if pt else en}*\n')
    return '\n'.join(L) + '\n'


def anchor(g, pt):
    s = GROUPS[g][1 if pt else 0].lower()
    s = re.sub(r'[^\w\s-]', '', s, flags=re.U).strip().replace(' ', '-')
    return s


def main():
    opts = read_options()
    ids = {o['id'] for o in opts}
    assert ids == set(T), f'missing text: {sorted(ids - set(T))}; text without option: {sorted(set(T) - ids)}'
    defaults = read_defaults()
    for d in ('en', 'pt', 'images'):
        os.makedirs(os.path.join(ROOT, 'docs', d), exist_ok=True)
    for pt, name in ((False, 'en/OPTIONS.md'), (True, 'pt/OPCOES.md')):
        open(os.path.join(ROOT, 'docs', name), 'w', encoding='utf-8', newline='\n').write(render(pt, opts, defaults))
    c = Counter(o['group'] for o in opts)
    write_chart(os.path.join(ROOT, 'docs', 'images', 'options_by_group.svg'), 'Options per group / Opções por grupo',
                [(GROUPS[g][0], c[g]) for g in ORDER], '#3d5a99')
    t = Counter(o['type'] for o in opts)
    write_chart(os.path.join(ROOT, 'docs', 'images', 'options_by_type.svg'), 'Options per type / Opções por tipo',
                [(k, t[k]) for k in ('bool', 'string', 'list', 'int', 'enum')], '#2e7d32')
    print(len(opts), 'options')


main()
