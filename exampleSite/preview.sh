#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Serve the example site, or the documentation site, as docsygen renders them.
#
# Usage: sh exampleSite/preview.sh [--doc] [REV] [PORT]
#   --doc    the documentation site (doc/) instead of the example site (exampleSite/)
#   REV      a revision of this repository (commit, branch, tag), built from a worktree of it;
#            by default the checkout this script belongs to, as it is, uncommitted changes included
#   PORT     the port of hugo server, on 127.0.0.1 (default 1313); a lone argument of up to five
#            digits is a port, not a revision
#
# What can be downloaded again is cached in /tmp/docsygen-preview-cache and reused when present:
# the Docsy release the revision's go.mod requires (git clone), and the site's node_modules, per
# package-lock.json. The rest lives in /var/tmp/docsygen-preview/<commit>: a worktree of the
# revision (for the checkout itself, nothing).
# Hugo resolves the modules through module.replacements; go downloads the reader module.
# Remove a preview with: git worktree remove --force /var/tmp/docsygen-preview/<commit>
set -eu

layout=example
rev=
port=
for arg in "$@"; do
  case $arg in
    --doc) layout=doc ;;
    -*) echo "usage: preview.sh [--doc] [REV] [PORT]" >&2; exit 1 ;;
    *)
      if [ -z "$port" ] && [ -n "$rev" ]; then port=$arg
      elif [ -z "$rev" ] && [ -z "$port" ] && ! expr "$arg" : '[0-9]\{1,5\}$' > /dev/null; then rev=$arg
      elif [ -z "$port" ]; then port=$arg
      else echo "usage: preview.sh [--doc] [REV] [PORT]" >&2; exit 1
      fi ;;
  esac
done
port=${port:-1313}
repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
cache=/tmp/docsygen-preview-cache
mkdir -p "$cache" /var/tmp/docsygen-preview

if [ -n "$rev" ]; then
  commit=$(git -C "$repo" rev-parse --verify "$rev^{commit}")
  short=$(printf '%s' "$commit" | cut -c1-7)
  work=/var/tmp/docsygen-preview/$short
  # The worktree of the revision.
  git -C "$repo" worktree prune
  if [ ! -d "$work/.git" ] && [ ! -f "$work/.git" ]; then
    rm -rf "$work"
    git -C "$repo" worktree add --detach "$work" "$commit" >&2
  fi
else
  short=checkout
  work=$repo
fi
site=$work/exampleSite
if [ "$layout" = doc ]; then site=$work/doc; fi

# Docsy, at the version the example site requires.
docsy=$(sed -n 's|^[[:space:]]*github.com/docsy/docsy/theme \(v[^ ]*\).*|\1|p' "$site/go.mod" | head -n 1)
[ -n "$docsy" ] || { echo "preview.sh: no Docsy version in $site/go.mod" >&2; exit 1; }
if [ ! -d "$cache/docsy-$docsy/theme" ]; then
  rm -rf "$cache/docsy-$docsy.new"
  git clone --quiet --depth 1 --branch "$docsy" https://github.com/docsy/docsy "$cache/docsy-$docsy.new"
  mv "$cache/docsy-$docsy.new" "$cache/docsy-$docsy"
fi

# node_modules, installed once per package-lock.json (npm 11: the system npm may be older).
lock=$(sha256sum "$site/package-lock.json" | cut -c1-16)
if [ ! -d "$cache/node_modules-$lock" ]; then
  rm -rf "$site/node_modules" "$cache/node_modules-$lock.new"
  (cd "$site" && npx -y npm@11 install --no-audit --no-fund >&2)
  cp -a "$site/node_modules" "$cache/node_modules-$lock.new"
  mv "$cache/node_modules-$lock.new" "$cache/node_modules-$lock"
elif [ ! -x "$site/node_modules/.bin/hugo" ]; then
  rm -rf "$site/node_modules"
  cp -a "$cache/node_modules-$lock" "$site/node_modules"
fi

replacements="github.com/jbigot/docsygen -> $work,github.com/docsy/docsy/theme -> $cache/docsy-$docsy/theme"
# Hugo wants every module of the graph replaced once one is: the revision's reader module too,
# from Go's module cache, when it has one.
xmldoc=$(sed -n 's/^.*github.com\/jbigot\/hugo-xml-document \(v[0-9.]*\).*$/\1/p' "$site/go.mod" | head -n 1)
if [ -n "$xmldoc" ]; then
  xmldoc_dir=$(cd "$work" && go mod download -json "github.com/jbigot/hugo-xml-document@$xmldoc" | sed -n 's/^[[:space:]]*"Dir": "\(.*\)",$/\1/p')
  replacements="$replacements,github.com/jbigot/hugo-xml-document -> $xmldoc_dir"
fi
export HUGO_MODULE_REPLACEMENTS=$replacements
export PATH="$site/node_modules/.bin:$PATH"
echo "preview.sh: $short, the $layout site, at http://localhost:$port/" >&2
cd "$site"
exec hugo server --bind 127.0.0.1 --port "$port" --renderToMemory --disableFastRender
