#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Check the template reader against the native decoder of gohugoio/hugo#15485, with one Hugo
# binary for both readers, so that a difference can only come from the reader.
#
# Usage: sh tests/reader-diff.sh
# The binary is the Hugo fork's docsygen-native (tests/lib.sh, native_hugo), whatever HUGO says:
# docsygen picks the native decoder there by itself (xmldoc/native.html, of hugo-xml-document), and
# DOCSYGEN_READER=template mounts tests/reader-template to force the template reader.
# With each reader:
#   1. tests/unit/run.sh, which must pass with both;
#   2. the Docsy test site on the sample, sample-c and pdi corpus entries, the example site and the
#      documentation site, whose public/ directories must be identical.
# The example site needs go for its modules. Exit 1 on any difference or failure.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
HUGO=$(native_hugo)
DOCSYGEN_HUGO_KIND=native
export HUGO DOCSYGEN_HUGO_KIND
hugo=$HUGO
"$hugo" version
status=0
fail() { echo "reader-diff.sh: FAILED: $*" >&2; status=1; }

echo "== unit"
for reader in template native; do
  if ! DOCSYGEN_READER=$reader sh "$root/tests/unit/run.sh" > "$tmp/unit-$reader.log" 2>&1; then
    cat "$tmp/unit-$reader.log" >&2; fail "tests/unit/run.sh with the $reader reader"
  fi
  printf '%s: %s\n' "$reader" "$(tail -n 1 "$tmp/unit-$reader.log")"
done

# compare NAME [SUBDIR]: the public/ directories (below SUBDIR) of $tmp/NAME-template and
# $tmp/NAME-native.
compare() {
  if diff -r "$tmp/$1-template/public/${2:-}" "$tmp/$1-native/public/${2:-}" > "$tmp/$1.diff"; then
    printf '%s: %s files identical\n' "$1" "$(find "$tmp/$1-template/public/${2:-}" -type f | wc -l)"
  else
    head -n 20 "$tmp/$1.diff" >&2; fail "$1 differs between the readers"
  fi
}

echo "== sites"
for name in sample sample-c pdi; do
  if ! dir=$(corpus "$name"); then fail "no $name corpus entry"; continue; fi
  ok=1
  for reader in template native; do
    work=$tmp/site-$name-$reader
    mkdir -p "$work"
    extra=
    if [ "$name" = sample ]; then extra="$root/tests/site/handwritten=content"; fi
    DOCSYGEN_READER=$reader
    # shellcheck disable=SC2086 # extra is one word or none
    site_config "$work/hugo.yaml" "$root/tests/site/layouts=layouts" "$root/tests/site/content=content" $extra \
      "$dir/xml=assets/doxygen/corpus"
    cat "$root/tests/site/config.yaml" >> "$work/hugo.yaml"
    # Not --quiet: it would hide the ERROR line that errorf logs.
    if ! "$hugo" --source "$work" --destination "$work/public" > "$work/log" 2>&1; then
      cat "$work/log" >&2; fail "site $name with the $reader reader"; ok=0
    fi
  done
  DOCSYGEN_READER=
  [ $ok -eq 0 ] || compare "site-$name"
done

# The example site and the documentation site as they are: a copy of each, whose layouts hold the
# template reader's, in the template run (a site's own layouts override a module's).
for site in exampleSite doc; do
  for reader in template native; do
    work=$tmp/$site-$reader
    mkdir -p "$work"
    (cd "$root/$site" && tar -c --exclude=./node_modules --exclude=./public --exclude=./resources .) | tar -x -C "$work"
    cp -a "$root/$site/node_modules" "$work/node_modules"
    sed -i "s#=> \.\./\$#=> $root#" "$work/go.mod"
    if [ "$reader" = template ]; then
      mkdir -p "$work/layouts"
      cp -r "$root/tests/reader-template/layouts/." "$work/layouts/"
    fi
    if ! PATH="$work/node_modules/.bin:$PATH" "$hugo" --source "$work" --destination "$work/public" > "$work/log" 2>&1; then
      cat "$work/log" >&2; fail "the $site site with the $reader reader"
    fi
  done
  # The example site's own pages come out differently from one build to the next (the order of
  # its languages' alternates, the build date): only what docsygen made counts.
  if [ "$site" = exampleSite ]; then compare "$site" docs/api; else compare "$site"; fi
done

[ $status -eq 0 ] && echo "reader-diff.sh: OK"
exit $status
