#!/bin/sh
# Check an XML reader against expat: every corpus file must give the same tree, and every file
# in edge/bad must fail the build. READER selects the reader: `template` (the default) is the
# template parser (layouts/_partials/docsygen/xml/parse.html), `unmarshal` is
# transform.Unmarshal's document layout (targetType: document). With `unmarshal`, extra.xml is
# accepted by design (what follows the root is ignored), and every file in edge/lenient must
# build: they are known differences from expat, inherited from encoding/xml.
#
# Usage: [READER=template|unmarshal] sh tests/xml-parse/run.sh [NAME=DIR ...]
#   NAME=DIR  an extra directory of XML files to compare, e.g. doxytest=<doxygen>/testing
# Always compared: the demo project in sample/ (regenerated with doxygen), edge/good, and
# the example site's PDI XML. HUGO selects the Hugo binary (default: the example site's
# npm-installed one, else `hugo` from PATH).
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
hugo=${HUGO:-$root/exampleSite/node_modules/.bin/hugo}
[ -x "$hugo" ] || hugo=hugo
reader=${READER:-template}
case $reader in
  template) layouts=$here/layouts; layout_opt= ;;
  unmarshal) layouts=$here/layouts-unmarshal; layout_opt='--layout document' ;;
  *) echo "READER must be template or unmarshal, not $reader" >&2; exit 2 ;;
esac
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# site_config FILE NAME=SOURCE...: Hugo config mounting the parser, the dump layout and
# each SOURCE (a directory or a single file) under assets/corpus/NAME.
site_config() {
  config=$1; shift
  {
    printf 'disableKinds: [taxonomy, term, rss, sitemap, page, section]\nmodule:\n  mounts:\n'
    printf '    - {source: "%s", target: layouts}\n' "$root/layouts" "$layouts"
    for corpus in "$@"; do
      printf '    - {source: "%s", target: "assets/corpus/%s"}\n' "${corpus#*=}" "${corpus%%=*}"
    done
  } > "$config"
}

(cat "$here/sample/Doxyfile"; printf '%s\n' "INPUT=$here/sample/src" "OUTPUT_DIRECTORY=$work/sample") | doxygen -

set -- "sample=$work/sample/xml" "edge=$here/edge/good" "pdi=$root/exampleSite/assets/doxygen/pdi" "$@"
mkdir -p "$work/good"
site_config "$work/good/hugo.yaml" "$@"
start=$(date +%s.%N)
"$hugo" --quiet --source "$work/good" --destination "$work/good/public"
end=$(date +%s.%N)
kb=$(for corpus in "$@"; do printf '%s\n' "${corpus#*=}"; done | xargs -d '\n' du -ck | tail -n 1 | cut -f 1)
LC_ALL=C awk -v s="$start" -v e="$end" -v kb="$kb" 'BEGIN { printf "build: %.2f s for %.1f MB of XML\n", e - s, kb / 1024 }'
python3 -I "$here/compare.py" $layout_opt "$work/good/public/trees.json" "$@"

status=0
for bad in "$here"/edge/bad/*.xml; do
  name=$(basename "$bad")
  mkdir -p "$work/bad"
  site_config "$work/bad/hugo.yaml" "bad/$name=$bad"
  # Not --quiet: it would hide the ERROR line that errorf logs.
  if message=$("$hugo" --source "$work/bad" --destination "$work/bad/public" 2>&1); then
    if [ "$reader" = unmarshal ] && [ "$name" = extra.xml ]; then
      printf 'accepted by design %s\n' "$name"
    else
      printf 'NOT REJECTED %s\n' "$name"; status=1
    fi
  else
    printf 'rejected %-22s %s\n' "$name" "$(printf '%s' "$message" | grep -o 'xml/parse: .*\|unmarshal failed: .*' | head -n 1)"
  fi
  rm -rf "$work/bad"
done

if [ "$reader" = unmarshal ]; then
  for lenient in "$here"/edge/lenient/*.xml; do
    name=$(basename "$lenient")
    case $name in
      no-space-between-attrs.xml) issue=go#68385 ;;
      *) issue=unreported ;;
    esac
    mkdir -p "$work/lenient"
    site_config "$work/lenient/hugo.yaml" "lenient/$name=$lenient"
    if "$hugo" --quiet --source "$work/lenient" --destination "$work/lenient/public" > /dev/null 2>&1; then
      printf 'KNOWN accepted %s (%s)\n' "$name" "$issue"
    else
      printf 'NOW REJECTED %s: drop it from edge/lenient\n' "$name"
    fi
    rm -rf "$work/lenient"
  done
fi
exit $status
