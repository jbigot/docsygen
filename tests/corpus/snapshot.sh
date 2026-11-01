#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Refresh the committed snapshots of the sample's XML that the documentation and example sites
# render (doc/assets/doxygen/sample, exampleSite/assets/doxygen/sample) from the corpus, generated
# with Doxygen 1.18.0; with --check, fail when one differs from it instead.
#
# Usage: sh tests/corpus/snapshot.sh [--check]
# Each site builds from its own directory (the example site is meant to be copied, and
# tests/reader-diff.sh copies both), hence two copies. Doxyfile.xml keeps the OUTPUT_DIRECTORY
# /tmp/doc-xml, so that the snapshot doesn't follow the corpus cache's directory. On a refresh, a
# file that the sample no longer gives goes with its .license, and a new file gets one: MIT for
# the XML and the sample's images, and the license of Doxygen's other schemas for a schema; any
# other new file needs its .license by hand.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../lib.sh"
check=
if [ "${1:-}" = --check ]; then check=1; fi
DOXYGEN=$(doxygen_bin 1.18.0) || exit 1
export DOXYGEN
fresh=$tmp/sample
mkdir -p "$fresh"
cp -a "$(corpus sample)/xml/." "$fresh/"
sed -i "s#\(<option  id='OUTPUT_DIRECTORY' [^>]*><value><!\[CDATA\[\)[^]]*\]\]>#\1/tmp/doc-xml]]>#" "$fresh/Doxyfile.xml"

status=0
for site in doc exampleSite; do
  dest=$root/$site/assets/doxygen/sample
  if [ -n "$check" ]; then
    if ! diff -r -x '*.license' "$fresh" "$dest" > "$tmp/$site.diff"; then
      head -n 20 "$tmp/$site.diff" >&2
      echo "snapshot.sh: $site/assets/doxygen/sample is not the sample's XML: run sh tests/corpus/snapshot.sh" >&2
      status=1
    fi
    continue
  fi
  find "$dest" -type f ! -name '*.license' -delete
  cp -a "$fresh/." "$dest/"
  for license in "$dest"/*.license; do
    [ -e "${license%.license}" ] || rm "$license"
  done
  for file in "$dest"/*; do
    case $file in *.license) continue ;; esac
    [ -e "$file.license" ] && continue
    case $file in
      *.xml | *.png | *.mmd) cp "$dest/index.xml.license" "$file.license" ;;
      *.xsd) cp "$dest/compound.xsd.license" "$file.license" ;;
      *) echo "snapshot.sh: $file needs a .license" >&2; status=1 ;;
    esac
  done
done
if [ $status -eq 0 ]; then echo "snapshot.sh: OK"; fi
exit $status
