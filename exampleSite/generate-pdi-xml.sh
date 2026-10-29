#!/bin/sh
# Regenerate assets/doxygen/NAME/ from a PDI checkout, with the Doxygen configuration PDI
# uses for its own documentation: the Doxyfile that PDI's CMake build configures in
# <build>/pdi/docs/ (Doxyfile, or Doxyfile.doxygen_doc for releases that use
# doxygen_add_docs). Only XML is generated, without source listings, since PDI's HTML
# documentation has none (SOURCE_BROWSER = NO). assets/doxygen/README.md says how each
# directory was made.
#
# Usage: sh generate-pdi-xml.sh PDI_SOURCE_DIR CONFIGURED_DOXYFILE [NAME]
#   NAME  the directory under assets/doxygen/ (default: pdi)
set -eu

site=$(cd "$(dirname "$0")" && pwd)
pdi_source=$1
doxyfile=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
name=${3:-pdi}
out=$site/assets/doxygen

rm -rf "${out:?}/$name"
mkdir -p "$out"
cd "$pdi_source"  # PDI's doc target runs doxygen from the source root
{
  cat "$doxyfile"
  printf '%s\n' GENERATE_HTML=NO GENERATE_XML=YES "OUTPUT_DIRECTORY=$out" "XML_OUTPUT=$name" \
    XML_PROGRAMLISTING=NO QUIET=YES WARNINGS=NO WARN_IF_UNDOCUMENTED=NO WARN_IF_INCOMPLETE_DOC=NO \
    WARN_IF_DOC_ERROR=NO
} | doxygen -
