<!--
SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
SPDX-License-Identifier: MIT
-->

# Contributing to docsygen

This file is for working on docsygen itself: its toolchain, its tests, how it is built, and what
to know about Doxygen, Hugo and Docsy to change it. How to use docsygen in a site is in
[README.md](README.md). Report bugs and propose changes on
[GitHub](https://github.com/jbigot/docsygen).

## Toolchain

| Tool | Version | Notes |
| --- | --- | --- |
| Hugo | ≥ 0.169.0 | the tests use Hugo with the native XML decoder (below) |
| Docsy | 0.18.0, pinned | module path `github.com/docsy/docsy/theme`; needs Dart Sass |
| Doxygen | 1.17 to 1.18 | the tests' oracle is 1.18.0 |
| npm | ≥ 11.18 | for the example site: older npm installs the wrong `sass` |

`go` and `git` are needed for Hugo's module commands, Python 3 for some tests.

- **Hugo**: docsygen reads the XML with Hugo's native decoder, `transform.Unmarshal` with
  `targetType: document` ([gohugoio/hugo#15485](https://github.com/gohugoio/hugo/issues/15485),
  not merged yet), when Hugo has it, and with the template reader of hugo-xml-document otherwise. The tests use the
  Hugo binary in `HUGO`; without it, they build Hugo with the native decoder, from the
  `docsygen-native` branch of the Hugo checkout in `HUGO_SRC` (default: `hugo/` next to this
  repository's main checkout), into `/tmp/docsygen-hugo-doc/<commit>/hugo`, in about 3 minutes.
  `tests/matrix.sh` checks the minimum released Hugo too.
- **Docsy** churns fast, with breaking changes in 0.16, 0.17 and 0.18: read its release post,
  `docsy.dev/blog/<year>/<version>/`, before bumping it. It moved in 0.18, to the repository
  `github.com/docsy/docsy` and the module `github.com/docsy/docsy/theme`, and Hugo modules don't
  follow GitHub's redirects.
- **Doxygen**: the tests download Doxygen 1.18.0 once into `/var/tmp/docsygen-matrix`, unless
  `DOXYGEN` names a binary. When a floor rises, everything that only served older versions goes.

## Repository layout

- The repository root is the module: `go.mod`, `hugo.yaml`, `layouts/` (partials under
  `layouts/_partials/docsygen/`), `assets/scss/`, `i18n/`.
- `exampleSite/` imports Docsy and docsygen as Hugo modules, docsygen through
  `replace github.com/jbigot/docsygen => ../` in its `go.mod`.
- `tests/`: the test suites, below.

## The example site

In `exampleSite/`, run `npx npm@11 install` once, then `npm run build`; Hugo and Dart Sass come
from npm. Run `hugo mod npm pack` again after a change to the module's npm dependencies.

It renders PDI's reference from its committed XML, in three versions (`main`, 1.12 latest, 1.7),
in two layouts:

- **the whole tree** of each version (`content/`), checked by `check-docsy.sh`;
- **PDI's layout** (`--config hugo.yaml,pdi-layout.yaml`: `content-pdi/`, `pdi-assets/`,
  `pdi-static/`, `layouts/redirect.html`), the draft of PDI's website, checked by
  `check-layout.sh`.

`sh exampleSite/preview.sh [--pdi|--plain] [REV] [PORT]` serves either, from the checkout or
from any revision, with Docsy and npm's packages cached. `exampleSite/generate-pdi-xml.sh`
regenerates PDI's XML, and `exampleSite/assets/doxygen/README.md` says how each version was made.

## Tests

`sh tests/all.sh` runs every suite, in about 2.5 minutes; run it on each change, and don't edit
the tree while it runs: later suites would test the edit. The PDI oracle needs `PDI_SRC`, a PDI
source tree, the first time. When a build fails, run it without `--quiet`, which hides
`errorf`'s message.

- `unit` (`tests/unit/`): unit cases of partials, and builds that must fail or warn.
- `site` (`tests/site/`): a test site without Docsy, on the sample oracles and PDI, checked by
  `check.py` (links, ids, foreign classes) and for its redirects.
- `info`, `info-docsy` (`tests/oracle/`): docsygen gives the same information as Doxygen's HTML,
  pairing Doxygen's pages with docsygen's (`tests/pairing/`). Information that the XML lacks is
  an entry of `xml-gaps.yaml`, never a guess; the rules are in `info-rules.yaml`.
- `check-docsy`, `check-layout`: the two layouts of the example site.
- `reference`: the test site against its build at the baseline commit in `tests/reference-base`;
  a change that changes the output moves the baseline.
- `reader-diff`: everything built with both readers must be identical.
- `tests/matrix.sh`, run separately: every supported Doxygen, and the minimum Hugo.

To probe an edge case, build a minimal site without Docsy: a `hugo.yaml` with
`module.replacements: "github.com/jbigot/docsygen -> <tree>"`, mounts for `content`, `layouts`
(an `all.html` that prints `{{ .Content }}`) and an oracle's XML at `assets/doxygen/sample`
(`DOXYGEN=… sh tests/oracle/generate.sh sample <dir>`).

## Architecture

- **XML reader**: templates read the XML through `partial "xmldoc/unmarshal.html"`, from the module
  [hugo-xml-document](https://github.com/jbigot/hugo-xml-document) (tests: its own repository), which
  returns the root element as `{tag, attributes, children}`. It uses Hugo's native decoder when
  Hugo has it, and the template reader, `xmldoc/parse.html`, otherwise. Both give the same
  tree, and what the reader accepts, the native decoder accepts with the same tree. Trees are
  cached in `hugo.Store`, per file and checked against its hash.
- **Model**: one model per XML directory, built once per build from `index.xml`, with an id→page
  map and a name→id map. Per-id results go in a per-model table (`docsygen/memo.html`), not in
  `partialCached`, an LRU of 1000 entries.
- **Paths**: the page scheme (`docsygen/paths/scheme.html`) gives each page a key, unique after
  Hugo's path normalization; placements (`docsygen/adapter.html`, one call per part of a version)
  put the keys at paths.
- **Rendering**: a page's plan lists its blocks in Doxygen's order. A skeleton
  (`docsygen/skeleton/<kind>.html`) turns it into Markdown, with real headings and one shortcode
  per block, so that search, print and `llms.txt` work. Generated pages are built from the
  public shortcodes, so that an embedded part renders as on its own page; each block renders
  through `docsygen/markup/block-<type>.html`.
- **Versions**: a registry built at render time from the version roots knows every version,
  since adapter files can't see each other.

Every generated page must work in Docsy's print output, search index and `llms.txt`. Style with
docsygen's own `docsygen-*` classes and Bootstrap's `--bs-*` variables, never Bootstrap's
internals, and never copy Docsy's templates: use its hooks, CSS, and ask upstream.

## Doxygen's XML

Doxygen's manual describes the XML output in
[Using the XML output](https://www.doxygen.nl/manual/customize.html#xmlgenerator); the reference is
its schemas, `index.xsd`, `compound.xsd` and `doxyfile.xsd`, from `templates/xml/` in
[doxygen/doxygen](https://github.com/doxygen/doxygen). Doxygen copies them into every XML output
directory: read the `compound.xsd` next to the input, which matches the version that wrote it.

What docsygen relies on beyond the schemas:

- `index.xml` is the entry point: enumerate it, never glob the directory.
- Take file names from refids, never derive them: their case follows `CASE_SENSE_NAMES`.
- Resolve cross-references (`<ref refid>`) through the id→page map, never by splitting ids: the
  compound that documents a member is not always the one its refid starts with.
- Descriptions are mixed content, with block elements inside `<para>`, which therefore can't map
  one to one to `<p>`.
- Doxygen versions add compound kinds and description elements: an unknown one warns once and
  renders generically, never crashes or disappears.
- `Doxyfile.xml` holds the effective configuration. Logo and icon are paths in the source tree:
  the XML output doesn't copy the files.

## Hugo and Docsy

Hugo's [content adapters](https://gohugo.io/content-management/content-adapters/) generate the
pages: adapter files run concurrently, in no fixed order, `.Store` is per file, and built-page
methods such as `.Site.Pages` fail inside them. Hugo denies `text/html` content by default, so
pages are Markdown with shortcodes and render hooks.

Pitfalls met so far:

- `transform.Unmarshal`'s default XML layout drops mixed content; the native decoder's
  `targetType: document` keeps it.
- `findRE` skips unmatched characters: check that the tokens cover the input.
- `merge` folds the case of keys and fails on maps of non-interface values: build maps with
  `newScratch` and `SetInMap`, and only `merge` new keys.
- `{{ with partial … }}` is Hugo's partial-decorator syntax, and panics on a plain partial:
  assign the result, then `with` it.
- `append` nests a slice whose element type differs: append elements one at a time.
- `where $pages "key" ""` matches nothing: compare in a `range`.
- `return` must end its pipeline: `return safeHTML (printf …)`.
- Two `AddPage` calls with one path keep the later page silently, even with
  `--printPathWarnings`.
- Shortcodes can't mix positional and named arguments.
- `html/template` drops HTML comments, in alias templates too.
- A resource's target path is relative to the site root; Hugo prefixes `baseURL`'s path.
- In a print output, `.RelPermalink` is the HTML page's: test the format through
  `.AlternativeOutputFormats.Get "html"`.
- YAML reads `1.10` as 1.1: quote version labels.
- A meta refresh drops the URL's fragment: redirects need a line of script.
- Hugo drops symlinked mounts.
- Docsy's `favicons.html` and its other `os.FileExists` checks look at the real `static/`, not at
  mounts; its blocks and `{{% alert %}}` need goldmark's `unsafe: true`.
- Building Hugo fills Go's build cache (33 GB once): `go clean -cache` afterwards.

## Licenses

A new file carries its license in a header, as the others do: `SPDX-FileCopyrightText` and
`SPDX-License-Identifier`, MIT unless the file comes from elsewhere, in which case it keeps its
own. Where a header can't go (binary and JSON files, Doxygen's generated files, inputs of a test
whose line numbers or exact bytes matter, such as `tests/sample/src/` and
`tests/xml-parse/edge/`), a `<file>.license` holds it. In Hugo templates the header is a `{{- /* …
*/ -}}` comment, in Markdown pages with front matter a `#` comment inside it. Check with `reuse
lint`.
