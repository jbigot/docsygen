#!/bin/sh
# Serve the example site with PDI's reference, as docsygen renders it.
#
# Usage: sh exampleSite/preview.sh [--pdi|--plain] [REV] [PORT]
#   --pdi    the example site in PDI's organization (pdi-layout.yaml, content-pdi/): the default
#   --plain  the whole tree of PDI's reference, at /docs/main/
#   REV      a revision of this repository (commit, branch, tag), built from a worktree of it;
#            by default the checkout this script belongs to, as it is, uncommitted changes included
#   PORT     the port of hugo server, on 127.0.0.1 (default 1313); a lone argument of up to five
#            digits is a port, not a revision
#
# What can be downloaded again is cached in /tmp/docsygen-preview-cache and reused when present:
# the Docsy release the revision's exampleSite/go.mod requires (git clone), and the example site's
# node_modules, per package-lock.json. The rest lives in /var/tmp/docsygen-preview/<commit>: a
# worktree of the revision, with, when it has none, a content adapter (content/docs/_content.gotmpl,
# untracked) that renders exampleSite/assets/doxygen/pdi at /docs/main/, and the preview
# configuration (next to the worktree, or in /var/tmp/docsygen-preview/current for the checkout).
# Hugo resolves the modules through module.replacements, so no go is needed.
# Remove a preview with: git worktree remove --force /var/tmp/docsygen-preview/<commit>
set -eu

layout=pdi
rev=
port=
for arg in "$@"; do
  case $arg in
    --pdi) layout=pdi ;;
    --plain) layout=plain ;;
    -*) echo "usage: preview.sh [--pdi|--plain] [REV] [PORT]" >&2; exit 1 ;;
    *)
      if [ -z "$port" ] && [ -n "$rev" ]; then port=$arg
      elif [ -z "$rev" ] && [ -z "$port" ] && ! expr "$arg" : '[0-9]\{1,5\}$' > /dev/null; then rev=$arg
      elif [ -z "$port" ]; then port=$arg
      else echo "usage: preview.sh [--pdi|--plain] [REV] [PORT]" >&2; exit 1
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
  cfg=$work
  # The worktree of the revision.
  git -C "$repo" worktree prune
  if [ ! -d "$work/.git" ] && [ ! -f "$work/.git" ]; then
    rm -rf "$work"
    git -C "$repo" worktree add --detach "$work" "$commit" >&2
  fi
else
  short=checkout
  work=$repo
  cfg=/var/tmp/docsygen-preview/current
  mkdir -p "$cfg"
fi
site=$work/exampleSite

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

# The plain layout: the reference of PDI under /docs/main/. Both: Docsy's sidebar root for it.
if [ "$layout" = pdi ]; then
  [ -f "$site/pdi-layout.yaml" ] || { echo "preview.sh: $short has no exampleSite/pdi-layout.yaml, use --plain" >&2; exit 1; }
  configs=hugo.yaml,pdi-layout.yaml,$cfg/preview.yaml
  start=/
else
  configs=hugo.yaml,$cfg/preview.yaml
  start=/docs/main/
fi
if [ "$layout" = plain ] && [ ! -f "$site/content/docs/_content.gotmpl" ]; then
  printf '%s\n' '{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/pdi" "version" "main" "path" ":version") -}}' \
    > "$site/content/docs/_content.gotmpl"
fi
printf 'params:\n  ui:\n    sidebar_menu_compact: true\n    sidebar_root_enabled: true\n' > "$cfg/preview.yaml"

cd "$site"
export HUGO_MODULE_REPLACEMENTS="github.com/jbigot/docsygen -> $work,github.com/docsy/docsy/theme -> $cache/docsy-$docsy/theme"
export PATH="$site/node_modules/.bin:$PATH"
echo "preview.sh: $short, $layout layout, at http://localhost:$port$start" >&2
exec hugo server --config "$configs" --bind 127.0.0.1 --port "$port" --renderToMemory --disableFastRender
