#!/bin/sh
# Build a site from each oracle's XML and compare it with that oracle's Doxygen HTML.
#
# Usage: sh tests/oracle/run.sh exact|info [NAME ...]
#   exact  builds tests/doxygen-compat and compares it with exact.py, with every scope listed in
#          tests/oracle/scopes and the gaps of tests/oracle/xml-gaps.yaml
#   info   builds tests/site and compares it with info.py
#   NAME   sample, sample-c or pdi (default: all three); pdi needs PDI_SRC the first time
#          (tests/lib.sh, oracle)
# The site directory holds layouts/, content/ and config.yaml (its configuration, without the
# module section); the oracle's xml/ is mounted at assets/doxygen/oracle. Exit 1 on any
# difference, when an oracle cannot be generated, or when the site does not exist yet.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../lib.sh"
mode=${1:?usage: run.sh exact|info [NAME ...]}
shift
[ $# -gt 0 ] || set -- sample sample-c pdi
case $mode in
  exact) site=$root/tests/doxygen-compat ;;
  info) site=$root/tests/site ;;
  *) echo "run.sh: unknown mode $mode (exact or info)" >&2; exit 2 ;;
esac
[ -f "$here/$mode.py" ] || { echo "run.sh: $here/$mode.py does not exist yet" >&2; exit 1; }
[ -d "$site" ] || { echo "run.sh: $site does not exist yet" >&2; exit 1; }
scopes=
for scope in $(sed 's/#.*//' "$here/scopes"); do scopes="$scopes --scope $scope"; done

status=0
for name; do
  printf '== %s\n' "$name"
  if ! dir=$(oracle "$name"); then status=1; continue; fi
  work=$tmp/$name
  mkdir -p "$work"
  site_config "$work/hugo.yaml" "$site/layouts=layouts" "$site/content=content" "$dir/xml=assets/doxygen/oracle"
  if [ -f "$site/config.yaml" ]; then cat "$site/config.yaml" >> "$work/hugo.yaml"; fi
  # Not --quiet: it would hide the ERROR line that errorf logs.
  if ! "$hugo" --source "$work" --destination "$work/public" > "$work/log" 2>&1; then
    cat "$work/log" >&2; status=1; continue
  fi
  # shellcheck disable=SC2086 # scopes are words
  python3 -I "$here/$mode.py" --doxygen "$dir/html" --site "$work/public" --paths "$work/public/paths.json" \
    --gaps "$here/xml-gaps.yaml" --oracle "$name" $scopes || status=1
done
exit $status
