#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Run the corpus against each supported Doxygen version and each Hugo: the Hugo fork's
# docsygen-native, where docsygen reads the XML with the native decoder, and the module's minimum
# release (hugoVersion.min in hugo.yaml), where it reads it with the template reader.
#
# Usage: sh tests/matrix.sh
# For each Doxygen version (DOXYGEN set to it) and each Hugo (HUGO, and DOCSYGEN_HUGO_KIND, native
# or release): tests/site/run.sh, which builds every corpus entry; coverage.py once per Doxygen
# version, on the sample's XML; and once per Hugo, with the latest Doxygen, tests/unit/run.sh and
# the Docsy sites: doc/check.sh, exampleSite/check.sh and tests/docsy/check.sh.
# The release binaries are downloaded once into the kept cache /var/tmp/docsygen-matrix.
# Exit 1 on any failure.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
doxygens="1.17.0 1.18.0"
hugo_min=$(sed -n 's/^ *min: *//p' "$root/hugo.yaml")

status=0
fail() { echo "matrix.sh: FAILED: $*" >&2; status=1; }

hugo_release=$cache/hugo-$hugo_min/hugo
fetch "https://github.com/gohugoio/hugo/releases/download/v$hugo_min/hugo_extended_${hugo_min}_linux-amd64.tar.gz" \
  "$cache/hugo-$hugo_min" || fail "no Hugo $hugo_min"
fork=$hugo

for v in $doxygens; do
  printf '=== Doxygen %s\n' "$v"
  DOXYGEN=$(doxygen_bin "$v") || { fail "$v: no Doxygen"; continue; }
  export DOXYGEN
  "$DOXYGEN" --version
  python3 -I "$root/tests/corpus/sample/coverage.py" "$(corpus sample)/xml" || fail "$v: coverage.py"
  for kind in native release; do
    case $kind in native) HUGO=$fork ;; release) HUGO=$hugo_release ;; esac
    DOCSYGEN_HUGO_KIND=$kind
    export HUGO DOCSYGEN_HUGO_KIND
    printf -- '--- Hugo %s\n' "$kind"
    sh "$root/tests/site/run.sh" || fail "Doxygen $v, Hugo $kind: site"
  done
done
unset HUGO DOCSYGEN_HUGO_KIND

for kind in native release; do
  case $kind in native) HUGO=$fork ;; release) HUGO=$hugo_release ;; esac
  DOCSYGEN_HUGO_KIND=$kind
  export HUGO DOCSYGEN_HUGO_KIND
  printf '=== unit and Docsy sites, Hugo %s\n' "$kind"
  sh "$root/tests/unit/run.sh" || fail "Hugo $kind: unit"
  sh "$root/doc/check.sh" || fail "Hugo $kind: doc"
  sh "$root/exampleSite/check.sh" || fail "Hugo $kind: example"
  sh "$root/tests/docsy/check.sh" || fail "Hugo $kind: docsy"
done
exit $status
