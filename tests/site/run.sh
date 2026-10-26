#!/bin/sh
# Build the Docsy-flavor test site from each XML directory and check its output (check.py).
#
# Usage: sh tests/site/run.sh [NAME ...]
#   NAME   sample, sample-c, pdi (the oracles' XML, tests/lib.sh) or unknown-kind
#          (tests/unit/fixtures/unknown-kind); all four by default
# A build fails on any WARN or ERROR line, but the unknown-kind fixture's expected warning.
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
    *) if ! dir=$(oracle "$name"); then status=1; continue; fi; xml=$dir/xml ;;
  esac
  work=$tmp/$name
  mkdir -p "$work"
  site_config "$work/hugo.yaml" "$here/layouts=layouts" "$here/content=content" "$xml=assets/doxygen/oracle"
  cat "$here/config.yaml" >> "$work/hugo.yaml"
  # Not --quiet: it would hide the ERROR line that errorf logs.
  if ! "$hugo" --source "$work" --destination "$work/public" > "$work/log" 2>&1; then
    cat "$work/log" >&2; status=1; continue
  fi
  if grep -E 'WARN|ERROR' "$work/log" | grep -vF "${expected:-//nothing//}" >&2; then status=1; continue; fi
  if [ -n "$expected" ] && ! grep -qF "$expected" "$work/log"; then
    echo "run.sh: missing the warning: $expected" >&2; status=1; continue
  fi
  python3 -I "$here/check.py" "$work/public" "$xml" /ref/ || status=1
done
exit $status
