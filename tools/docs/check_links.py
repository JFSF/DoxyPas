"""Fails if a relative link or image of the Markdown files points to a file that does not exist."""
import glob
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
bad = 0
for f in glob.glob(os.path.join(ROOT, '*.md')) + glob.glob(os.path.join(ROOT, 'docs', '**', '*.md'), recursive=True):
    if os.sep + 'example' + os.sep in f:
        continue
    text = open(f, encoding='utf-8').read()
    text = re.sub(r'```.*?```', '', text, flags=re.S)
    text = re.sub(r'`[^`\n]*`', '', text)
    for m in re.finditer(r'\]\(([^)#\s]+)(#[^)]*)?\)', text):
        t = m.group(1)
        if t.startswith(('http:', 'https:', 'mailto:')):
            continue
        if not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(f), t))):
            print('BROKEN', os.path.relpath(f, ROOT), t)
            bad += 1
print('broken links:', bad)
sys.exit(1 if bad else 0)
