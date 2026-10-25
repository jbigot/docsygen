#!/bin/sh
# Check that hugo server re-parses only the XML files that changed: editing a content file must
# re-parse nothing, and editing one XML file must re-parse that file only. partialCached alone
# doesn't do it, since Hugo clears its cache at the start of every build.
#
# Usage: sh tests/xml-parse/rebuild.sh
# HUGO selects the Hugo binary, as in run.sh. PORT (default 13998) is the server's port.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
# The npm package's .bin/hugo is a Node.js wrapper: killing it would leave the server running.
hugo=${HUGO:-$root/exampleSite/node_modules/hugo-extended/bin/hugo}
[ -x "$hugo" ] || hugo=hugo
work=$(mktemp -d)
pid=
trap '[ -z "$pid" ] || kill "$pid" 2> /dev/null || true; rm -rf "$work"' EXIT

mkdir -p "$work/content" "$work/corpus"
cp "$here"/edge/good/*.xml "$work/corpus/"
printf -- '---\ntitle: Home\n---\n' > "$work/content/_index.md"
{
  printf 'disableKinds: [taxonomy, term, rss, sitemap, page, section]\nmodule:\n  mounts:\n'
  printf '    - {source: "%s", target: layouts}\n' "$root/layouts" "$here/layouts"
  printf '    - {source: content, target: content}\n    - {source: corpus, target: assets/corpus/edge}\n'
} > "$work/hugo.yaml"

# --templateMetrics prints one table per build: the number of parse.html calls is the number
# of files parsed by that build.
"$hugo" server --source "$work" --port "${PORT:-13998}" --renderToMemory --templateMetrics \
  > "$work/log" 2>&1 &
pid=$!
builds() { grep -c 'cumulative' "$work/log" || true; }
wait_build() {
  i=0
  while [ "$(builds)" -lt "$1" ]; do
    i=$((i + 1))
    if [ $i -gt 100 ] || ! kill -0 "$pid" 2> /dev/null; then cat "$work/log" >&2; exit 1; fi
    sleep 0.2
  done
}
parses() {
  awk -v n="$1" '/cumulative/ { b++ } b == n && /_partials\/docsygen\/xml\/parse.html/ { print $(NF - 1) }' "$work/log"
}
status=0
check() {
  got=$(parses "$1")
  if [ "${got:-0}" = "$2" ]; then
    printf 'ok   %s: %s parsed\n' "$3" "$2"
  else
    printf 'FAIL %s: %s parsed instead of %s\n' "$3" "${got:-0}" "$2"; status=1
  fi
}

wait_build 1
check 1 8 'first build'
printf 'Edited.\n' >> "$work/content/_index.md"
wait_build 2
check 2 0 'after editing a content file'
printf '\n' >> "$work/corpus/merge.xml"
wait_build 3
check 3 1 'after editing one XML file'
exit $status
