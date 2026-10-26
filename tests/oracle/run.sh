#!/bin/sh
# Build a site from each oracle's XML and compare it with that oracle's Doxygen HTML.
#
# Usage: sh tests/oracle/run.sh exact|info [NAME ...]
#   exact  builds tests/doxygen-compat and compares it with exact.py, with every scope listed in
#          tests/oracle/scopes and the gaps of tests/oracle/xml-gaps.yaml
#   info   builds tests/site and tests/doxygen-compat, and compares the first with info.py through
#          the paths.json of both, with the gaps and tests/oracle/info-rules.yaml
#   info-docsy  the same with a copy of exampleSite, the Docsy site, pointed at the oracle's xml/
#          (its Docsy content is main .td-content); pdi only, as the example site renders PDI
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
  info-docsy) site=$root/exampleSite; set -- pdi ;;
  *) echo "run.sh: unknown mode $mode (exact or info)" >&2; exit 2 ;;
esac
script=$here/${mode%-docsy}.py
[ -f "$script" ] || { echo "run.sh: $script does not exist yet" >&2; exit 1; }
[ -d "$site" ] || { echo "run.sh: $site does not exist yet" >&2; exit 1; }
scopes=
for scope in $(sed 's/#.*//' "$here/scopes"); do scopes="$scopes --scope $scope"; done

status=0
for name; do
  printf '== %s\n' "$name"
  if ! dir=$(oracle "$name"); then status=1; continue; fi
  work=$tmp/$name
  mkdir -p "$work"
  if [ "$mode" = info-docsy ]; then
    # exampleSite as it is, but for the oracle's XML in place of its committed one, and a hook
    # that publishes paths.json.
    {
      printf 'module:\n  mounts:\n'
      printf '    - {source: "%s", target: "assets/doxygen/pdi"}\n' "$dir/xml"
      printf '    - {source: assets, target: assets, excludeFiles: ["doxygen/**"]}\n'
      for d in content static layouts data i18n archetypes; do printf '    - {source: "%s", target: "%s"}\n' "$d" "$d"; done
      printf '    - {source: "%s", target: "layouts"}\n' "$root/tests/site/hooks"
    } > "$work/checks.yaml"
    if ! PATH="$site/node_modules/.bin:$PATH" "$hugo" --source "$site" --config "$site/hugo.yaml,$work/checks.yaml" \
        --destination "$work/public" > "$work/log" 2>&1; then
      cat "$work/log" >&2; status=1; continue
    fi
  else
    site_config "$work/hugo.yaml" "$site/layouts=layouts" "$site/content=content" "$dir/xml=assets/doxygen/oracle"
    if [ -f "$site/config.yaml" ]; then cat "$site/config.yaml" >> "$work/hugo.yaml"; fi
    # Not --quiet: it would hide the ERROR line that errorf logs.
    if ! "$hugo" --source "$work" --destination "$work/public" > "$work/log" 2>&1; then
      cat "$work/log" >&2; status=1; continue
    fi
  fi
  if [ "$mode" != exact ]; then
    # info.py pairs pages through the roles of the compat site's pages.
    compat=$work/compat
    mkdir -p "$compat"
    site_config "$compat/hugo.yaml" "$root/tests/doxygen-compat/layouts=layouts" \
      "$root/tests/doxygen-compat/content=content" "$dir/xml=assets/doxygen/oracle"
    cat "$root/tests/doxygen-compat/config.yaml" >> "$compat/hugo.yaml"
    if ! "$hugo" --source "$compat" --destination "$compat/public" > "$compat/log" 2>&1; then
      cat "$compat/log" >&2; status=1; continue
    fi
    python3 -I "$script" --doxygen "$dir/html" --compat "$compat/public/paths.json" --site "$work/public" \
      --paths "$work/public/paths.json" --gaps "$here/xml-gaps.yaml" --rules "$here/info-rules.yaml" \
      --oracle "$name" || status=1
    continue
  fi
  # shellcheck disable=SC2086 # scopes are words
  python3 -I "$here/$mode.py" --doxygen "$dir/html" --site "$work/public" --paths "$work/public/paths.json" \
    --gaps "$here/xml-gaps.yaml" --oracle "$name" $scopes || status=1
done
exit $status
