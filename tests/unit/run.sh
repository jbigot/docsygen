#!/bin/sh
# Run the unit cases (cases/*.yaml) and the build cases (builds/*.yaml) of docsygen's partials.
#
# Usage: sh tests/unit/run.sh [REGEX]
#   REGEX (or DOCSYGEN_TEST) keeps the cases whose name matches it.
# A unit case is {name, partial, context, expect, select?, len?, flavor?}: see
# layouts/_partials/test/{context,run}.html. Cases of flavor compat (the default) run with the
# compat flavor's partials (tests/doxygen-compat) overriding the module's; cases of flavor
# docsy run in a second build without them.
# A build case is {name, partial, context, mounts?, error | warning}, one build each: the build
# must fail with an error, or succeed with a warning, that contains the given text. mounts maps
# directories of tests/unit to assets/ paths, or to layouts paths when the target starts with
# layouts.
# Every site mounts the XML of the sample and sample-c oracles, the example site's committed PDI
# XML and fixtures/doxygen-1.17 at assets/doxygen/{sample,sample-c,pdi,doxygen-1.17}.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../lib.sh"
filter=${1:-${DOCSYGEN_TEST:-}}
compat=$root/tests/doxygen-compat/layouts/_partials/docsygen
set -- "$(oracle sample)/xml=assets/doxygen/sample" "$(oracle sample-c)/xml=assets/doxygen/sample-c" \
  "$root/exampleSite/assets/doxygen/pdi=assets/doxygen/pdi" "$here/fixtures/doxygen-1.17=assets/doxygen/doxygen-1.17"

# unit_site DIR FLAVOR [SOURCE=TARGET ...]: a unit site in DIR.
unit_site() {
  dir=$1 flavor=$2; shift 2
  mkdir -p "$dir"
  # The first mount of a file wins: a case's own mounts, then the compat flavor's partials.
  if [ "$flavor" = compat ] && [ -d "$compat" ]; then set -- "$@" "$compat=layouts/_partials/docsygen"; fi
  for data in builds cases; do
    if [ -d "$here/$data" ]; then set -- "$here/$data=assets/$data" "$@"; fi
  done
  site_config "$dir/hugo.yaml" "$here/layouts=layouts" "$@"
  printf 'disableKinds: [taxonomy, term, rss, sitemap, page, section]\nparams:\n  flavor: %s\n' "$flavor" >> "$dir/hugo.yaml"
}

# build DIR: build the site in DIR, keeping its output in DIR/log.
build() {
  # Not --quiet: it would hide the ERROR line that errorf logs.
  "$hugo" --source "$1" --destination "$1/public" > "$1/log" 2>&1
}

status=0
for flavor in compat docsy; do
  unit_site "$tmp/$flavor" "$flavor" "$@"
  printf '  test: %s\n' "$(printf '%s' "$filter" | sed 's/["\\]/\\&/g; s/.*/"&"/')" >> "$tmp/$flavor/hugo.yaml"
  if ! build "$tmp/$flavor"; then cat "$tmp/$flavor/log" >&2; exit 1; fi
  grep WARN "$tmp/$flavor/log" >&2 || true
done

# A build case's mounts, as SOURCE=TARGET lines, and whether it expects an error or a warning.
python3 -I - "$tmp/compat/public/builds.json" "$filter" > "$tmp/builds" <<'EOF'
import json, re, sys
for case in json.load(open(sys.argv[1])):
    if sys.argv[2] and not re.search(sys.argv[2], case['name']): continue
    want = 'error' if 'error' in case else 'warning'
    mounts = ' '.join(f'{k}={v}' if v.split('/')[0] == 'layouts' else f'{k}=assets/{v}'
                      for k, v in (case.get('mounts') or {}).items())
    print('\t'.join([case['name'], want, case[want], mounts]))
EOF
builds=0
while IFS="$(printf '\t')" read -r name want text mounts; do
  builds=$((builds + 1))
  dir=$tmp/build-$builds
  # shellcheck disable=SC2086 # mounts are paths of tests/unit, without spaces
  unit_site "$dir" compat $(for m in $mounts; do printf '%s ' "$here/$m"; done) "$@"
  printf '  build: "%s"\n' "$name" >> "$dir/hugo.yaml"
  if build "$dir"; then outcome=built; else outcome=failed; fi
  case $want/$outcome in
    error/failed | warning/built)
      if grep -qF -- "$text" "$dir/log"; then
        printf 'ok   %s\n' "$name"
      else
        printf 'FAIL %s\n  want %s %s\n  got  %s\n' "$name" "$want" "$text" "$(grep -E 'ERROR|WARN' "$dir/log" | head -n 3)"; status=1
      fi
      ;;
    error/built) printf 'FAIL %s\n  want error %s\n  got  a successful build\n' "$name" "$text"; status=1 ;;
    warning/failed) printf 'FAIL %s\n  want warning %s\n  got  %s\n' "$name" "$text" "$(grep ERROR "$dir/log" | head -n 3)"; status=1 ;;
  esac
done < "$tmp/builds"

python3 -I - "$tmp/compat/public/results.json" "$tmp/docsy/public/results.json" "$builds" <<'EOF' || status=1
import json, sys
results = json.load(open(sys.argv[1])) + json.load(open(sys.argv[2]))
failed = [r for r in results if not r['ok']]
for r in failed: print(f"FAIL {r['name']}\n  got  {r['got']}\n  want {r['want']}")
print(f"{len(results) - len(failed)} of {len(results)} unit cases passed, {sys.argv[3]} build cases run")
sys.exit(1 if failed or not results and sys.argv[3] == '0' else 0)
EOF
exit $status
