#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Generate the Doxygen XML of a corpus entry into OUT/xml, with the overrides that keep it
# complete (source listings included).
#
# Usage: sh tests/corpus/generate.sh NAME OUT
#   NAME  sample, sample-c or sample-next: tests/corpus/<dir>/Doxyfile[.<variant>], run from <dir>
#         (see corpus_entry in tests/lib.sh). pdi has no sources: its XML is committed.
# DOXYGEN selects the Doxygen binary (default: doxygen; the test scripts set it, tests/lib.sh).
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
name=$1
mkdir -p "$2"
out=$(cd "$2" && pwd)
doxygen=${DOXYGEN:-doxygen}

case $name in
  sample) dir=$root/tests/corpus/sample; doxyfile=$dir/Doxyfile ;;
  sample-c) dir=$root/tests/corpus/sample; doxyfile=$dir/Doxyfile.c ;;
  sample-next) dir=$root/tests/corpus/sample-next; doxyfile=$dir/Doxyfile ;;
  *) echo "generate.sh: unknown corpus entry $name (sample, sample-c or sample-next)" >&2; exit 2 ;;
esac
[ -f "$doxyfile" ] || { echo "generate.sh: no Doxyfile at $doxyfile" >&2; exit 1; }

rm -rf "$out/xml"
cd "$dir"
{
  cat "$doxyfile"
  printf '%s\n' GENERATE_HTML=NO GENERATE_XML=YES GENERATE_LATEX=NO XML_PROGRAMLISTING=YES \
    HAVE_DOT=NO QUIET=YES WARNINGS=NO WARN_IF_UNDOCUMENTED=NO WARN_IF_INCOMPLETE_DOC=NO \
    WARN_IF_DOC_ERROR=NO "OUTPUT_DIRECTORY=$out" XML_OUTPUT=xml
} | "$doxygen" -
