#!/bin/sh
# Build the example site in PDI's organization (pdi-layout.yaml, content-pdi/) and check it.
#
# Usage: sh exampleSite/check-layout.sh
# The build fails on any WARN or ERROR (--printPathWarnings included). Then tests/site/check.py
# without its role checks, since each placement holds part of a tree, and
# tests/site/check_layout.py with layout-expected.json: the titles of some pages and some links.
# HUGO selects the Hugo binary (tests/lib.sh: the Hugo fork by default). Hugo needs go for its
# modules, unless HUGO_MODULE_REPLACEMENTS points them at local copies.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../tests/lib.sh"
export PATH="$here/node_modules/.bin:$PATH"
# Not --quiet: it would hide the ERROR line that errorf logs.
if ! "$hugo" --source "$here" --config "$here/hugo.yaml,$here/pdi-layout.yaml" --printPathWarnings \
    --destination "$tmp/public" > "$tmp/log" 2>&1; then
  cat "$tmp/log" >&2; exit 1
fi
status=0
if grep -E 'WARN|ERROR' "$tmp/log" >&2; then status=1; fi
python3 -I "$root/tests/site/check.py" "$tmp/public" - - || status=1
python3 -I "$root/tests/site/check_layout.py" "$tmp/public" "$here/layout-expected.json" || status=1
[ $status -eq 0 ] && echo "check-layout.sh: OK"
exit $status
