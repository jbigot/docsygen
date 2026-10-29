#!/bin/sh
# Run every suite of the standard check, in order, and stop at the first failure.
#
# Usage: sh tests/all.sh
# The pdi oracle needs PDI_SRC the first time (tests/lib.sh, oracle), and the example site go or
# HUGO_MODULE_REPLACEMENTS for its modules. Prints one line per suite, its last line of output
# after it; a failing suite's output is printed in full. With ALL_LOGS set to a directory, each
# suite's output is kept there as NAME.log. Exit 1 on the first failure.
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
logs=${ALL_LOGS:-}
if [ -z "$logs" ]; then logs=$(mktemp -d); trap 'rm -rf "$logs"' EXIT; fi
mkdir -p "$logs"

# run NAME COMMAND...: run a suite, keeping its output in $logs/NAME.log.
run() {
  name=$1; shift
  log=$logs/$name.log
  printf '== %s\n' "$name"
  if ! "$@" > "$log" 2>&1; then
    cat "$log" >&2
    echo "all.sh: FAILED: $name" >&2
    exit 1
  fi
  tail -n 1 "$log"
}

cd "$root"
run oracle-unit python3 -I -m unittest discover -s tests/oracle -p 'test_*.py'
run unit sh tests/unit/run.sh
run site sh tests/site/run.sh
run info sh tests/oracle/run.sh info
run info-docsy sh tests/oracle/run.sh info-docsy
run check-docsy sh exampleSite/check-docsy.sh
run check-layout sh exampleSite/check-layout.sh
run xml-parse sh tests/xml-parse/run.sh
run reference sh tests/reference.sh
run reader-diff sh tests/reader-diff.sh
echo "all.sh: OK"
