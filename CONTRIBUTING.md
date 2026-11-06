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
| Doxygen | 1.17 to 1.18 | the tests use both |
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
- **Doxygen**: the tests download Doxygen 1.17.0 and 1.18.0 once into `/var/tmp/docsygen-matrix`, unless
  `DOXYGEN` names a binary. When a floor rises, everything that only served older versions goes.

## Repository layout

- The repository root is the module: `go.mod`, `hugo.yaml`, `layouts/` (partials under
  `layouts/_partials/docsygen/`), `assets/scss/`, `i18n/`.
- `exampleSite/` imports Docsy and docsygen as Hugo modules, docsygen through
  `replace github.com/jbigot/docsygen => ../` in its `go.mod`.
- `doc/`: docsygen's documentation, a Docsy site published on GitHub Pages by
  `.github/workflows/pages.yml` (<https://jbigot.github.io/docsygen/>). It imports docsygen
  through `replace github.com/jbigot/docsygen => ../` and renders the `sample` corpus entry's
  committed XML (`doc/assets/doxygen/sample`, regenerated with `tests/corpus/generate.sh sample`
  and Doxygen 1.18) as its API reference. Run `npx npm@11 install` once, then `npm run build`.
- `tests/`: the test suites, below.

## The example site

`exampleSite/` is [docsy-example](https://github.com/docsy/docsy-example) at the tag of the pinned
Docsy (v0.18.0), plus what adding docsygen costs: the module imports in `hugo.yaml`, `@use
'docsygen'` in `assets/scss/_styles_project.scss`, the sample's XML in `assets/doxygen/sample`, one
adapter call, `content/en/docs/_content.gotmpl`, which puts its reference at `/docs/api/latest/`,
and a link to it from the docs landing page. Besides that, Hugo 0.169 in `package.json`, and Node 22
instead of 24 in `engines` (with `engine-strict` in `.npmrc`, npm refuses an older Node).
docsy-example's own tooling is left out: its tests, CI, link checking (`link-cache`, lychee),
formatting (`prettier`, cspell), update scripts (`npm-check-updates`, renovate), Netlify
configuration, `docsy.work`, README, CONTRIBUTING and LICENSE, and the `package.json` scripts and
dependencies that use them. Run `npx npm@11 install` once, then `npm run build`; Hugo and Dart Sass
come from npm. The files it keeps from docsy-example are Apache-2.0, its content CC-BY-4.0
(`REUSE.toml`).

`sh exampleSite/check.sh` builds it and checks what docsygen made (`tests/site/check_built.sh`
with `--under docs/api`); `sh exampleSite/preview.sh [--doc] [REV] [PORT]` serves it, or `doc/`,
from the checkout or from any revision, with Docsy and npm's packages cached.

`doc/` and `exampleSite/` each hold a copy of the `sample` corpus entry's XML, generated with
Doxygen 1.18.0: each site builds from its own directory. `sh tests/corpus/snapshot.sh` refreshes
both after a change to the sample, and the `snapshot` suite fails when they are stale.

The draft of PDI's website, which showed the reference in PDI's own layout, lives in
[pdi-docsygen](https://github.com/jbigot/pdi-docsygen).

## Tests

`sh tests/all.sh` runs every suite, in about 3 minutes; run it on each change, and don't edit
the tree while it runs: later suites would test the edit. When a build fails, run it without
`--quiet`, which hides `errorf`'s message.

- **The corpus** (`tests/corpus/`): `sample` and `sample-c` (a C++ and a C project meant to use
  every construct docsygen renders), `sample-next` (the sample one release later, without
  `io.hpp` and with `next/extra.hpp`, for versions), and `pdi`, PDI's real, large XML (also the
  performance check). `tests/corpus/generate.sh` runs Doxygen on an entry with a `Doxyfile`; the
  XML is generated per Doxygen version, into the cache `/var/tmp/docsygen-matrix/corpus`, never
  committed, and the entries that no run used for two weeks go. `pdi` is committed as it is,
  from Doxygen 1.18.0.
- `unit` (`tests/unit/`): unit cases of partials, and builds that must fail or warn.
- `site` (`tests/site/`): a test site without Docsy on each corpus entry, on `versions`
  (`sample` as 1.0 and `sample-next` as 2.0, the latest) and on `versions-mixed` (the same, with
  1.0 from Doxygen 1.17.0), checked by `check.py` (links, ids, roles, foreign classes) and for its
  redirects.
- `snapshot`: the copies of the sample's XML in `doc/` and `exampleSite/` are current
  (`tests/corpus/snapshot.sh --check`).
- `doc`, `example`: the documentation and example sites build, with `--printPathWarnings`, and
  the links, ids and roles of their reference are valid (`doc/check.sh`, `exampleSite/check.sh`,
  through `tests/site/check_built.sh`; a test-only hook, `tests/site/hooks`, publishes the
  `paths.json` of each version root).
- `docsy` (`tests/docsy/`): how the versions meet Docsy, on `doc/`'s configuration with four
  versions of the sample (one from another adapter file, placed elsewhere) and hand-written
  pages that link to them. Against expectations written from the design, not from the output:
  the version menus, canonical links and notices (`versions-expected.json`), the links of a
  hand-written page (`expected-links.json`), the sections and sidebar, the search index, the
  sitemap, the print pages and `llms.txt`, a baseURL with a path, that a second build is
  identical, and a development build's warnings.
- `reference`: what changed since the previous commit. It builds the test site of every corpus
  entry and Doxygen version (1.17, 1.18; the entries whose XML doesn't depend on it, with 1.18
  only) with the module of `REF` (default `HEAD`: the working tree against the last commit;
  `REF=main` for a branch) and with the working tree's, prints the number of identical, changed,
  added and removed files, and writes a `diff -r` per changed site into
  `/var/tmp/docsygen-reference`. A change doesn't fail it: `sh tests/reference-summary.sh` groups
  the changes by kind, so that an expected change is checked at a glance, and
  `sh tests/reference.sh --strict` fails on any change, for a refactor.
- `reader-diff`: everything built with both readers must be identical.
- `tests/matrix.sh`, run separately: for every supported Doxygen, the `site` suite with the Hugo
  fork and the minimum released Hugo, and the reader's comparison with expat
  ([hugo-xml-document](https://github.com/jbigot/hugo-xml-document)'s `tests/run.sh`, at the
  version `go.mod` requires) on the corpus, with both readers; and `unit`, `doc`, `example` and
  `docsy` with both Hugos.

The tests use internal partials of hugo-xml-document, which its README lists as stable for its
dependents' tests: `xmldoc/read.html` and `xmldoc/parse.html` to force the template reader, and
`xmldoc/native.html`. The tests set aside `HUGO_MODULE_REPLACEMENTS`: test sites import docsygen
through the `replace` of a `go.mod`. [pdi-docsygen](https://github.com/jbigot/pdi-docsygen) keeps
copies of `tests/site/check.py` and `htmltree.py`: update them there too.

To probe an edge case, build a minimal site without Docsy: a `hugo.yaml` with
`module.replacements: "github.com/jbigot/docsygen -> <tree>"`, mounts for `content`, `layouts`
(an `all.html` that prints `{{ .Content }}`) and a corpus entry's XML at `assets/doxygen/sample`
(`DOXYGEN=… sh tests/corpus/generate.sh sample <dir>`).

## Architecture

- **XML reader**: templates read the XML through `partial "xmldoc/unmarshal.html"`, from the module
  [hugo-xml-document](https://github.com/jbigot/hugo-xml-document) (tests: its own repository), which
  returns the root element as `{tag, attributes, children}`. It uses Hugo's native decoder when
  Hugo has it, and the template reader, `xmldoc/parse.html`, otherwise. Both give the same
  tree, and what the reader accepts, the native decoder accepts with the same tree. Trees are
  cached in `hugo.Store`, per file and checked against its hash.
- **Model**: one model per XML directory, built once per build from `index.xml`, with an id→page
  map and a name→id map. `partialCached` is an LRU of 1000 entries: it holds O(versions) entries,
  and what is computed per compound (sections, inherited members) is one map per model in one
  entry (`plan/sections/all.html`, `plan/inherited/all.html`, `plan/overloads/build.html`). Only the plans, one per page and
  expensive, go in a per-model table (`docsygen/memo.html`), scoped by the dir and pathMap.
- **Paths**: the page scheme (`docsygen/paths/scheme.html`) gives each page a key, unique after
  Hugo's path normalization; placements (`docsygen/adapter.html`, one call per part of a version)
  put the keys at paths.
- **Rendering**: a page's plan lists its blocks (its declarations are one `list` block,
  `plan/list.html`) in Doxygen's order. A skeleton
  (`docsygen/skeleton/<kind>.html`) turns it into Markdown, with real headings and one shortcode
  per block, so that search, print and `llms.txt` work. Generated pages are built from the
  public shortcodes, called as `{{% %}}` (goldmark reads their output, so it needs `unsafe: true`,
  which `docsygen/shortcode/unsafe.html` checks), so that an embedded part renders as on its own
  page; each block renders through `docsygen/markup/block-<type>.html`, and a shortcode returns it
  through `docsygen/markup/md-safe.html`, since a blank line would end goldmark's HTML block.
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
- A meta refresh drops the URL's fragment, and Hugo's alias page has no script to keep it:
  an alias lands at the top of its target.
- Hugo drops symlinked mounts.
- Docsy's `favicons.html` and its other `os.FileExists` checks look at the real `static/`, not at
  mounts; its blocks and `{{% alert %}}` need goldmark's `unsafe: true`.
- Building Hugo fills Go's build cache (33 GB once): `go clean -cache` afterwards.

## Licenses

A new file carries its license in a header, as the others do: `SPDX-FileCopyrightText` and
`SPDX-License-Identifier`, MIT unless the file comes from elsewhere, in which case it keeps its
own. Where a header can't go (binary and JSON files, Doxygen's generated files, inputs of a test
whose line numbers or exact bytes matter, such as `tests/corpus/sample/src/`),
a `<file>.license` holds it. The files copied from docsy-example, `exampleSite/`'s, are annotated
in `REUSE.toml`. In Hugo templates the header is a `{{- /* …
*/ -}}` comment, in Markdown pages with front matter a `#` comment inside it. Check with `reuse
lint` (on a copy of the tree without `node_modules/`).
