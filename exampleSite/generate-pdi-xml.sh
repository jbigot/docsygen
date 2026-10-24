#!/bin/sh
# Regenerate assets/doxygen/pdi/ from a PDI checkout, with the Doxygen configuration PDI
# uses for its own documentation: the Doxyfile that PDI's CMake build configures in
# <build>/pdi/docs/. Only XML is generated, without source listings, since PDI's HTML
# documentation has none (SOURCE_BROWSER = NO).
#
# Usage: sh generate-pdi-xml.sh PDI_SOURCE_DIR CONFIGURED_DOXYFILE
set -eu

site=$(cd "$(dirname "$0")" && pwd)
pdi_source=$1
doxyfile=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
out=$site/assets/doxygen

rm -rf "${out:?}/pdi"
mkdir -p "$out"
cd "$pdi_source"  # PDI's doc target runs doxygen from the source root
{
  cat "$doxyfile"
  printf '%s\n' GENERATE_HTML=NO GENERATE_XML=YES "OUTPUT_DIRECTORY=$out" XML_OUTPUT=pdi \
    XML_PROGRAMLISTING=NO QUIET=YES WARNINGS=NO WARN_IF_UNDOCUMENTED=NO WARN_IF_INCOMPLETE_DOC=NO \
    WARN_IF_DOC_ERROR=NO
} | doxygen -
