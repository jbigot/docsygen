#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Build the documentation site and check its links, ids and roles (tests/site/check_built.sh).
#
# Usage: sh doc/check.sh
# HUGO selects the Hugo binary (tests/lib.sh: the Hugo fork by default); set it to a released
# Hugo to check the site with the template reader. Hugo needs go for its modules.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../tests/lib.sh"
export PATH="$here/node_modules/.bin:$PATH"
# The test-only hook that publishes each version root's paths.json (tests/site/hooks), mounted
# after the site's own layouts.
{
  printf 'module:\n  mounts:\n'
  printf '    - {source: "%s", target: layouts}\n' "$root/tests/site/hooks"
} > "$tmp/checks.yaml"
# Not --quiet: it would hide the ERROR line that errorf logs.
if ! "$hugo" --source "$here" --config "$here/hugo.yaml,$tmp/checks.yaml" --baseURL / --printPathWarnings \
    --destination "$tmp/public" > "$tmp/log" 2>&1; then
  cat "$tmp/log" >&2; exit 1
fi
status=0
if grep -E 'WARN|ERROR' "$tmp/log" >&2; then status=1; fi
sh "$root/tests/site/check_built.sh" "$tmp/public" "$here/assets/doxygen/sample" /docs/reference/latest/ || status=1
sh "$root/tests/site/check_chroma_css.sh" "$tmp/public" || status=1
exit $status
