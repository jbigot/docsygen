#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Regenerate assets/doxygen/NAME/ from a PDI checkout, with the Doxygen configuration PDI
# uses for its own documentation: the Doxyfile that PDI's CMake build configures in
# <build>/pdi/docs/ (Doxyfile, or Doxyfile.doxygen_doc for releases that use
# doxygen_add_docs). Only XML is generated, without source listings, since PDI's HTML
# documentation has none (SOURCE_BROWSER = NO). assets/doxygen/README.md says how each
# directory was made.
#
# Usage: sh generate-pdi-xml.sh PDI_SOURCE_DIR CONFIGURED_DOXYFILE [NAME]
#   NAME  the directory under assets/doxygen/ (default: pdi)
# DOXYGEN selects the Doxygen binary (default: the oracle's, Doxygen 1.18.0, as tests/lib.sh
# downloads it).
set -eu

site=$(cd "$(dirname "$0")" && pwd)
pdi_source=$1
doxyfile=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
name=${3:-pdi}
doxygen=${DOXYGEN:-/var/tmp/docsygen-matrix/doxygen-1.18.0/doxygen-1.18.0/bin/doxygen}
out=$site/assets/doxygen

rm -rf "${out:?}/$name"
mkdir -p "$out"
cd "$pdi_source"  # PDI's doc target runs doxygen from the source root
{
  cat "$doxyfile"
  printf '%s\n' GENERATE_HTML=NO GENERATE_XML=YES "OUTPUT_DIRECTORY=$out" "XML_OUTPUT=$name" \
    XML_PROGRAMLISTING=NO QUIET=YES WARNINGS=NO WARN_IF_UNDOCUMENTED=NO WARN_IF_INCOMPLETE_DOC=NO \
    WARN_IF_DOC_ERROR=NO
} | "$doxygen" -

# Doxygen's output carries no license: give each file the one it has in the repository (REUSE), in
# a .license file next to it. PDI's XML and images are PDI's (BSD-3-Clause); the schemas and the
# stylesheet are Doxygen's, and xml.xsd the W3C's.
for file in "$out/$name"/*; do
  case ${file##*/} in
    xml.xsd) holder='2001 W3C (MIT, ERCIM, Keio, Beihang)'; spdx=W3C-20150513 ;;
    combine.xslt|*.xsd) holder='1997-2026 Dimitri van Heesch'; spdx=GPL-2.0-or-later ;;
    *) holder="2015-2026 Commissariat a l'energie atomique et aux energies alternatives (CEA)"
       spdx=BSD-3-Clause ;;
  esac
  # The tags are split so that reuse doesn't read them in this script.
  printf '%s\n%s\n' "SPDX-""FileCopyrightText: $holder" "SPDX-""License-Identifier: $spdx" \
    > "$file.license"
done
