#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Group the differences that tests/reference.sh found by kind of change, so that an expected
# change is checked at a glance.
#
# Usage: sh tests/reference-summary.sh [DIR]
#   DIR  the reports of tests/reference.sh (default /var/tmp/docsygen-reference)
# Per report, the changed files by kind (their extension, or html page for pages), then, for
# every distinct change (digits, hashes and the values of id, href, title, src and name folded), how many lines and files it touches, as
#   N lines in F files: - removed text
#                       + added text
# the most frequent first; a line shown here that you expected is fine, one you didn't expect is
# a regression.
set -eu

dir=${1:-/var/tmp/docsygen-reference}
exec python3 -I - "$dir" <<'PY'
import collections, glob, os, re, sys

def fold(line):
    line = re.sub(r'[0-9a-f]{32,}', 'HASH', line)
    # What names a page or a symbol varies from one change to the next of the same kind.
    line = re.sub(r'\b(id|data-doxygen-id|href|title|src|name)="[^"]*"', r'\1="..."', line)
    return re.sub(r'\d+', 'N', line)[:200]

reports = sorted(glob.glob(os.path.join(sys.argv[1], '*.diff')))
if not reports:
    print('reference-summary.sh: no differences')
for report in reports:
    print('==', os.path.basename(report)[:-5])
    kinds = collections.Counter()
    changes = collections.Counter()
    spread = collections.defaultdict(set)
    current = None
    with open(report, errors='replace') as f:
        for line in f:
            if line.startswith('diff -r '):
                current = line.split()[-1]
                ext = os.path.splitext(current)[1].lstrip('.') or 'none'
                kinds['html page' if ext == 'html' else ext] += 1
            elif line.startswith('Only in '):
                kinds['added or removed'] += 1
                print('  ', line.rstrip())
            elif line[:1] in '<>' and line[1:2] == ' ':
                key = (line[0], fold(line[2:].rstrip()))
                changes[key] += 1
                spread[key].add(current)
    for kind, n in kinds.most_common():
        print(f'  {n:5} files: {kind}')
    for (side, text), n in changes.most_common(15):
        print(f'  {n:5} lines in {len(spread[(side, text)])} files: {"-" if side == "<" else "+"} {text}')
PY
