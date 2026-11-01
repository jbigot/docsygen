#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Check the links and ids of a built Docsy site that renders the sample corpus entry (doc/ and
# exampleSite/), with check.py.
#
# Usage: sh tests/site/check_built.sh PUBLIC [DIR]
#   DIR  only the pages below it count (check.py --under), for a site with pages of its own
# The sample's member demo::io::print has the id "print", which Docsy's print link has on the same
# page (TODO.md, "Anchors can collide with Docsy's ids"): that one error is expected, and only it.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
log=$(mktemp)
trap 'rm -f "$log"' EXIT
python3 -I "$here/check.py" "$1" - - ${2:+--under "$2"} > "$log" 2>&1 || true
known="docs/.*/demo/io/index.html: id 'print' appears 2 times"
if grep -v "^$known\$" "$log" | grep -qv "^check.py: "; then
  cat "$log" >&2; exit 1
fi
tail -n 1 "$log"
