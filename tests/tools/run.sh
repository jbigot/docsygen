#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Check that tools/check.py, the check docsygen offers sites, reports what a build can't: a link
# to a fragment that its page lacks (a claiming page that embeds only some of the members linked
# to), and an id that appears twice (a member's anchor that equals a hand-written heading's).
#
# Usage: sh tests/tools/run.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
out=$(python3 -I "$root/tools/check.py" "$here/fixture/public" - - 2>&1) && { echo "tools/run.sh: check.py passed a broken site" >&2; exit 1; }
status=0
for want in "a/index.html: /b/#dg-resize leads to no id in b/index.html" "b/index.html: id 'dg-width' appears 2 times"; do
  case $out in *"$want"*) ;; *) printf 'tools/run.sh: check.py did not report: %s\n%s\n' "$want" "$out" >&2; status=1 ;; esac
done
[ $status -ne 0 ] || echo "tools/run.sh: OK"
exit $status
