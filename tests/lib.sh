# Shared by the test scripts, which source it: . "$(dirname "$0")/../lib.sh"
# It sets:
#   root  the repository root
#   hugo  the Hugo binary: HUGO, else the Hugo fork's docsygen-native (native_hugo)
#   tmp   a scratch directory, removed on exit unless DOCSYGEN_KEEP is set (a script that sets its
#         own EXIT trap removes it)
# and exports DOXYGEN, the Doxygen binary of the oracles: DOXYGEN, else Doxygen 1.18.0, downloaded
# once into /var/tmp/docsygen-matrix (fetch); and DOCSYGEN_HUGO_KIND, native unless HUGO is set (tests/matrix.sh sets it to release
# for a released Hugo), which picks the unit cases that have a hugo key.
# It defines fetch, native_hugo, oracle and site_config, below.

root=$(CDPATH='' cd -- "$(dirname -- "$0")" 2> /dev/null && git rev-parse --show-toplevel 2> /dev/null) \
  || root=$(git rev-parse --show-toplevel)
tmp=$(mktemp -d)
if [ -n "${DOCSYGEN_KEEP:-}" ]; then echo "lib.sh: keeping $tmp" >&2; else trap 'rm -rf "$tmp"' EXIT; fi

# fetch URL DIR: download and unpack the tarball at URL into DIR, unless DIR exists.
fetch() {
  [ -d "$2" ] && return 0
  rm -rf "$2.new"
  mkdir -p "$2.new"
  curl -fsSL "$1" | tar -xz -C "$2.new"
  mv "$2.new" "$2"
}
if [ -z "${DOXYGEN:-}" ]; then
  fetch https://github.com/doxygen/doxygen/releases/download/Release_1_18_0/doxygen-1.18.0.linux.bin.tar.gz \
    /var/tmp/docsygen-matrix/doxygen-1.18.0
  DOXYGEN=/var/tmp/docsygen-matrix/doxygen-1.18.0/doxygen-1.18.0/bin/doxygen
fi
export DOXYGEN

# native_hugo: print the path of the Hugo fork's binary, the primary Hugo of the tests. HUGO_SRC
# is the fork (default: the hugo directory next to the main checkout of this repository, so that
# a linked worktree elsewhere finds it too). Its branch docsygen-native (the native decoder of
# gohugoio/hugo#15485 merged with the fix of merge) is built into
# /tmp/docsygen-hugo-doc/<commit>/hugo when that is missing, then Go's build cache is cleaned:
# building Hugo fills it. Upstream has no extended build any more: Docsy needs only Dart Sass.
native_hugo() {
  src=${HUGO_SRC:-$(dirname "$(dirname "$(cd "$root" && cd "$(git rev-parse --git-common-dir)" && pwd)")")/hugo}
  commit=$(git -C "$src" rev-parse --short=9 docsygen-native) || return 1
  bin=/tmp/docsygen-hugo-doc/$commit/hugo
  if [ ! -x "$bin" ]; then
    echo "lib.sh: building docsygen-native ($commit) into $bin" >&2
    git -C "$src" worktree add -q -d "$tmp/hugo-src" "$commit" >&2 || return 1
    mkdir -p "$(dirname "$bin")"
    built=0
    (cd "$tmp/hugo-src" && CGO_ENABLED=1 go build -o "$bin.new" .) >&2 && built=1
    git -C "$src" worktree remove --force "$tmp/hugo-src"
    go clean -cache >&2
    [ $built -eq 1 ] || { echo "lib.sh: the build of docsygen-native failed" >&2; return 1; }
    mv "$bin.new" "$bin"
  fi
  printf '%s\n' "$bin"
}
if [ -n "${HUGO:-}" ]; then
  hugo=$HUGO
else
  hugo=$(native_hugo) || exit 1
  DOCSYGEN_HUGO_KIND=${DOCSYGEN_HUGO_KIND:-native}
fi
DOCSYGEN_HUGO_KIND=${DOCSYGEN_HUGO_KIND:-}
export DOCSYGEN_HUGO_KIND

# oracle NAME: print the directory that holds Doxygen's xml/ and html/ for NAME (sample,
# sample-c or pdi), generating them if needed (tests/oracle/generate.sh).
# The samples are generated once per test run, in $tmp, or in DOCSYGEN_ORACLES when it is set
# (shared by the scripts a script runs: tests/reader-diff.sh). pdi is generated once per Doxygen
# version into the kept cache /var/tmp/docsygen-oracle/pdi-9645c141-doxygen-<version>, and needs
# PDI_SRC the first time.
oracle() {
  case $1 in
    sample | sample-c) dir=${DOCSYGEN_ORACLES:-$tmp/oracle}/$1 ;;
    pdi) dir=/var/tmp/docsygen-oracle/pdi-9645c141-doxygen-$("$DOXYGEN" --version | cut -d ' ' -f 1) ;;
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
# With DOCSYGEN_READER=template, tests/reader-template is mounted first, so that docsygen reads
# the XML with the template reader even when Hugo has the native decoder (tests/reader-diff.sh).
site_config() {
  config=$1; shift
  if [ "${DOCSYGEN_READER:-}" = template ]; then set -- "$root/tests/reader-template/layouts=layouts" "$@"; fi
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
