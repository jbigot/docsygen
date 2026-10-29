# Shared by the test scripts, which source it: . "$(dirname "$0")/../lib.sh"
# It sets:
#   root  the repository root
#   hugo  the Hugo binary: HUGO, else the example site's npm-installed one, else hugo from PATH
#   tmp   a scratch directory, removed on exit unless DOCSYGEN_KEEP is set (a script that sets its
#         own EXIT trap removes it)
# and defines oracle and site_config, below.

root=$(CDPATH='' cd -- "$(dirname -- "$0")" 2> /dev/null && git rev-parse --show-toplevel 2> /dev/null) \
  || root=$(git rev-parse --show-toplevel)
# The npm package's .bin/hugo is a Node.js wrapper around this binary: a test that kills
# hugo server must kill the binary itself.
hugo=${HUGO:-$root/exampleSite/node_modules/hugo-extended/bin/hugo}
[ -x "$hugo" ] || hugo=hugo
tmp=$(mktemp -d)
if [ -n "${DOCSYGEN_KEEP:-}" ]; then echo "lib.sh: keeping $tmp" >&2; else trap 'rm -rf "$tmp"' EXIT; fi

# oracle NAME: print the directory that holds Doxygen's xml/ and html/ for NAME (sample,
# sample-c or pdi), generating them if needed (tests/oracle/generate.sh).
# The samples are generated once per test run, in $tmp, or in DOCSYGEN_ORACLES when it is set
# (shared by the scripts a script runs: tests/reader-diff.sh). pdi is generated once into the kept
# cache /var/tmp/docsygen-oracle/pdi-9645c141, and needs PDI_SRC the first time.
oracle() {
  case $1 in
    sample | sample-c) dir=${DOCSYGEN_ORACLES:-$tmp/oracle}/$1 ;;
    pdi) dir=/var/tmp/docsygen-oracle/pdi-9645c141 ;;
    *) echo "oracle: unknown oracle $1 (sample, sample-c or pdi)" >&2; return 2 ;;
  esac
  if [ ! -d "$dir/xml" ] || [ ! -d "$dir/html" ]; then
    if [ "$1" = pdi ] && [ -z "${PDI_SRC:-}" ]; then
      echo "oracle: set PDI_SRC to a PDI checkout to generate the pdi oracle in $dir" >&2
      return 1
    fi
    rm -rf "$dir.new"
    sh "$root/tests/oracle/generate.sh" "$1" "$dir.new" >&2 || return 1
    rm -rf "$dir"
    mv "$dir.new" "$dir"
  fi
  printf '%s\n' "$dir"
}

# site_config FILE [SOURCE=TARGET ...]: write to FILE the module configuration of a test site
# that imports docsygen from this repository, as a site imports a module. Each SOURCE (absolute,
# or relative to the site) is mounted at TARGET. Project mounts replace the site's default ones,
# so a site that has its own layouts or content lists them too; a site's own mounts override
# the module's files of the same name. Append the rest of the configuration to FILE.
# DOCSYGEN_MODULE, when set, is the docsygen tree imported in place of this repository's
# (tests/reference.sh).
# With DOCSYGEN_READER=native, tests/reader-native is mounted first, so that docsygen reads the
# XML with the native decoder (tests/reader-diff.sh).
site_config() {
  config=$1; shift
  if [ "${DOCSYGEN_READER:-template}" = native ]; then set -- "$root/tests/reader-native/layouts=layouts" "$@"; fi
  {
    printf 'module:\n'
    printf '  replacements: "github.com/jbigot/docsygen -> %s"\n' "${DOCSYGEN_MODULE:-$root}"
    printf '  imports:\n    - path: github.com/jbigot/docsygen\n'
    if [ $# -gt 0 ]; then
      printf '  mounts:\n'
      for mount in "$@"; do
        printf '    - {source: "%s", target: "%s"}\n' "${mount%%=*}" "${mount#*=}"
      done
    fi
  } > "$config"
}
