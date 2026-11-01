#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Build the documentation site and check its links and ids (tests/site/check.py).
#
# Usage: sh doc/check.sh
# HUGO selects the Hugo binary (tests/lib.sh: the Hugo fork by default); set it to a released
# Hugo to check the site with the template reader. Hugo needs go for its modules.
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
sh "$root/tests/site/check_built.sh" "$tmp/public" || status=1
exit $status
