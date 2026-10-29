#!/bin/sh
# Check an XML reader against expat: every corpus file must give the same tree, in the document
# layout ({tag, attributes, children}), and every file in edge/bad must fail the build. READER
# selects the reader: `template` (the default) is the template reader, through
# layouts/_partials/docsygen/xml/unmarshal.html with tests/reader-template mounted over it, and
# `unmarshal` is transform.Unmarshal's document
# layout (targetType: document). With `unmarshal`, the bad files that the template reader rejects
# only by being stricter are accepted by design. The files in edge/lenient are known differences
# from expat, inherited from encoding/xml: each one is either accepted with the tree encoding/xml
# gives, or, for the template reader only, rejected. known-differences.md lists them all.
#
# Usage: [READER=template|unmarshal] sh tests/xml-parse/run.sh [NAME=DIR ...]
#   NAME=DIR  an extra directory of XML files to compare, e.g. doxytest=<doxygen>/testing
# Always compared: the XML of the sample and sample-c oracles (regenerated with doxygen, see
# tests/oracle/generate.sh), edge/good, and the example site's PDI XML. HUGO and DOXYGEN select
# the binaries (tests/lib.sh). TREES names a file to keep the trees of those files in
# (tests/reader-diff.sh).
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../lib.sh"
reader=${READER:-template}
case $reader in
  template) layouts=$here/layouts; DOCSYGEN_READER=template ;;
  unmarshal) layouts=$here/layouts-unmarshal ;;
  *) echo "READER must be template or unmarshal, not $reader" >&2; exit 2 ;;
esac
work=$tmp

# corpus_config FILE NAME=SOURCE...: the configuration of a site that imports docsygen and dumps
# the tree of every XML file of each SOURCE (a directory or a single file), mounted under
# assets/corpus/NAME.
corpus_config() {
  config=$1; shift
  n=$#
  for corpus; do set -- "$@" "${corpus#*=}=assets/corpus/${corpus%%=*}"; done
  shift "$n"
  site_config "$config" "$layouts=layouts" "$@"
  printf 'disableKinds: [taxonomy, term, rss, sitemap, page, section]\n' >> "$config"
}

set -- "sample=$(oracle sample)/xml" "sample-c=$(oracle sample-c)/xml" "edge=$here/edge/good" \
  "pdi=$root/exampleSite/assets/doxygen/pdi" "$@"
mkdir -p "$work/good"
corpus_config "$work/good/hugo.yaml" "$@"
now() { python3 -c 'import time; print(time.time())'; }
start=$(now)
# Not --quiet: it would hide the ERROR line of a rejected file.
if ! message=$("$hugo" --source "$work/good" --destination "$work/good/public" 2>&1); then
  printf '%s\n' "$message" >&2; exit 1
fi
end=$(now)
bytes=0
for corpus in "$@"; do
  bytes=$((bytes + $(find "${corpus#*=}" -type f -name '*.xml' -exec cat {} + | wc -c)))
done
LC_ALL=C awk -v s="$start" -v e="$end" -v b="$bytes" 'BEGIN { printf "build: %.2f s for %.1f MB of XML\n", e - s, b / 1e6 }'
status=0
python3 -I "$here/compare.py" --layout document "$work/good/public/trees.json" "$@" || status=1
if [ -n "${TREES:-}" ]; then cp "$work/good/public/trees.json" "$TREES"; fi

for bad in "$here"/edge/bad/*.xml; do
  name=$(basename "$bad")
  mkdir -p "$work/bad"
  corpus_config "$work/bad/hugo.yaml" "bad/$name=$bad"
  # Not --quiet: it would hide the ERROR line that errorf logs.
  if message=$("$hugo" --source "$work/bad" --destination "$work/bad/public" 2>&1); then
    case $reader/$name in
      # What follows the root is ignored, and encoding/xml accepts more names and declarations.
      unmarshal/extra.xml | unmarshal/text-outside.xml | unmarshal/second-root.xml | \
      unmarshal/non-ascii-name.xml | unmarshal/declaration.xml) printf 'accepted by design %s\n' "$name" ;;
      *) printf 'NOT REJECTED %s\n' "$name"; status=1 ;;
    esac
  else
    case $reader in
      template) pattern='xml/parse: .*' ;;
      unmarshal) pattern='failed to unmarshal XML: .*' ;;
    esac
    if reason=$(printf '%s' "$message" | grep -oE "$pattern" | head -n 1) && [ -n "$reason" ]; then
      printf 'rejected %-22s %s\n' "$name" "$reason"
    else
      printf 'REJECTED WITHOUT A READER MESSAGE %s\n%s\n' "$name" "$message"; status=1
    fi
  fi
  rm -rf "$work/bad"
done

for lenient in "$here"/edge/lenient/*.xml; do
  name=$(basename "$lenient")
  # The tree encoding/xml gives, and whether the template reader rejects the file instead.
  case $name in
    duplicate-attr.xml) issue=go#68295 want='{"attributes":{"a":"2"},"children":[],"tag":"r"}' strict= ;;
    no-space-between-attrs.xml) issue=go#68385 want='{"attributes":{"a":"1","b":"2"},"children":[],"tag":"r"}' strict=template ;;
    surrogate-ref.xml) issue=unreported want='{"attributes":{},"children":["\ufffd"],"tag":"r"}' strict= ;;
    *) printf 'UNLISTED %s: add its expected outcome to run.sh\n' "$name"; status=1; continue ;;
  esac
  mkdir -p "$work/lenient"
  corpus_config "$work/lenient/hugo.yaml" "lenient/$name=$lenient"
  if "$hugo" --source "$work/lenient" --destination "$work/lenient/public" > "$work/lenient.log" 2>&1; then
    if [ "$strict" = "$reader" ]; then
      printf 'NOT REJECTED %s: the %s reader rejects it\n' "$name" "$reader"; status=1
    elif python3 -I -c 'import json, sys; (got,) = json.load(open(sys.argv[1])).values(); sys.exit(got != json.loads(sys.argv[2]))' \
        "$work/lenient/public/trees.json" "$want"; then
      printf 'KNOWN accepted %s (%s)\n' "$name" "$issue"
    else
      printf 'DIFF %s: %s instead of %s\n' "$name" "$(cat "$work/lenient/public/trees.json")" "$want"; status=1
    fi
  elif [ "$strict" = "$reader" ]; then
    printf 'rejected (stricter) %s\n' "$name"
  else
    printf 'NOW REJECTED %s (%s): drop it from edge/lenient\n' "$name" "$issue"; cat "$work/lenient.log"; status=1
  fi
  rm -rf "$work/lenient"
done
exit $status
