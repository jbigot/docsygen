#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Build the Docsy-flavor test site from each corpus entry and check its output: check.py on its
# two version roots, /ref/ and /latest/ (tests/site/content/_content.gotmpl), and the redirects
# from /1.0/ to /latest/ (check_redirects.py).
#
# Usage: sh tests/site/run.sh [NAME ...]
#   NAME   sample, sample-c, pdi (the corpus, tests/lib.sh), versions (sample as 1.0, sample-next as
#          2.0, the latest) or unknown-kind (tests/unit/fixtures/unknown-kind); all by default
# A build fails on any WARN or ERROR line, but an expected warning: the unknown-kind fixture's, and
# the sample's for its eqnarray* formula, an environment KaTeX lacks (its source is shown).
# Exit 1 on any failure.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../lib.sh"
[ $# -gt 0 ] || set -- sample sample-c pdi unknown-kind versions
status=0
for name; do
  printf '== %s\n' "$name"
  expected=
  case $name in
    versions) if ! dir=$(corpus sample); then status=1; continue; fi; xml=$dir/xml
       expected='docsygen: formula "\\begin{eqnarray*}' ;;
    unknown-kind) xml=$root/tests/unit/fixtures/unknown-kind; expected='docsygen: unknown compound kind "widgetkind"' ;;
    *) if ! dir=$(corpus "$name"); then status=1; continue; fi; xml=$dir/xml
       if [ "$name" = sample ]; then expected='docsygen: formula "\\begin{eqnarray*}'; fi ;;
  esac
  work=$tmp/$name
  content=content next=
  if [ "$name" = versions ]; then
    if ! dir=$(corpus sample-next); then status=1; continue; fi
    content=content-versions next=$dir/xml
  fi
  mkdir -p "$work"
  # The hand-written page links to the sample's symbols.
  extra=
  if [ "$name" = sample ]; then extra="$here/handwritten=content"; fi
  # shellcheck disable=SC2086 # extra is one word or none
  site_config "$work/hugo.yaml" "$here/layouts=layouts" "$here/$content=content" $extra "$xml=assets/doxygen/corpus" ${next:+"$next=assets/doxygen/next"}
  cat "$here/config.yaml" >> "$work/hugo.yaml"
  # Not --quiet: it would hide the ERROR line that errorf logs.
  if ! "$hugo" --source "$work" --destination "$work/public" > "$work/log" 2>&1; then
    cat "$work/log" >&2; status=1; continue
  fi
  if grep -E 'WARN|ERROR' "$work/log" | grep -vF "${expected:-//nothing//}" >&2; then status=1; continue; fi
  if [ -n "$expected" ] && ! grep -qF "$expected" "$work/log"; then
    echo "run.sh: missing the warning: $expected" >&2; status=1; continue
  fi
  if [ "$name" = versions ]; then
    # 1.0 and 2.0 (the latest, at /latest/): io.hpp only in 1.0, demo::Extra only in 2.0, each root consistent.
    python3 -I "$here/check.py" "$work/public" "$xml" /1.0/ || status=1
    python3 -I "$here/check.py" "$work/public" "$next" /latest/ || status=1
    for want in "1.0 io_8hpp yes" "latest io_8hpp no" "1.0 classdemo_1_1Extra no" "latest classdemo_1_1Extra yes"; do
      set -- $want
      found=no
      if grep -rqF "data-doxygen-id=\"$2\"" "$work/public/$1"; then found=yes; fi
      [ "$found" = "$3" ] || { echo "run.sh: $2 is $found in $1, expected $3" >&2; status=1; }
    done
    python3 -I "$here/check_redirects.py" "$work/public" /latest/ /2.0/ || status=1
    continue
  fi
  links=
  if [ "$name" = sample ]; then links="--links handwritten/index.html $here/expected-links.json"; fi
  # shellcheck disable=SC2086 # links is words
  python3 -I "$here/check.py" "$work/public" "$xml" /ref/ $links || status=1
  python3 -I "$here/check.py" "$work/public" "$xml" /latest/ || status=1
  # tests/site/handwritten/handwritten/embed.md embeds demo::Widget::width in full twice: its
  # anchor once.
  if [ "$name" = sample ] && [ "$(grep -o 'id="width"' "$work/public/handwritten/embed/index.html" | wc -l)" -ne 1 ]; then
    echo "run.sh: the anchor of demo::Widget::width is not on the embed page exactly once" >&2; status=1
  fi
  python3 -I "$here/check_redirects.py" "$work/public" /latest/ /1.0/ || status=1
done
exit $status
