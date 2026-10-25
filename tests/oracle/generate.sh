#!/bin/sh
# Generate an oracle: Doxygen's XML and its HTML, written by the same run into OUT/xml and
# OUT/html, with the overrides that keep the HTML plain (no tree view, search, dot, custom layout,
# header, footer or stylesheet) and the XML complete (source listings included).
#
# Usage: sh tests/oracle/generate.sh sample|sample-c|pdi OUT
#   sample, sample-c  tests/sample/Doxyfile or Doxyfile.c, run from tests/sample
#   pdi  PDI's own Doxyfile, run in PDI_SRC as PDI's doc target does. PDI_SRC must be a clean
#        checkout of 9645c141 with its build tree, and PDI_DOXYFILE (default: the one that
#        CMake configures in PDI_SRC/.build/ClangDevel/PDI/src/PDI-build/pdi/docs/) its
#        configured Doxyfile.
# DOXYGEN selects the Doxygen binary (default: doxygen).
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
name=$1
mkdir -p "$2"
out=$(cd "$2" && pwd)
doxygen=${DOXYGEN:-doxygen}

case $name in
  sample) dir=$root/tests/sample; doxyfile=$dir/Doxyfile ;;
  sample-c) dir=$root/tests/sample; doxyfile=$dir/Doxyfile.c ;;
  pdi)
    dir=${PDI_SRC:?"PDI_SRC must name a PDI checkout to generate the pdi oracle"}
    build=$dir/.build/ClangDevel/PDI/src/PDI-build/pdi
    doxyfile=${PDI_DOXYFILE:-$build/docs/Doxyfile}
    head=$(git -C "$dir" rev-parse HEAD)
    case $head in
      9645c141*) ;;
      *) echo "generate.sh: PDI_SRC is at $head, not 9645c141" >&2; exit 1 ;;
    esac
    if [ -n "$(git -C "$dir" status --porcelain)" ]; then
      echo "generate.sh: PDI_SRC has uncommitted changes" >&2; exit 1
    fi
    for header in "$build/pdi/export.h" "$build/pdi/version.h"; do
      [ -f "$header" ] || { echo "generate.sh: $header is missing: build PDI first" >&2; exit 1; }
    done
    ;;
  *) echo "generate.sh: unknown oracle $name (sample, sample-c or pdi)" >&2; exit 2 ;;
esac
[ -f "$doxyfile" ] || { echo "generate.sh: no Doxyfile at $doxyfile" >&2; exit 1; }

rm -rf "$out/xml" "$out/html"
cd "$dir"
{
  cat "$doxyfile"
  printf '%s\n' GENERATE_HTML=YES GENERATE_XML=YES GENERATE_LATEX=NO XML_PROGRAMLISTING=YES \
    GENERATE_TREEVIEW=NO SEARCHENGINE=NO USE_MATHJAX=YES HTML_DYNAMIC_SECTIONS=NO \
    HTML_CODE_FOLDING=NO HTML_COPY_CLIPBOARD=NO HAVE_DOT=NO LAYOUT_FILE= HTML_HEADER= \
    HTML_FOOTER= HTML_EXTRA_STYLESHEET= QUIET=YES WARNINGS=NO WARN_IF_UNDOCUMENTED=NO \
    WARN_IF_INCOMPLETE_DOC=NO WARN_IF_DOC_ERROR=NO "OUTPUT_DIRECTORY=$out" XML_OUTPUT=xml \
    HTML_OUTPUT=html
} | "$doxygen" -
