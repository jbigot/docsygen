#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Build the documentation site and check its links, ids and roles (tests/site/check_built.sh),
# and that its live examples are framed.
#
# Usage: sh doc/check.sh
# HUGO selects the Hugo binary (tests/lib.sh: the Hugo fork by default); set it to a released
# Hugo to check the site with the template reader. Hugo needs go for its modules.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../tests/lib.sh"
export PATH="$here/node_modules/.bin:$PATH"
# The test-only hook that publishes each version root's paths.json (tests/site/hooks), mounted
# after the site's own layouts.
{
  printf 'module:\n  mounts:\n'
  printf '    - {source: "%s", target: layouts}\n' "$root/tests/site/hooks"
} > "$tmp/checks.yaml"
# Not --quiet: it would hide the ERROR line that errorf logs.
if ! "$hugo" --source "$here" --config "$here/hugo.yaml,$tmp/checks.yaml" --baseURL / --printPathWarnings \
    --destination "$tmp/public" > "$tmp/log" 2>&1; then
  cat "$tmp/log" >&2; exit 1
fi
status=0
if grep -E 'WARN|ERROR' "$tmp/log" >&2; then status=1; fi
# A live example, a line that calls one of docsygen's shortcodes (not the escaped {{%/* … */%}}
# that shows it), is framed: it sits in a card's body, <div class="card-body"> … </div>, so that
# what it renders stands apart from the prose.
python3 -I - "$here/content" <<'PY' || status=1
import pathlib, re, sys
ok = True
for md in sorted(pathlib.Path(sys.argv[1]).rglob('*.md')):
    framed = False
    for n, line in enumerate(md.read_text().splitlines(), 1):
        if line.strip() == '<div class="card-body">':
            framed = True
        elif line.strip() == '</div>':
            framed = False
        elif re.match(r'\{\{[%<] docsygen/', line) and not framed:
            print(f'doc/check.sh: {md.relative_to(sys.argv[1])}:{n}: a live example outside a frame', file=sys.stderr)
            ok = False
sys.exit(0 if ok else 1)
PY
sh "$root/tests/site/check_built.sh" "$tmp/public" "$here/assets/doxygen/sample" /docs/reference/latest/ || status=1
sh "$root/tests/site/check_chroma_css.sh" "$tmp/public" || status=1
exit $status
