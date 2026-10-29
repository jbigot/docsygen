#!/bin/sh
# Compare the Docsy test site built with the module of the baseline commit and with the working
# tree's: the baseline's output is the reference that the Docsy flavor is checked against.
#
# Usage: sh tests/reference.sh [NAME ...]
#   NAME   sample, sample-c, pdi or unknown-kind, as tests/site/run.sh (default: all four)
# The baseline is the commit in tests/reference-base, checked out in a git worktree that is
# removed on exit. Both builds use the working tree's tests/site layouts and configuration, so that
# the module makes the difference; the content (adapter calls, hand-written pages) is each tree's
# own, since it follows its module's interface: a page that only the working tree has is added. Prints, per site,
#   reference.sh: NAME: N files identical, A added
# and the added files. A changed or removed file fails, with the first 20 lines of diff -r.
# Moving the baseline: write the new commit into tests/reference-base, in the commit of the
# task whose output change was reviewed. Exit 1 on any failure.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
[ $# -gt 0 ] || set -- sample sample-c pdi unknown-kind
base=$(cat "$root/tests/reference-base")
git -C "$root" worktree add -q -d "$tmp/base" "$base"
trap 'git -C "$root" worktree remove --force "$tmp/base"; rm -rf "$tmp"' EXIT
# The test sites import docsygen through module.replacements, which this variable overrides.
unset HUGO_MODULE_REPLACEMENTS
site=$root/tests/site

status=0
for name; do
  case $name in
    unknown-kind) xml=$root/tests/unit/fixtures/unknown-kind ;;
    *) if ! dir=$(oracle "$name"); then status=1; continue; fi; xml=$dir/xml ;;
  esac
  ok=1
  for tree in base work; do
    work=$tmp/$name-$tree
    mkdir -p "$work"
    DOCSYGEN_MODULE=$root
    if [ $tree = base ]; then DOCSYGEN_MODULE=$tmp/base; fi
    # Each tree's own adapter calls and hand-written pages: they follow its module's interface.
    extra=
    if [ "$name" = sample ]; then extra="$DOCSYGEN_MODULE/tests/site/handwritten=content"; fi
    # shellcheck disable=SC2086 # extra is one word or none
    site_config "$work/hugo.yaml" "$site/layouts=layouts" "$DOCSYGEN_MODULE/tests/site/content=content" $extra "$xml=assets/doxygen/oracle"
    cat "$site/config.yaml" >> "$work/hugo.yaml"
    # Not --quiet: it would hide the ERROR line that errorf logs.
    if ! "$hugo" --source "$work" --destination "$work/public" > "$work/log" 2>&1; then
      cat "$work/log" >&2; echo "reference.sh: $name: the $tree build failed" >&2; status=1; ok=0
    fi
  done
  unset DOCSYGEN_MODULE
  [ $ok -eq 1 ] || continue
  python3 -I - "$tmp/$name-base/public" "$tmp/$name-work/public" "$name" <<'EOF' && continue
import filecmp, os, sys
base, work, name = sys.argv[1:]
def files(top):
    return {os.path.relpath(os.path.join(d, f), top) for d, _, fs in os.walk(top) for f in fs}
a, b = files(base), files(work)
same = sorted(f for f in a & b if filecmp.cmp(os.path.join(base, f), os.path.join(work, f), shallow=False))
changed = sorted(f for f in a & b if f not in same)
for f in sorted(b - a): print(f'reference.sh: {name}: added {f}')
for f in changed: print(f'reference.sh: {name}: changed {f}')
for f in sorted(a - b): print(f'reference.sh: {name}: removed {f}')
print(f'reference.sh: {name}: {len(same)} files identical, {len(b - a)} added')
sys.exit(1 if changed or a - b else 0)
EOF
  diff -r "$tmp/$name-base/public" "$tmp/$name-work/public" | head -n 20 >&2 || true
  status=1
done
exit $status
