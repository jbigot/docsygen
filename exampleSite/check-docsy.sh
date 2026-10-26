#!/bin/sh
# Build the example site as a Docsy site and check its output.
#
# Usage: sh exampleSite/check-docsy.sh
# The build fails on any WARN or ERROR (--printPathWarnings included). Then:
#   - tests/site/check.py on the output (a test-only Docsy hook, tests/site/hooks, publishes the
#     paths.json it reads);
#   - the offline search index holds PDI_share's brief;
#   - the print page of the reference holds a member's signature;
#   - llms.txt, if Docsy produces it, lists pages of /docs/main/.
# Hugo needs go for its modules, unless HUGO_MODULE_REPLACEMENTS points them at local copies.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
{
  printf 'module:\n  mounts:\n'
  for dir in content assets static layouts data i18n archetypes; do
    printf '    - {source: "%s", target: "%s"}\n' "$dir" "$dir"
  done
  printf '    - {source: "%s", target: "layouts"}\n' "$root/tests/site/hooks"
} > "$out/checks.yaml"
export PATH="$here/node_modules/.bin:$PATH"
# Not --quiet: it would hide the ERROR line that errorf logs.
if ! hugo --source "$here" --config "$here/hugo.yaml,$out/checks.yaml" --printPathWarnings \
    --destination "$out/public" > "$out/log" 2>&1; then
  cat "$out/log" >&2; exit 1
fi
status=0
if grep -E 'WARN|ERROR' "$out/log" >&2; then status=1; fi
python3 -I "$root/tests/site/check.py" "$out/public" "$here/assets/doxygen/pdi" /docs/main/ || status=1
if ! grep -qF 'Shares some data with PDI.' "$out"/public/offline-search-index.*.json 2>/dev/null; then
  echo "check-docsy.sh: the offline search index lacks PDI_share's brief" >&2; status=1
fi
if ! grep -qF 'docsygen-signature' "$out/public/_print/docs/main/index.html" 2>/dev/null; then
  echo "check-docsy.sh: the print page of /docs/main/ holds no member signature" >&2; status=1
fi
if [ -f "$out/public/llms.txt" ] && ! grep -qF '/docs/main/' "$out/public/llms.txt"; then
  echo "check-docsy.sh: llms.txt lists no page of /docs/main/" >&2; status=1
fi
[ $status -eq 0 ] && echo "check-docsy.sh: OK"
exit $status
