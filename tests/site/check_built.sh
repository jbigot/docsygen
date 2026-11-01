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
# The sample's member demo::io::print has the id "print", which Docsy's print link has on the same
# page (TODO.md, "Anchors can collide with Docsy's ids"): that one error is expected, and only it.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
log=$(mktemp)
trap 'rm -f "$log"' EXIT
python3 -I "$here/check.py" "$@" > "$log" 2>&1 || true
known="[^ ]*/demo/io/index.html: id 'print' appears 2 times"
if grep -v "^$known\$" "$log" | grep -qv "^check.py: "; then
  cat "$log" >&2; exit 1
fi
tail -n 1 "$log"
