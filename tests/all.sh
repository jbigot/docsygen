#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Run every suite of the standard check, in order, and stop at the first failure.
#
# Usage: sh tests/all.sh
# The sites need go for their modules, and `npx npm@11 install` run in doc/ and exampleSite/. Prints one line per suite, its last line of output
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
run unit sh tests/unit/run.sh
run site sh tests/site/run.sh
run tools sh tests/tools/run.sh
run snapshot sh tests/corpus/snapshot.sh --check
run doc sh doc/check.sh
run example sh exampleSite/check.sh
run docsy sh tests/docsy/check.sh
run reference sh tests/reference.sh
run reader-diff sh tests/reader-diff.sh
echo "all.sh: OK"
