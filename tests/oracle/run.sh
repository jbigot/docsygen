#!/bin/sh
# Build a site from each oracle's XML and check with info.py that it shows all the information of
# that oracle's Doxygen HTML.
#
# Usage: sh tests/oracle/run.sh info|info-docsy [--gap-usage] [NAME ...]
#   info   builds tests/site and the pairing site tests/pairing, and compares the first with
#          info.py through the paths.json of both (/ref/paths.json), with the gaps of
#          xml-gaps.yaml and the rules of info-rules.yaml
#   info-docsy  the same with a copy of exampleSite, the Docsy site, pointed at the oracle's xml/
#          (its Docsy content is main .td-content, its paths.json /docs/main/paths.json); pdi only,
#          as the example site renders PDI
#   --gap-usage  info.py also prints whether each gap is needed
#   NAME   sample, sample-c or pdi (default: all three); pdi needs PDI_SRC the first time
#          (tests/lib.sh, oracle)
# The site directory holds layouts/, content/ and config.yaml (its configuration, without the
# module section); the oracle's xml/ is mounted at assets/doxygen/oracle. The counts of the gaps
# and rules are checked only on Doxygen 1.15.0's XML (--counts-advisory otherwise). Exit 1 on any
# difference, when an oracle cannot be generated, or when the site does not exist yet.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../lib.sh"
mode=${1:?usage: run.sh info|info-docsy [--gap-usage] [NAME ...]}
shift
usage=
if [ "${1:-}" = --gap-usage ]; then usage=--gap-usage; shift; fi
[ $# -gt 0 ] || set -- sample sample-c pdi
case $mode in
  info) site=$root/tests/site; root_url=ref ;;
  info-docsy) site=$root/exampleSite; root_url=docs/main; set -- pdi ;;
  *) echo "run.sh: unknown mode $mode (info or info-docsy)" >&2; exit 2 ;;
esac
pairing=$root/tests/pairing

status=0
for name; do
  printf '== %s\n' "$name"
  if ! dir=$(oracle "$name"); then status=1; continue; fi
  # The counts of xml-gaps.yaml and info-rules.yaml are those of Doxygen 1.15.0's HTML.
  advisory=
  version=$(sed -n 's/.*<doxygenindex [^>]*version="\([^"]*\)".*/\1/p' "$dir/xml/index.xml")
  if [ "$version" != 1.15.0 ]; then advisory=--counts-advisory; fi
  work=$tmp/$name
  mkdir -p "$work"
  if [ "$mode" = info-docsy ]; then
    # exampleSite as it is, but for the oracle's XML in place of its committed one, and a hook
    # that publishes paths.json.
    {
      printf 'module:\n  mounts:\n'
      printf '    - {source: "%s", target: "assets/doxygen/pdi"}\n' "$dir/xml"
      printf '    - {source: assets, target: assets, files: ["! doxygen/pdi/**"]}\n'
      for d in content static layouts data i18n archetypes; do printf '    - {source: "%s", target: "%s"}\n' "$d" "$d"; done
      printf '    - {source: "%s", target: "layouts"}\n' "$root/tests/site/hooks"
    } > "$work/checks.yaml"
    if ! PATH="$site/node_modules/.bin:$PATH" "$hugo" --source "$site" --config "$site/hugo.yaml,$work/checks.yaml" \
        --destination "$work/public" > "$work/log" 2>&1; then
      cat "$work/log" >&2; status=1; continue
    fi
  else
    site_config "$work/hugo.yaml" "$site/layouts=layouts" "$site/content=content" "$dir/xml=assets/doxygen/oracle"
    if [ -f "$site/config.yaml" ]; then cat "$site/config.yaml" >> "$work/hugo.yaml"; fi
    # Not --quiet: it would hide the ERROR line that errorf logs.
    if ! "$hugo" --source "$work" --destination "$work/public" > "$work/log" 2>&1; then
      cat "$work/log" >&2; status=1; continue
    fi
  fi
  # info.py pairs pages through the roles of the pairing site's pages.
  pair=$work/pairing
  mkdir -p "$pair"
  site_config "$pair/hugo.yaml" "$pairing/layouts=layouts" "$pairing/content=content" "$dir/xml=assets/doxygen/oracle"
  cat "$pairing/config.yaml" >> "$pair/hugo.yaml"
  if ! "$hugo" --source "$pair" --destination "$pair/public" > "$pair/log" 2>&1; then
    cat "$pair/log" >&2; status=1; continue
  fi
  # shellcheck disable=SC2086 # advisory and usage are one word or none
  python3 -I "$here/info.py" --doxygen "$dir/html" --compat "$pair/public/ref/paths.json" --site "$work/public" \
    --paths "$work/public/$root_url/paths.json" --gaps "$here/xml-gaps.yaml" --rules "$here/info-rules.yaml" \
    --oracle "$name" $advisory $usage || status=1
done
exit $status
