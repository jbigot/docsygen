#!/bin/sh
# Run the test suites against each supported Doxygen version and against the module's minimum Hugo.
#
# Usage: sh tests/matrix.sh
# Per Doxygen version (DOXYGEN set to it): coverage.py on the sample's XML, tests/xml-parse/run.sh,
# tests/site/run.sh and tests/oracle/run.sh info on sample and sample-c. The exact oracle must
# pass on 1.15.0, the version Doxygen-identical output is defined against; for the other
# versions, its counts are printed only.
# With the Hugo of module.hugoVersion.min in hugo.yaml (HUGO set to it): tests/unit/run.sh and
# tests/site/run.sh. The latter builds the pdi oracle, which needs PDI_SRC the first time
# (tests/lib.sh, oracle).
# The release binaries are downloaded once into the kept cache /var/tmp/docsygen-matrix.
# Exit 1 on any failure.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
doxygens="1.15.0 1.16.0 1.17.0 1.18.0"
hugo_min=$(sed -n 's/^ *min: *//p' "$root/hugo.yaml")
cache=/var/tmp/docsygen-matrix

# fetch URL DIR: download and unpack the tarball at URL into DIR, unless DIR exists.
fetch() {
  [ -d "$2" ] && return 0
  rm -rf "$2.new"
  mkdir -p "$2.new"
  curl -fsSL "$1" | tar -xz -C "$2.new"
  mv "$2.new" "$2"
}

status=0
fail() { echo "matrix.sh: FAILED: $*" >&2; status=1; }

for v in $doxygens; do
  printf '=== Doxygen %s\n' "$v"
  fetch "https://github.com/doxygen/doxygen/releases/download/Release_$(echo "$v" | tr . _)/doxygen-$v.linux.bin.tar.gz" \
    "$cache/doxygen-$v"
  DOXYGEN=$cache/doxygen-$v/doxygen-$v/bin/doxygen
  export DOXYGEN
  "$DOXYGEN" --version
  sh "$root/tests/oracle/generate.sh" sample "$tmp/$v/sample" || fail "$v: sample oracle"
  python3 -I "$root/tests/sample/coverage.py" "$tmp/$v/sample/xml" || fail "$v: coverage.py"
  sh "$root/tests/xml-parse/run.sh" || fail "$v: xml-parse"
  sh "$root/tests/site/run.sh" sample sample-c || fail "$v: site"
  sh "$root/tests/oracle/run.sh" info sample sample-c || fail "$v: info oracle"
  if [ "$v" = 1.15.0 ]; then
    sh "$root/tests/oracle/run.sh" exact sample sample-c || fail "$v: exact oracle"
  else
    sh "$root/tests/oracle/run.sh" exact sample sample-c 2>&1 | grep -E '^(==|scope )' || true
  fi
done
unset DOXYGEN

printf '=== Hugo %s\n' "$hugo_min"
fetch "https://github.com/gohugoio/hugo/releases/download/v$hugo_min/hugo_extended_${hugo_min}_linux-amd64.tar.gz" \
  "$cache/hugo-$hugo_min"
HUGO=$cache/hugo-$hugo_min/hugo
export HUGO
"$HUGO" version
sh "$root/tests/unit/run.sh" || fail "Hugo $hugo_min: unit"
sh "$root/tests/site/run.sh" || fail "Hugo $hugo_min: site"

exit $status
