#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Check the links, ids and roles of a built Docsy site that renders the sample's or sample-next's
# XML (doc/, exampleSite/, tests/docsy/), with check.py.
#
# Usage: sh tests/site/check_built.sh PUBLIC XMLDIR ROOT [OPTION ...]
#   XMLDIR  the XML of the version root ROOT (/docs/api/latest/), whose paths.json the build
#           published: the site mounts tests/site/hooks over its layouts
#   OPTION  check.py's: --under DIR for a site with pages of its own, --links PAGE EXPECTED.json
set -eu

here=$(cd "$(dirname "$0")" && pwd)
log=$(mktemp)
trap 'rm -f "$log"' EXIT
if ! python3 -I "$here/check.py" "$@" > "$log" 2>&1; then
  cat "$log" >&2; exit 1
fi
tail -n 1 "$log"
