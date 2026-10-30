# docsygen

docsygen is a [Hugo](https://gohugo.io/) module that turns the XML output of
[Doxygen](https://www.doxygen.nl/) into native pages of a [Docsy](https://www.docsy.dev/) site:
the C and C++ API reference (classes, namespaces, files, groups, pages, examples, indexes), with
links between them and from your hand-written pages.

It reads the XML directly, from a content adapter: no tool runs between `doxygen` and `hugo`.

## Requirements

- Hugo 0.169.0 or later. docsygen reads the XML with Hugo's own decoder when Hugo has its
  document layout (gohugoio/hugo#15485, not released yet), and with its own reader otherwise,
  with the same result.
- Docsy 0.18 (module `github.com/docsy/docsy/theme`), with its usual requirements: the `sass`
  CLI on `PATH`, and Bootstrap and Font Awesome from npm.
- Doxygen's XML output, `GENERATE_XML = YES`, from Doxygen 1.17 to 1.18 (`tests/matrix.sh`
  tests each one).

## Set up a site

Import the module next to Docsy, and **before** it, in `hugo.yaml`: docsygen replaces some of
Docsy's partials (the version menu and banner, the `head-end` hook and the print heading of
docs pages), which only works when it comes first. The build stops otherwise.

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
through a symbolic link: Hugo drops symlinked mounts.

Generate the pages from a content adapter, for example `content/docs/_content.gotmpl`:

```go-html-template
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/mylib-main" "version" "main" "path" ":version") -}}
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/mylib-2.1" "version" "2.1" "path" ":version" "latest" true) -}}
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/mylib-2.0" "version" "2.0" "path" ":version") -}}
```

| Option | Required | Meaning |
| --- | --- | --- |
| `store` | yes | the adapter's context, `.` |
| `dir` | yes | the XML directory, under `assets/` |
| `version` | yes | the version's label, as `doxygen:` links name it |
| `path` | yes | where the reference goes, relative to the adapter's directory: a pattern with one `:version` segment, which the label fills (`:version`, `docs/:version/api`) |
| `select` | no | what to place (default: the whole tree): see [Place parts of the reference](#place-parts-of-the-reference) |
| `children` | no | whether the pages below the selected one come too (default `true`) |
| `title`, `linkTitle`, `weight` | no | the placed root's title, menu title and weight (default: see [Place parts of the reference](#place-parts-of-the-reference)) |
| `duplicate` | no | `true`, or the page keys and names whose pages are duplicates: see [Hand a page over](#hand-a-page-over) |
| `latest` | no | whether this is the latest release (default `false`; one version at most, which links without a version need): see [Versions](#versions). The label `latest`, and a segment `latest` in `path`, are reserved for it |
| `search` | no | whether its pages are in Docsy's search index (default: `latest`) |
| `pathMap` | no | rewrites of file locations for the file tree, `[{from, to}]` (default `[]`) |

Call the adapter once per version, each with its own `dir`: the calls of one version, which may
place several parts of it, name the same `dir` and `pathMap`, or the build stops. The page at the `:version` segment
is its version's own sidebar root (`sidebar_root_for: self`), so set
`params.ui.sidebar_root_enabled: true`.
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

- **The latest release lives at `latest/`.** The call marked `latest` generates its pages with
  `latest` for `:version` (`/docs/latest/`), and each one gets an alias at its numbered path
  (`/docs/2.1/…`), a page that redirects there and keeps the URL's `#fragment`. When 2.2
  comes out, mark it `latest` instead: `/docs/2.1/` becomes an ordinary version, and its links
  keep working.
- **Canonical links:** a page of `latest/` is its own canonical page. A page of any other version
  points its canonical link at the same page in `latest/`, or at itself when the latest release
  has no such page. The redirects point at their target. Only `latest/` is in the sitemap.
- **Order:** the versions whose label is not a release number (`main`) come first, by the
  smallest `weight` of their calls, then by name, with the releases newer than the latest one (a
  release documented ahead of it); then the latest release; then the older releases, newest
  first (`2.10` before `2.9`). A version's calls may sit in several adapter files: the order
  doesn't depend on which one runs first.
- **Version menu:** on a generated page, Docsy's navbar menu lists the versions, `latest (2.1)`
  for the latest one, and each entry leads to the same page in that version, wherever it is
  placed. When that version has no such page, the entry leads to the nearest page there: the same
  path with that version, without its last segments, until a page exists (`/guide/1.7/new/` is
  missing, so `/guide/1.7/`). A page that [claims an item](#hand-a-page-over) is a page of its
  version: it has the menu, the notice and the canonical link of the item's page. Hand-written pages show no menu. docsygen sets a placeholder `params.versions`
  for Docsy to call its menu, doesn't read the site's own, and its stylesheet hides the navbar
  item that Docsy leaves empty on hand-written pages.
- **Notice:** the pages of `main`, of releases newer than the latest, and of older releases say
  so above their content, with a link
  to the same page in the latest release. It replaces Docsy's version banner
  (`params.archived_version` is not used), and heads the print page of a section too. Reword or
  translate it in your `i18n/<lang>.yaml`, with the keys `docsygen-notice-older` and
  `docsygen-notice-main` of docsygen's `i18n/en.yaml`. The project's name comes from Doxygen's
  `PROJECT_NAME`.
- **Search:** only the latest release's pages are in the search index, unless a call sets
  `search`.
- **Canonical links go through Docsy's `hooks/head-end.html`.** If your site has its own
  `layouts/_partials/hooks/head-end.html`, it shadows docsygen's: call docsygen from it:

  ```go-html-template
  {{- partial "docsygen/canonical-link.html" . -}}
  ```

  Likewise, a site's own `layouts/_partials/print/page-heading-docs.html` calls
  `{{ partial "version-banner.html" .Page }}` for the notice of print pages.
- Docsy's `shared` chrome mode (`td.chrome`) copies one navbar into every page, which drops the
  version menu: docsygen warns when a page of the reference is in it, and needs the default,
  `full`.

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

Links go to the page that holds their target in that version, whichever placement it is in
([Place parts of the reference](#place-parts-of-the-reference)). A target that no page of the
version holds, because no placement selects it, renders as its text without a link, with a
warning (`docsygen-unplaced`, which `ignoreLogs` can silence) naming the linking page: links
from `doxygen:` destinations and links in the generated pages alike, the entries of lists and
indexes included.

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

## Place parts of the reference

By default a call places a version's whole tree. With `select`, it places one part of it, so that
a site can arrange the reference as it likes, with one call per part and version:

```go-html-template
{{- /* content/_content.gotmpl */ -}}
{{- range slice (dict "dir" "doxygen/mylib-main" "version" "main") (dict "dir" "doxygen/mylib-2.1" "version" "2.1" "latest" true) -}}
  {{- partial "docsygen/adapter.html" (merge . (dict "store" $ "path" "guide/:version" "select" "pages" "title" "Guide")) -}}
  {{- partial "docsygen/adapter.html" (merge . (dict "store" $ "path" "api/:version" "select" "api" "duplicate" (slice "mylib::Widget"))) -}}
  {{- partial "docsygen/adapter.html" (merge . (dict "store" $ "path" "widget/:version" "select" "mylib::Widget" "children" false)) -}}
{{- end -}}
```

- `select` is a page key of the default tree, as the `pages`, `topics`, `api/mylib`,
  `pages/install` sections and pages of the whole tree name them, or the name of a compound as a
  `doxygen:` link writes it (`mylib::Widget`, `page:install`, `group:io`). The placement holds
  that page and every page below it, or the page alone with `children: false`. A member has no
  page: `select` stops the build, and [embedding](#embed-the-reference) shows a member anywhere.
- `path` is a pattern with one `:version` segment, anywhere: `:version`, `guide/:version`,
  `docs/:version/api`. The placed pages keep their place below the selected one.
- `mylib::Widget` is in the `api` subtree too: each item has one page per version, so the `api`
  call marks it as a duplicate ([Hand a page over](#hand-a-page-over)).
- The placement root keeps the selected page's title ("Pages", `mylib::Widget`) unless `title`
  or `linkTitle` are given; `title` is its menu title too. A root at the `:version` segment
  (`guide/:version`) is its version's section: its menu title stays the version (`latest (2.1)`
  for the latest) unless `linkTitle` is given, and its weight orders it as the version menu. The
  whole tree's root is titled with the project's name and the label, and its content starts with
  the main page's title unless `title` is given. `select: ""` with `children: false` places the
  main page alone.
- The pages between the `:version` segment and a deeper root (`docs/2.1/` for
  `docs/:version/api`) are sections that docsygen adds, titled with their segment, the
  `:version` one with the project's name and the version, as a whole tree's root. They are
  pages of their version, with its menu, notice and canonical link. The segments above
  `:version` are your site's own sections (an `_index.md`), or Hugo's top-level ones.
- Two placements of one adapter file that generate the same page stop the build, naming both.
  Calls in different adapter files can't see each other: when one adapter file is in a
  directory below another's (`content/` and `content/guide/`), they must not generate the same
  paths.

## Hand a page over

A hand-written page can be the page of an item in one version, in place of the generated one:
links to the item, and to its members, then go to it. It claims the item in its front matter:

```yaml
---
title: Array datatype
params:
  docsygen:
    version: "1.12"
    claims: ["PDI::Array_datatype"]
---
```

Each claim is a page key or a name, as `select` takes them. Write the page with the
[shortcodes](#embed-the-reference), which take its version: a full member carries its anchor,
so that links to the member land on it, `docsygen/members` shows them all, and an `{#details}`
heading takes the links to the class's detailed description. A page can claim several items
only when their anchors differ: two classes both have `details`, so each needs its own page,
and the build stops otherwise.

Every item has at most one canonical page per version: two placements that generate one page, or
a placement and a hand-written page, stop the build, naming both. Mark the generated one as a
duplicate with the call's `duplicate` option: `true` for all its pages, or a list of page keys
and names for those pages and the pages below them:

```go-html-template
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/pdi-1.12" "version" "1.12" "latest" true
    "path" "plugin-api/:version" "select" "api" "duplicate" (slice "PDI::Array_datatype")) -}}
```

A duplicate is still a page of the site, but no link goes to it, it is out of the search index
and the sitemap, and its canonical link is that of the page that holds its item. A duplicate
takes the pages below it along: the nested classes of a class marked as a duplicate need a
claim too, or links to them render as text. The example
site's PDI layout does this with `content-pdi/guide/latest/array-datatype.md`.

## Embed the reference

Any page can show a part of a version's reference with two shortcodes. The generated pages are
built from the same ones, so an embedded part looks as it does on its own page.

```markdown
{{< docsygen/member item="demo::Widget::width" >}}
{{< docsygen/member item="demo::Widget::resize(int)" form="summary" >}}
{{< docsygen/members item="demo::Widget" >}}
{{< docsygen/part item="demo::Widget" part="description" >}}
{{< docsygen/part item="demo::Widget" part="decls" section="public-func" >}}
{{< docsygen/part part="tree" name="annotated" >}}
```

- `item` names what to show, as a `doxygen:` link does (`[KIND:]NAME[(SIGNATURE)]`, without the
  version). `id` names it by its Doxygen id instead. A list or an index takes neither.
- `docsygen/member` shows a member: `form="full"` (the default), its documentation as its
  compound's page shows it, or `form="summary"`, its row of the summary table.
- `docsygen/members` shows every member that a compound's page documents, in its order, each in
  full as `docsygen/member` shows it: a hand-written page for a class lists them all, and keeps
  up with the members later versions add.
- `docsygen/part` shows one part of a page, `part` being its type: `brief`, `includes`,
  `diagram`, `concept-definition`, `decls` (a summary table, with `section` its key, such as
  `public-func`, `func` or `typedef`), `description` (the detailed description, its sections
  included when embedded elsewhere), `section`, `inline-classes`, `member`, `all-members`,
  `tree` and `index` (with `name`, and for an index `filter` and `letter`), `source`,
  `generated-from`.
- `version` picks the version. Without it, a part comes from the page's own version: that of the
  version root above the page, or the page's `params.docsygen.version`, else `latest`.
- Links in an embedded part go to the version's own pages.
- The full form of a member carries the member's anchor, so that links to the member can land on
  the page, unless the page already has it: from the member's heading, or from an earlier full
  form of the same member. Shortcodes can't mix positional and named arguments in Hugo, hence
  `item=`.
- A part that the version lacks stops the build. A version that development mode leaves out
  embeds nothing, with a warning.

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
The page tree comes from `docsygen/paths/scheme.html`. The markup only uses `docsygen-*`
classes, which `_docsygen.scss` styles with Bootstrap's `--bs-*` variables.

The Markdown of a page comes from `docsygen/skeleton/<kind>.html`, which a site overrides to
redesign every page of a kind, else from `docsygen/skeleton/default.html`. The kind is the
compound kind of the page (`class`, `struct`, `namespace`, `file`, `group`, `page`, `concept`,
`dir`, …), or `root`, `tree-<name>`, `index-<name>`, `all-members` or `source`. The template gets
`{entry, paths, dir, pathMap, blocks}`, `blocks` being the page's parts in Doxygen's order, and
returns Markdown: headings, text, and a shortcode per part, which
`partial "docsygen/skeleton/call.html" $block` writes. For example, a class page without its
summary tables:

```go-html-template
{{- $out := slice -}}
{{- range .blocks -}}
  {{- if not (in (slice "title" "summary-links" "heading" "decls") .type) -}}
    {{- $out = $out | append (partial "docsygen/skeleton/call.html" .) -}}
  {{- end -}}
{{- end -}}
{{- return delimit $out "\n\n" -}}
```

## The example site

`exampleSite/` renders [PDI](https://pdi.dev)'s reference from its committed XML, in three
versions: `main`, the latest release, 1.12, and an older one, 1.7
(`exampleSite/assets/doxygen/README.md` says how each was made), in two organizations:

- the whole Doxygen tree per version, under `/docs/` (`content/`): `npm run serve`;
- PDI's own organization (`content-pdi/`), with the main page at `/about/<version>/`, the
  narrative pages at `/guide/<version>/` (one menu entry, where PDI's own menu lists each), the
  C API's topics at `/c-api/<version>/`, the namespaces at `/plugin-api/<version>/`, and a
  hand-written page that claims `PDI::Array_datatype`:
  `npx hugo server --config hugo.yaml,pdi-layout.yaml`.

From that directory, run `npx npm@11 install` first. `hugo server` builds `main` and `latest`
only (`config/development/hugo.yaml`). `exampleSite/check-docsy.sh` and
`exampleSite/check-layout.sh` build them and check their output.
