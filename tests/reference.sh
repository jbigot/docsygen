#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Build the Docsy-flavor test site of every corpus entry, with each supported Doxygen's XML, with
# the module of a reference revision and with the working tree's, and docsygen's own Docsy sites
# from each tree, and report what changed.
#
# Usage: [REF=REVISION] [REFERENCE_OUT=DIR] sh tests/reference.sh [--strict] [NAME ...]
#   NAME      sample, sample-c, pdi, unknown-kind, versions or versions-mixed, as tests/site/run.sh,
#             or doc and example, the documentation and example sites (default: all); those whose
#             XML doesn't depend on the Doxygen version (pdi, unknown-kind, versions-mixed, doc and
#             example, which render their committed XML) are built with the last one only
#   REF       the revision whose output is the reference (default HEAD: the working tree against
#             the last commit; REF=main for a branch)
#   REFERENCE_OUT  where the reports go (default /var/tmp/docsygen-reference)
#   --strict  fail on any change, for a refactor that must not change the output
# The reference is checked out in a git worktree that is removed on exit. Both builds use the
# working tree's tests/site layouts and configuration, so that the module makes the difference;
# the content (adapter calls, hand-written pages) is each tree's own, since it follows its
# module's interface, and an entry that the reference has no content for is skipped. doc and
# example are each tree's own site directory, content and configuration included, built as
# doc/check.sh and exampleSite/check.sh do but without git dates (exampleSite's "Last modified"
# would differ on every page a branch edits), and with weights for exampleSite's languages,
# which have none: Hugo
# then lists the translations of its taxonomy pages in its sitemaps in no fixed order. The
# reference's uses the working tree's node_modules (npx npm@11 install in doc/ and exampleSite/).
# The comparison ignores `var buildDate = new Date("…")`: Docsy's td/site-build-info shortcode
# writes the build time into docsy-example's /site/ page and RSS feed even when Netlify doesn't
# build it, which its own comment says it avoids (Hugo's --clock doesn't stop the clock).
# Prints, per
# site and Doxygen version,
#   reference.sh: NAME (doxygen V): N identical, C changed, A added, R removed
# and writes REFERENCE_OUT/NAME-V.diff (diff -r of the two outputs) for a site that differs.
# `sh tests/reference-summary.sh` groups those diffs by kind of change. A failed build always
# fails. Exit 1 on a failure, or on a change with --strict.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
strict=
if [ "${1:-}" = --strict ]; then strict=1; shift; fi
[ $# -gt 0 ] || set -- sample sample-c pdi unknown-kind versions versions-mixed doc example
ref=${REF:-HEAD}
out=${REFERENCE_OUT:-/var/tmp/docsygen-reference}
doxygens=${REFERENCE_DOXYGENS:-"1.17.0 1.18.0"}
git -C "$root" worktree add -q -d "$tmp/base" "$ref"
trap 'git -C "$root" worktree remove --force "$tmp/base"; rm -rf "$tmp"' EXIT
rm -rf "$out"
mkdir -p "$out"
site=$root/tests/site

status=0
# compare NAME V: report how the work build of NAME with Doxygen V differs from the base one, and
# write its diff -r; a difference sets status with --strict.
compare() {
  python3 -I - "$tmp/$1-$2-base/public" "$tmp/$1-$2-work/public" "$1 (doxygen $2)" <<'PY' && return 0
import os, re, sys
base, work, name = sys.argv[1:]
build_date = re.compile(rb'var buildDate = new Date\((?:"|&#34;)[^"&]*(?:"|&#34;)\)')
def files(top):
    return {os.path.relpath(os.path.join(d, f), top) for d, _, fs in os.walk(top) for f in fs}
def content(top, f):
    # Without the build date, written back so that diff -r below sees the same files.
    path = os.path.join(top, f)
    with open(path, 'rb') as h:
        data = h.read()
    clean = build_date.sub(b'', data)
    if clean != data:
        with open(path, 'wb') as h:
            h.write(clean)
    return clean
a, b = files(base), files(work)
for f in a: content(base, f)
for f in b: content(work, f)
same = [f for f in a & b if content(base, f) == content(work, f)]
changed = len(a & b) - len(same)
print(f'reference.sh: {name}: {len(same)} identical, {changed} changed, {len(b - a)} added, {len(a - b)} removed')
sys.exit(1 if changed or a != b else 0)
PY
  diff -r "$tmp/$1-$2-base/public" "$tmp/$1-$2-work/public" > "$out/$1-$2.diff" || true
  [ -z "$strict" ] || status=1
}
last=${doxygens##* }
for v in $doxygens; do
  DOXYGEN=$(doxygen_bin "$v") || { status=1; continue; }
  export DOXYGEN
  for name; do
    case $name in pdi | unknown-kind | versions-mixed | doc | example) [ "$v" = "$last" ] || continue ;; esac
    case $name in doc | example)
      dir=doc
      if [ "$name" = example ]; then dir=exampleSite; fi
      if [ ! -f "$tmp/base/$dir/hugo.yaml" ]; then
        echo "reference.sh: $name (doxygen $v): skipped, $ref has no $dir/hugo.yaml"; continue
      fi
      if [ ! -d "$root/$dir/node_modules" ]; then
        echo "reference.sh: $name: run npx npm@11 install in $root/$dir" >&2; status=1; continue
      fi
      [ -e "$tmp/base/$dir/node_modules" ] || ln -s "$root/$dir/node_modules" "$tmp/base/$dir/node_modules"
      # The packages that the working tree's node_modules links to (exampleSite's
      # @docsy/hugoautogen) are outside the reference's directory: Node may read them.
      printf 'security:\n  node:\n    permissions:\n      allowRead: ["%s"]\n' "$root/$dir" > "$tmp/$name-node.yaml"
      if [ "$name" = example ]; then
        printf 'languages:\n  en: {weight: 1}\n  "no": {weight: 2}\n  fa: {weight: 3}\n' >> "$tmp/$name-node.yaml"
      fi
      ok=1
      for tree in base work; do
        src=$root/$dir
        if [ $tree = base ]; then src=$tmp/base/$dir; fi
        work=$tmp/$name-$v-$tree
        if ! PATH="$root/$dir/node_modules/.bin:$PATH" "$hugo" --source "$src" --config "$src/hugo.yaml,$tmp/$name-node.yaml" \
            --baseURL / --enableGitInfo=false --destination "$work/public" > "$tmp/$name-$v-$tree.log" 2>&1; then
          cat "$tmp/$name-$v-$tree.log" >&2; echo "reference.sh: $name: the $tree build failed" >&2; status=1; ok=0
        fi
      done
      [ $ok -eq 0 ] || compare "$name" "$v"
      continue ;;
    esac
    next= content=content
    case $name in
      unknown-kind) xml=$root/tests/unit/fixtures/unknown-kind ;;
      versions | versions-mixed)
        content=content-versions
        if ! dir=$(corpus sample-next); then status=1; continue; fi; next=$dir/xml
        if [ "$name" = versions-mixed ]; then
          if ! dir=$(DOXYGEN=$(doxygen_bin 1.17.0) && corpus sample); then status=1; continue; fi
        elif ! dir=$(corpus sample); then status=1; continue; fi
        xml=$dir/xml ;;
      *) if ! dir=$(corpus "$name"); then status=1; continue; fi; xml=$dir/xml ;;
    esac
    if [ ! -d "$tmp/base/tests/site/$content" ]; then
      echo "reference.sh: $name (doxygen $v): skipped, $ref has no tests/site/$content"; continue
    fi
    ok=1
    for tree in base work; do
      work=$tmp/$name-$v-$tree
      mkdir -p "$work"
      DOCSYGEN_MODULE=$root
      if [ $tree = base ]; then DOCSYGEN_MODULE=$tmp/base; fi
      # Each tree's own adapter calls and hand-written pages: they follow its module's interface.
      extra=
      if [ "$name" = sample ]; then extra="$DOCSYGEN_MODULE/tests/site/handwritten=content"; fi
      # A reference older than the corpus mounts its XML at assets/doxygen/oracle.
      target=corpus
      if grep -q 'doxygen/oracle' "$DOCSYGEN_MODULE/tests/site/$content/_content.gotmpl"; then target=oracle; fi
      # shellcheck disable=SC2086 # extra is one word or none
      site_config "$work/hugo.yaml" "$site/layouts=layouts" "$DOCSYGEN_MODULE/tests/site/$content=content" $extra \
        "$xml=assets/doxygen/$target" ${next:+"$next=assets/doxygen/next"}
      cat "$site/config.yaml" >> "$work/hugo.yaml"
      # Not --quiet: it would hide the ERROR line that errorf logs.
      if ! "$hugo" --source "$work" --destination "$work/public" > "$work/log" 2>&1; then
        cat "$work/log" >&2; echo "reference.sh: $name (doxygen $v): the $tree build failed" >&2; status=1; ok=0
      fi
    done
    unset DOCSYGEN_MODULE
    [ $ok -eq 1 ] || continue
    compare "$name" "$v"
  done
done
if [ -n "$(ls "$out")" ]; then
  echo "reference.sh: differences are in $out; sh tests/reference-summary.sh $out groups them"
fi
exit $status
