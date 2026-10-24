#!/bin/sh
# Check the template XML parser (layouts/_partials/docsygen/xml/parse.html) against expat:
# every corpus file must give the same tree, and every file in edge/bad must fail the build.
#
# Usage: sh tests/xml-parse/run.sh [NAME=DIR ...]
#   NAME=DIR  an extra directory of XML files to compare, e.g. doxytest=<doxygen>/testing
# Always compared: the demo project in sample/ (regenerated with doxygen), edge/good, and
# the example site's PDI XML. HUGO selects the Hugo binary (default: the example site's
# npm-installed one, else `hugo` from PATH).
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
hugo=${HUGO:-$root/exampleSite/node_modules/.bin/hugo}
[ -x "$hugo" ] || hugo=hugo
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# site_config FILE NAME=SOURCE...: Hugo config mounting the parser, the dump layout and
# each SOURCE (a directory or a single file) under assets/corpus/NAME.
site_config() {
  config=$1; shift
  {
    printf 'disableKinds: [taxonomy, term, rss, sitemap, page, section]\nmodule:\n  mounts:\n'
    printf '    - {source: "%s", target: layouts}\n' "$root/layouts" "$here/layouts"
    for corpus in "$@"; do
      printf '    - {source: "%s", target: "assets/corpus/%s"}\n' "${corpus#*=}" "${corpus%%=*}"
    done
  } > "$config"
}

(cat "$here/sample/Doxyfile"; printf '%s\n' "INPUT=$here/sample/src" "OUTPUT_DIRECTORY=$work/sample") | doxygen -

set -- "sample=$work/sample/xml" "edge=$here/edge/good" "pdi=$root/exampleSite/assets/doxygen/pdi" "$@"
mkdir -p "$work/good"
site_config "$work/good/hugo.yaml" "$@"
"$hugo" --quiet --source "$work/good" --destination "$work/good/public"
python3 -I "$here/compare.py" "$work/good/public/trees.json" "$@"

status=0
for bad in "$here"/edge/bad/*.xml; do
  name=$(basename "$bad")
  mkdir -p "$work/bad"
  site_config "$work/bad/hugo.yaml" "bad/$name=$bad"
  # Not --quiet: it would hide the ERROR line that errorf logs.
  if message=$("$hugo" --source "$work/bad" --destination "$work/bad/public" 2>&1); then
    printf 'NOT REJECTED %s\n' "$name"; status=1
  else
    printf 'rejected %-22s %s\n' "$name" "$(printf '%s' "$message" | grep -o 'xml/parse: .*' | head -n 1)"
  fi
  rm -rf "$work/bad"
done
exit $status
