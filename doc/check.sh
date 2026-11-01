#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Build the documentation site and check its links and ids (tests/site/check.py).
#
# Usage: sh doc/check.sh
# HUGO selects the Hugo binary (tests/lib.sh: the Hugo fork by default); set it to a released
# Hugo to check the site with the template reader. Hugo needs go for its modules.
# Known: the sample's member demo::io::print has the id "print", which Docsy's print link has on
# the same page (TODO.md, "Anchors can collide with Docsy's ids"): that one error is expected.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../tests/lib.sh"
export PATH="$here/node_modules/.bin:$PATH"
# Not --quiet: it would hide the ERROR line that errorf logs.
if ! "$hugo" --source "$here" --baseURL / --destination "$tmp/public" > "$tmp/log" 2>&1; then
  cat "$tmp/log" >&2; exit 1
fi
status=0
if grep -E 'WARN|ERROR' "$tmp/log" >&2; then status=1; fi
python3 -I "$root/tests/site/check.py" "$tmp/public" - - > "$tmp/check.log" 2>&1 || true
if grep -v "^docs/reference/latest/api/demo/io/index.html: id 'print' appears 2 times$" "$tmp/check.log" | grep -v "^check.py: .* 1 errors$" | grep -qv "^check.py: "; then
  cat "$tmp/check.log" >&2; status=1
fi
tail -n 1 "$tmp/check.log"
exit $status
