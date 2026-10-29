# docsygen

docsygen is a [Hugo](https://gohugo.io/) module that turns the XML output of
[Doxygen](https://www.doxygen.nl/) into native pages of a [Docsy](https://www.docsy.dev/) site:
the C and C++ API reference (classes, namespaces, files, groups, pages, examples, indexes), with
links between them and from your hand-written pages.

It reads the XML directly, from a content adapter: no tool runs between `doxygen` and `hugo`.

## Requirements

- Hugo extended 0.160.1 or later (Docsy 0.18's floor; the module itself needs 0.153.0).
- Docsy 0.18 (module `github.com/docsy/docsy/theme`), with its usual requirements: the `sass`
  CLI on `PATH`, and Bootstrap and Font Awesome from npm.
- Doxygen's XML output, `GENERATE_XML = YES`, from Doxygen 1.15 to 1.18 (`tests/matrix.sh`
  tests each one).

## Set up a site

Import the module next to Docsy, and **before** it, in `hugo.yaml`: docsygen replaces some of
Docsy's partials (the version menu and banner, its `head-end` hook), which only works when it
comes first. The build stops otherwise.

```yaml
module:
  imports:
    - path: github.com/jbigot/docsygen
    - path: github.com/docsy/docsy/theme
```

Import its styles from your `assets/scss/_styles_project.scss`:

```scss
@import 'docsygen';
```

Copy Doxygen's XML directory under `assets/`, for example `assets/doxygen/mylib/`. A mount works
too, from a directory outside the site (`module.mounts`, with an absolute `source`), but not
through a symbolic link: Hugo 0.166 drops symlinked mounts.

Generate the pages from a content adapter in the **parent** directory of the reference, for
example `content/docs/_content.gotmpl`:

```go-html-template
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/mylib-main" "version" "main" "path" "main") -}}
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/mylib-2.1" "version" "2.1" "path" "2.1" "latest" true) -}}
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/mylib-2.0" "version" "2.0" "path" "2.0") -}}
```

| Option | Required | Meaning |
| --- | --- | --- |
| `store` | yes | the adapter's context, `.` |
| `dir` | yes | the XML directory, under `assets/` |
| `version` | yes | the version's label, as `doxygen:` links name it |
| `path` | yes | where the reference goes, relative to the adapter's directory |
| `latest` | no | whether this is the latest release (default `false`; one version at most, which links without a version need): see [Versions](#versions). The label `latest`, and a `path` named `latest`, are reserved for it |
| `search` | no | whether its pages are in Docsy's search index (default: `latest`) |
| `pathMap` | no | rewrites of file locations for the file tree, `[{from, to}]` (default `[]`) |

Call the adapter once per version, each with its own `dir` and `path`. A reference's root is
its own sidebar root (`sidebar_root_for: self`), so set `params.ui.sidebar_root_enabled: true`.
Keep the reference below a top-level section (`content/docs/main/`, not `content/main/`), or Docsy
warns about `sidebar_root_for`.

`pathMap` matches each location after the common leading directories are stripped, and
rewrites it with the first `from` that starts it: `[{from: "build/gen/", to: ""}]` moves generated
headers next to the sources. A directory left without files joins its parent's page.

The reference holds `pages/`, `topics/`, `api/`, `files/`, `examples/` and `indexes/` sections,
each only when Doxygen has something for it.

## Versions

Each adapter call adds one version of the reference. They share the content adapter, and so the
parent directory: `/docs/main/`, `/docs/2.0/`, and so on. Each version's root is titled with the
project's name (Doxygen's `PROJECT_NAME`) and its label, and its sidebar entry and breadcrumb show
the label, as the version menu does; the parent's section list and sidebar list the versions in
the menu's order.

- **The latest release lives at `latest/`.** The call marked `latest` generates its pages at
  `latest/`, next to its `path` (`/docs/latest/`), and each one gets an alias at its numbered
  path (`/docs/2.1/…`), a page that redirects there and keeps the URL's `#fragment`. When 2.2
  comes out, mark it `latest` instead: `/docs/2.1/` becomes an ordinary version, and its links
  keep working.
- **Canonical links:** a page of `latest/` is its own canonical page. A page of any other version
  points its canonical link at the same page in `latest/`, or at itself when the latest release
  has no such page. The redirects point at their target. Only `latest/` is in the sitemap.
- **Order:** the versions whose label is not a release number (`main`) come first, in the order
  of the calls, then the latest release, then the older releases, newest first (`2.10` before
  `2.9`).
- **Version menu:** on a generated page, Docsy's navbar menu lists the versions, `latest (2.1)`
  for the latest one, and each entry leads to the same page in that version, or to its root when
  it has none. Hand-written pages show no menu. docsygen sets a placeholder `params.versions`
  for Docsy to call its menu, and doesn't read the site's own.
- **Notice:** the pages of `main` and of older releases say so above their content, with a link
  to the same page in the latest release. It replaces Docsy's version banner
  (`params.archived_version` is not used). Reword or translate it in your `i18n/<lang>.yaml`,
  with the keys `docsygen-notice-older` and `docsygen-notice-main` of docsygen's `i18n/en.yaml`.
  The project's name comes from Doxygen's `PROJECT_NAME`.
- **Search:** only the latest release's pages are in the search index, unless a call sets
  `search`.
- **Canonical links go through Docsy's `hooks/head-end.html`.** If your site has its own
  `layouts/_partials/hooks/head-end.html`, it shadows docsygen's: call docsygen from it:

  ```go-html-template
  {{- partial "docsygen/canonical-link.html" . -}}
  ```

- Docsy's `shared` chrome mode (`params.td.chrome`) copies one navbar into every page, which
  drops the version menu: docsygen warns when it is on, and needs the default, `full`.

### Development mode

Building every version takes time. To build only some of them while you edit, list their labels
in `params.docsygen.versions`, `latest` allowed, in the configuration of `hugo server`'s
environment, `config/development/hugo.yaml`:

```yaml
params:
  docsygen:
    versions: [main, latest]
```

`hugo`, whose environment is `production`, still builds every version. The versions left out
are missing from the version menu, and a `doxygen:` link to one of them renders as its text,
with a warning. The latest version must be built. A label that no adapter call has stops the
build: quote version numbers, since YAML reads an unquoted `1.10` as the number 1.1.

## Link to the reference

From any Markdown page, link with a `doxygen:` destination:

```markdown
[the widget](doxygen:demo::Widget)
[](doxygen:demo::Widget)          <!-- empty text: `demo::Widget` as code, a page's title -->
[a section](doxygen:guide#first-section)
[an older version](doxygen:2.0/demo::Widget)
[the latest release, always](doxygen:latest/demo::Widget)
[a directory](doxygen:dir:src)
[one overload](<doxygen:demo::Widget::resize(int, int) const>)
```

The destination is `[VERSION/][KIND:]NAME[(SIGNATURE)][#FRAGMENT]`:

- `VERSION`, a version's label, or `latest`; without it, the latest release. Naming the latest
  release by its number (`doxygen:2.1/…`) links to its redirect, `/docs/2.1/…`, so that the link
  stays on 2.1 after the next release;
- `KIND`, a compound kind (`class`, `file`, `dir`, `page`, …), a member kind, or `member`; without
  it, symbols win, then pages, groups, files and directories;
- `NAME`, as Doxygen writes it: `PDI::Datatype`, `PDI_share`, a `\page` name;
- `SIGNATURE`, the parameter types of an overload, and `const`; a destination with spaces needs
  Markdown's angle brackets, `[x](<doxygen:… const>)`;
- `FRAGMENT`, an anchor of the target page.

A destination that resolves to nothing stops the build.

The links go through docsygen's `layouts/_markup/render-link.html`, which renders other links as
Hugo's embedded link hook does: a destination that names a page or a resource links to it. If
your site has its own `render-link.html`, it shadows docsygen's: send
`doxygen:` destinations to docsygen from it:

```go-html-template
{{- if hasPrefix .Destination "doxygen:" -}}
  {{- partial "docsygen/link.html" . -}}
{{- else -}}
  …your rendering…
{{- end -}}
```

On a multilingual site with a single host, Hugo's embedded link hook takes over (with the default
`markup.goldmark.renderHooks.link.useEmbedded: auto`): set it to `fallback` to keep docsygen's.

## Doxygen options that matter

- `XML_PROGRAMLISTING`: `YES` gives each file its source listing, which roughly doubles the XML
  and the build time; `NO` is faster, with no source listings.
- `SHOW_FILES`: `NO` leaves out the file pages, as Doxygen's HTML does (directories keep theirs).
- `EXTRACT_PRIVATE`, `EXTRACT_STATIC`, `INLINE_SIMPLE_STRUCTS`, `SORT_MEMBER_DOCS`, `IGNORE_PREFIX`
  and the other options that decide what Doxygen's HTML shows are read from `Doxyfile.xml`.

## Customize the rendering

Each rendered block goes through a partial named `docsygen/markup/block-<type>.html`, and
descriptions through `docsygen/markup/doc.html` and `docsygen/markup/doc-node.html`. A site
overrides one by putting a file of the same name in its own `layouts/_partials/docsygen/markup/`.
The page tree comes from `docsygen/paths/scheme.html`, the Markdown of each page from
`docsygen/skeleton.html`. The markup only uses `docsygen-*` classes, which `_docsygen.scss`
styles with Bootstrap's `--bs-*` variables.

## The example site

`exampleSite/` renders [PDI](https://pdi.dev)'s reference from its committed XML, in three
versions: `main`, the latest release, 1.12, and an older one, 1.7 (`exampleSite/assets/doxygen/README.md`
says how each was made). From that directory, `npx npm@11 install` then `npm run serve`, which
builds `main` and `latest` only (`config/development/hugo.yaml`). `exampleSite/check-docsy.sh`
builds it and checks its output.
