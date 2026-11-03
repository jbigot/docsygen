#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Build the Docsy test site and check how docsygen's versions meet Docsy. The site is the
# documentation site (doc/: its configuration, Docsy and node_modules) with the content of
# tests/docsy/content: sample-next as main and as 2.0, the latest release, the sample as 1.0, and
# as 0.9 by another adapter file and in another place (/archive/), plus hand-written pages.
#
# Usage: sh tests/docsy/check.sh
# The build fails on any WARN or ERROR (--printPathWarnings included). Then:
#   - tests/site/check_built.sh on each version root, and the links of the hand-written guide
#     (expected-links.json);
#   - each page of /docs/latest/ has a redirect at /docs/2.0/ (tests/site/check_redirects.py);
#   - the version menu, the canonical link and the notice of the pages of versions-expected.json
#     (check_versions.py);
#   - check_docsy.py: hand-written pages, sections, search index, sitemap, print pages, llms.txt,
#     and a build with a baseURL that has a path;
#   - a second build is identical: adapter files run concurrently, in no fixed order;
#   - a development build of main and the latest release warns that the guide links to 1.0 and
#     0.9 as text, and nothing else.
# HUGO selects the Hugo binary (tests/lib.sh: the Hugo fork by default). Hugo needs go for its
# modules, and `npx npm@11 install` must have run in doc/.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../lib.sh"
doc=$root/doc
sample=$(corpus sample)/xml
next=$(corpus sample-next)/xml
export PATH="$doc/node_modules/.bin:$PATH"
{
  printf 'module:\n  mounts:\n'
  printf '    - {source: "%s", target: content}\n' "$here/content"
  printf '    - {source: assets/scss, target: assets/scss}\n'
  printf '    - {source: "%s", target: assets/doxygen/sample}\n' "$sample"
  printf '    - {source: "%s", target: assets/doxygen/next}\n' "$next"
  printf '    - {source: "%s", target: layouts}\n' "$root/tests/site/hooks"
  printf 'outputs:\n  home: [HTML, RSS, LLMS]\n'
  # Hugo's table of contents stops at level 3, the members; a section in one is a level 4 heading.
  printf 'markup:\n  tableOfContents:\n    endLevel: 5\n'
} > "$tmp/docsy.yaml"
printf 'params:\n  docsygen:\n    versions: [main, latest]\n' > "$tmp/development.yaml"

# build NAME [HUGO_ARG ...]: build the site into $tmp/NAME, its log in $tmp/NAME.log.
build() {
  name=$1; shift
  # Not --quiet: it would hide the ERROR line that errorf logs. Absolute paths: with relative
  # ones, Hugo doesn't find the modules that doc/go.mod replaces.
  if ! "$hugo" --source "$doc" --destination "$tmp/$name" "$@" > "$tmp/$name.log" 2>&1; then
    cat "$tmp/$name.log" >&2; echo "check.sh: the $name build failed" >&2; exit 1
  fi
}
build public --config "$doc/hugo.yaml,$tmp/docsy.yaml" --baseURL https://example.org/ --printPathWarnings
status=0
if grep -E 'WARN|ERROR' "$tmp/public.log" >&2; then status=1; fi
check() { sh "$root/tests/site/check_built.sh" "$tmp/public" "$@" || status=1; }
check "$next" /docs/main/ --links docs/guide/index.html "$here/expected-links.json"
check "$next" /docs/latest/
check "$sample" /docs/1.0/
check "$sample" /archive/0.9/
python3 -I "$root/tests/site/check_redirects.py" "$tmp/public" /docs/latest/ /docs/2.0/ || status=1
python3 -I "$here/check_versions.py" "$tmp/public" "$here/versions-expected.json" || status=1
build based --config "$doc/hugo.yaml,$tmp/docsy.yaml" --baseURL https://example.org/sub/
python3 -I "$here/check_docsy.py" "$tmp/public" "$tmp/based" || status=1
build again --config "$doc/hugo.yaml,$tmp/docsy.yaml" --baseURL https://example.org/
if ! diff -r "$tmp/public" "$tmp/again" > "$tmp/again.diff"; then
  head -n 20 "$tmp/again.diff" >&2; echo "check.sh: two builds differ" >&2; status=1
fi
build development --config "$doc/hugo.yaml,$tmp/docsy.yaml,$tmp/development.yaml" --environment development
for v in 1.0 0.9; do
  warning="docsygen: version \"$v\" is not built here: /docs/guide links to it as text"
  if ! grep -qF "$warning" "$tmp/development.log"; then echo "check.sh: missing the warning: $warning" >&2; status=1; fi
done
if grep -E 'WARN|ERROR' "$tmp/development.log" | grep -v 'docsygen: version "\(1\.0\|0\.9\)" is not built here: /docs/guide links to it as text' >&2; then
  status=1
fi
[ $status -eq 0 ] && echo "check.sh: OK"
exit $status
