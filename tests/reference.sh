#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Build the Docsy-flavor test site of every corpus entry, with each supported Doxygen's XML, with
# the module of a reference revision and with the working tree's, and report what changed.
#
# Usage: [REF=REVISION] [REFERENCE_OUT=DIR] sh tests/reference.sh [--strict] [NAME ...]
#   NAME      sample, sample-c, pdi, unknown-kind or versions (default: all)
#   REF       the revision whose output is the reference (default HEAD: the working tree against
#             the last commit; REF=main for a branch)
#   REFERENCE_OUT  where the reports go (default /var/tmp/docsygen-reference)
#   --strict  fail on any change, for a refactor that must not change the output
# The reference is checked out in a git worktree that is removed on exit. Both builds use the
# working tree's tests/site layouts and configuration, so that the module makes the difference;
# the content (adapter calls, hand-written pages) is each tree's own, since it follows its
# module's interface, and an entry that the reference has no content for is skipped. Prints, per
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
[ $# -gt 0 ] || set -- sample sample-c pdi unknown-kind versions
ref=${REF:-HEAD}
out=${REFERENCE_OUT:-/var/tmp/docsygen-reference}
doxygens=${REFERENCE_DOXYGENS:-"1.17.0 1.18.0"}
git -C "$root" worktree add -q -d "$tmp/base" "$ref"
trap 'git -C "$root" worktree remove --force "$tmp/base"; rm -rf "$tmp"' EXIT
# The test sites import docsygen through module.replacements, which this variable overrides.
unset HUGO_MODULE_REPLACEMENTS
rm -rf "$out"
mkdir -p "$out"
site=$root/tests/site

status=0
for v in $doxygens; do
  DOXYGEN=$(doxygen_bin "$v") || { status=1; continue; }
  export DOXYGEN
  for name; do
    next= content=content
    case $name in
      unknown-kind) xml=$root/tests/unit/fixtures/unknown-kind ;;
      versions)
        content=content-versions
        if ! dir=$(corpus sample-next); then status=1; continue; fi; next=$dir/xml
        if ! dir=$(corpus sample); then status=1; continue; fi; xml=$dir/xml ;;
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
    python3 -I - "$tmp/$name-$v-base/public" "$tmp/$name-$v-work/public" "$name (doxygen $v)" <<'PY' && continue
import filecmp, os, sys
base, work, name = sys.argv[1:]
def files(top):
    return {os.path.relpath(os.path.join(d, f), top) for d, _, fs in os.walk(top) for f in fs}
a, b = files(base), files(work)
same = [f for f in a & b if filecmp.cmp(os.path.join(base, f), os.path.join(work, f), shallow=False)]
changed = len(a & b) - len(same)
print(f'reference.sh: {name}: {len(same)} identical, {changed} changed, {len(b - a)} added, {len(a - b)} removed')
sys.exit(1 if changed or a != b else 0)
PY
    diff -r "$tmp/$name-$v-base/public" "$tmp/$name-$v-work/public" > "$out/$name-$v.diff" || true
    [ -z "$strict" ] || status=1
  done
done
if [ -n "$(ls "$out")" ]; then
  echo "reference.sh: differences are in $out; sh tests/reference-summary.sh $out groups them"
fi
exit $status
