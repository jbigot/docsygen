#!/bin/sh
# Build the Docsy-flavor test site from each XML directory and check its output: check.py on its
# two version roots, /ref/ and /latest/ (tests/site/content/_content.gotmpl), and the redirects
# from /1.0/ to /latest/ (check_redirects.py).
#
# Usage: sh tests/site/run.sh [NAME ...]
#   NAME   sample, sample-c, pdi (the oracles' XML, tests/lib.sh) or unknown-kind
#          (tests/unit/fixtures/unknown-kind); all four by default
# A build fails on any WARN or ERROR line, but an expected warning: the unknown-kind fixture's, and
# the sample's for its eqnarray* formula, an environment KaTeX lacks (its source is shown).
# Exit 1 on any failure.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../lib.sh"
[ $# -gt 0 ] || set -- sample sample-c pdi unknown-kind
status=0
for name; do
  printf '== %s\n' "$name"
  expected=
  case $name in
    unknown-kind) xml=$root/tests/unit/fixtures/unknown-kind; expected='docsygen: unknown compound kind "widgetkind"' ;;
    *) if ! dir=$(oracle "$name"); then status=1; continue; fi; xml=$dir/xml
       if [ "$name" = sample ]; then expected='docsygen: formula "\\begin{eqnarray*}'; fi ;;
  esac
  work=$tmp/$name
  mkdir -p "$work"
  # The hand-written page links to the sample's symbols.
  extra=
  if [ "$name" = sample ]; then extra="$here/handwritten=content"; fi
  # shellcheck disable=SC2086 # extra is one word or none
  site_config "$work/hugo.yaml" "$here/layouts=layouts" "$here/content=content" $extra "$xml=assets/doxygen/oracle"
  cat "$here/config.yaml" >> "$work/hugo.yaml"
  # Not --quiet: it would hide the ERROR line that errorf logs.
  if ! "$hugo" --source "$work" --destination "$work/public" > "$work/log" 2>&1; then
    cat "$work/log" >&2; status=1; continue
  fi
  if grep -E 'WARN|ERROR' "$work/log" | grep -vF "${expected:-//nothing//}" >&2; then status=1; continue; fi
  if [ -n "$expected" ] && ! grep -qF "$expected" "$work/log"; then
    echo "run.sh: missing the warning: $expected" >&2; status=1; continue
  fi
  links=
  if [ "$name" = sample ]; then links="--links handwritten/index.html $here/expected-links.json"; fi
  # shellcheck disable=SC2086 # links is words
  python3 -I "$here/check.py" "$work/public" "$xml" /ref/ $links || status=1
  python3 -I "$here/check.py" "$work/public" "$xml" /latest/ || status=1
  python3 -I "$here/check_redirects.py" "$work/public" /latest/ /1.0/ || status=1
done
exit $status
