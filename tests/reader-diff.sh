#!/bin/sh
# Check the template reader against the native decoder of gohugoio/hugo#15485, with one Hugo
# binary for both readers, so that a difference can only come from the reader.
#
# Usage: sh tests/reader-diff.sh
# The binary is the Hugo fork's docsygen-native (tests/lib.sh, native_hugo), whatever HUGO says:
# docsygen picks the native decoder there by itself (docsygen/xml/native.html), and
# DOCSYGEN_READER=template mounts tests/reader-template to force the template reader.
# With each reader:
#   1. tests/xml-parse/run.sh, then the two trees of every corpus file compared with each other;
#   2. tests/unit/run.sh, which must pass with both;
#   3. the Docsy test site on the sample, sample-c and pdi oracles, and the example site, whose
#      public/ directories must be identical.
# The pdi oracle needs PDI_SRC the first time (tests/lib.sh, oracle), and the example site go
# or HUGO_MODULE_REPLACEMENTS for its modules. Exit 1 on any difference or failure.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
HUGO=$(native_hugo)
DOCSYGEN_HUGO_KIND=native
# The same sample XML for every run: Doxygen writes its output directory into Doxyfile.xml.
DOCSYGEN_ORACLES=$tmp/oracle
export HUGO DOCSYGEN_HUGO_KIND DOCSYGEN_ORACLES
hugo=$HUGO
"$hugo" version
status=0
fail() { echo "reader-diff.sh: FAILED: $*" >&2; status=1; }

echo "== xml-parse"
for reader in template unmarshal; do
  if ! READER=$reader TREES=$tmp/trees-$reader.json sh "$root/tests/xml-parse/run.sh" > "$tmp/xml-$reader.log" 2>&1; then
    cat "$tmp/xml-$reader.log" >&2; fail "tests/xml-parse/run.sh with READER=$reader"
  fi
done
if [ -f "$tmp/trees-template.json" ] && [ -f "$tmp/trees-unmarshal.json" ]; then
  python3 -I - "$tmp/trees-template.json" "$tmp/trees-unmarshal.json" <<'EOF' || fail "the two readers' trees differ"
import json, sys
a, b = (json.load(open(p)) for p in sys.argv[1:])
diff = sorted(k for k in set(a) | set(b) if a.get(k) != b.get(k))
for k in diff: print('DIFF', k)
print(f'{len(a) - len(diff)} of {len(a)} trees identical')
sys.exit(1 if diff else 0)
EOF
fi

echo "== unit"
for reader in template native; do
  if ! DOCSYGEN_READER=$reader sh "$root/tests/unit/run.sh" > "$tmp/unit-$reader.log" 2>&1; then
    cat "$tmp/unit-$reader.log" >&2; fail "tests/unit/run.sh with the $reader reader"
  fi
  printf '%s: %s\n' "$reader" "$(tail -n 1 "$tmp/unit-$reader.log")"
done

# compare NAME: the public/ directories of $tmp/NAME-template and $tmp/NAME-native.
compare() {
  if diff -r "$tmp/$1-template/public" "$tmp/$1-native/public" > "$tmp/$1.diff"; then
    printf '%s: %s files identical\n' "$1" "$(find "$tmp/$1-template/public" -type f | wc -l)"
  else
    head -n 20 "$tmp/$1.diff" >&2; fail "$1 differs between the readers"
  fi
}

echo "== sites"
for name in sample sample-c pdi; do
  if ! dir=$(oracle "$name"); then fail "no $name oracle"; continue; fi
  ok=1
  for reader in template native; do
    work=$tmp/site-$name-$reader
    mkdir -p "$work"
    extra=
    if [ "$name" = sample ]; then extra="$root/tests/site/handwritten=content"; fi
    DOCSYGEN_READER=$reader
    # shellcheck disable=SC2086 # extra is one word or none
    site_config "$work/hugo.yaml" "$root/tests/site/layouts=layouts" "$root/tests/site/content=content" $extra \
      "$dir/xml=assets/doxygen/oracle"
    cat "$root/tests/site/config.yaml" >> "$work/hugo.yaml"
    # Not --quiet: it would hide the ERROR line that errorf logs.
    if ! "$hugo" --source "$work" --destination "$work/public" > "$work/log" 2>&1; then
      cat "$work/log" >&2; fail "site $name with the $reader reader"; ok=0
    fi
  done
  DOCSYGEN_READER=
  [ $ok -eq 0 ] || compare "site-$name"
done

# The example site as it is, with the template reader's layouts mounted before its own.
example=$root/exampleSite
for reader in template native; do
  work=$tmp/example-$reader
  mkdir -p "$work"
  {
    printf 'module:\n  mounts:\n'
    if [ "$reader" = template ]; then printf '    - {source: "%s", target: "layouts"}\n' "$root/tests/reader-template/layouts"; fi
    for d in content assets static layouts data i18n archetypes; do printf '    - {source: "%s", target: "%s"}\n' "$d" "$d"; done
  } > "$work/mounts.yaml"
  if ! PATH="$example/node_modules/.bin:$PATH" "$hugo" --source "$example" --config "$example/hugo.yaml,$work/mounts.yaml" \
      --destination "$work/public" > "$work/log" 2>&1; then
    cat "$work/log" >&2; fail "the example site with the $reader reader"
  fi
done
compare example

[ $status -eq 0 ] && echo "reader-diff.sh: OK"
exit $status
