---
title: docsygen
description: >-
  Generate the C and C++ API reference of a Docsy site from Doxygen's XML: set up, the content
  adapter, versions, links, placements, hand-written pages and shortcodes.
---

docsygen is a [Hugo](https://gohugo.io/) module that turns the XML output of
[Doxygen](https://www.doxygen.nl/) into native pages of a [Docsy](https://www.docsy.dev/) site:
the C and C++ API reference (classes, namespaces, files, groups, pages, examples, indexes), with
links between them and from your hand-written pages. It reads the XML directly, from a content
adapter: no tool runs between `doxygen` and `hugo`.

The reference of this site, PDI's, comes from docsygen, and the examples on this page run on
PDI's XML.

## Requirements

| Tool | Versions | Notes |
| --- | --- | --- |
| Hugo | 0.169.0 or later, extended edition | docsygen reads the XML with Hugo's own decoder when Hugo has its document layout, and with its own reader otherwise, with the same result |
| Docsy | 0.18 (`github.com/docsy/docsy/theme`) | with its usual requirements: the `sass` CLI on `PATH`, Bootstrap and Font Awesome from npm |
| Doxygen | 1.17 to 1.18 | with `GENERATE_XML = YES` |

## Get started

### 1. Import the module

Import docsygen next to Docsy, in your `hugo.yaml`:

```yaml
module:
  imports:
    - path: github.com/jbigot/docsygen
    - path: github.com/docsy/docsy/theme
```

{{% alert title="docsygen comes first" color="warning" %}}
docsygen replaces some of Docsy's partials (the version menu and banner, the `head-end` hook and
the print heading of docs pages), which only works when it is imported **before** Docsy. The build
stops otherwise.
{{% /alert %}}

Then import its styles from your `assets/scss/_styles_project.scss`:

```scss
@import 'docsygen';
```

### 2. Bring in Doxygen's XML

docsygen reads the XML directory that Doxygen writes (`XML_OUTPUT`, `xml` by default) from Hugo's
`assets/`:

{{< tabpane text=true >}}
{{% tab header="A copy" %}}
Copy the directory under your site's `assets/`, for example as `assets/doxygen/mylib/`.
{{% /tab %}}
{{% tab header="A mount" %}}
Mount the directory from outside the site, with an absolute `source`:

```yaml
module:
  mounts:
    - source: /path/to/build/doc/xml
      target: assets/doxygen/mylib
```

Mount `assets` itself too, since a mount replaces the default one:
`{source: assets, target: assets}`.
{{% /tab %}}
{{< /tabpane >}}

{{% alert title="No symbolic links" color="warning" %}}
Hugo drops symlinked mounts: point the mount at the directory itself.
{{% /alert %}}

### 3. Generate the pages

Call docsygen's content adapter, `docsygen/adapter.html`, from a `_content.gotmpl` file, for
example `content/docs/_content.gotmpl`:

```go-html-template
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/mylib" "version" "1.0" "path" ":version" "latest" true) -}}
```

and let each version be its own sidebar root, in `hugo.yaml`:

```yaml
params:
  ui:
    sidebar_root_enabled: true
```

The reference is now at `/docs/latest/`. Keep it below a top-level section (`content/docs/`, not
`content/`), or Docsy warns about `sidebar_root_for`.

## The content adapter

Each call of `docsygen/adapter.html` adds pages from one version of the reference, below the
directory of its `_content.gotmpl`.

| Option | Required | Meaning |
| --- | --- | --- |
| `store` | yes | the adapter's context, `.` |
| `dir` | yes | the XML directory, under `assets/` |
| `version` | yes | the version's label, as [`doxygen:` links](#link-to-the-reference) name it |
| `path` | yes | where the pages go, relative to the adapter's directory: a pattern with one `:version` segment, which the label fills (`:version`, `docs/:version/api`) |
| `select` | no | what to place, by default the whole tree: see [Place parts of the reference](#place-parts-of-the-reference) |
| `children` | no | whether the pages below the selected one come too (default `true`) |
| `title`, `linkTitle`, `weight` | no | the placed root's title, menu title and weight |
| `duplicate` | no | `true`, or the page keys and names whose pages are duplicates: see [Hand a page over](#hand-a-page-over) |
| `latest` | no | whether this is the latest release (default `false`): see [Versions](#versions) |
| `search` | no | whether its pages are in Docsy's search index (default: the value of `latest`) |
| `pathMap` | no | rewrites of file locations for the file tree, `[{from, to}]` (default `[]`) |

The whole tree holds `pages/`, `topics/`, `api/`, `files/`, `examples/` and `indexes/` sections,
each only when Doxygen has something for it.

`pathMap` matches each file location after the common leading directories are stripped, and
rewrites it with the first `from` that starts it: `[{from: "build/gen/", to: ""}]` moves
generated headers next to the sources. A directory left without files joins its parent's page.

### Versions

Call the adapter once per version, each with its own `dir`:

```go-html-template
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/mylib-main" "version" "main" "path" ":version") -}}
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/mylib-2.1" "version" "2.1" "path" ":version" "latest" true) -}}
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/mylib-2.0" "version" "2.0" "path" ":version") -}}
```

The calls of one version, which may [place several parts of it](#place-parts-of-the-reference),
name the same `dir` and `pathMap`, or the build stops.

The latest release
: The call marked `latest`, one at most, generates its pages at `latest/` (`/docs/latest/`), and
  each one gets an alias at its numbered path (`/docs/2.1/…`) that redirects there and keeps the
  URL's `#fragment`. When 2.2 comes out, mark it `latest` instead: `/docs/2.1/` becomes an
  ordinary version, and its links keep working. The label `latest`, and a `latest` segment in
  `path`, are reserved for it.

Titles and order
: Each version's root is titled with the project's name (Doxygen's `PROJECT_NAME`) and its
  label. The sidebar and the version menu list the versions that are not release numbers
  (`main`) first, then the releases newer than the latest one, the latest release, and the older
  releases, newest first (`2.10` before `2.9`).

Version menu
: On a generated page, Docsy's navbar menu lists the versions, `latest (2.1)` for the latest
  one, and each entry leads to the same page in that version, wherever it is placed, or to its
  nearest existing parent. Hand-written pages show no menu, unless they
  [claim an item](#hand-a-page-over).

Notice
: The pages of `main`, of releases newer than the latest, and of older releases say so above
  their content, with a link to the same page in the latest release. It replaces Docsy's
  version banner. Reword or translate it in your `i18n/<lang>.yaml`, with the keys
  `docsygen-notice-older` and `docsygen-notice-main`.

Canonical links and search
: A page of `latest/` is its own canonical page; a page of another version points its canonical
  link at the same page in `latest/`, if there is one. Only `latest/` is in the sitemap and, unless
  a call sets `search`, in the search index.

{{% alert title="Docsy's chrome mode" color="info" %}}
Docsy's `shared` chrome mode (`td.chrome`) copies one navbar into every page, which drops the
version menu: docsygen warns when a page of the reference is in it, and needs the default,
`full`.
{{% /alert %}}

### Development mode

Building every version takes time. To build only some of them while you edit, list their labels
in `params.docsygen.versions`, `latest` allowed, in the configuration of `hugo server`'s
environment, `config/development/hugo.yaml`:

```yaml
params:
  docsygen:
    versions: [main, latest]
```

`hugo`, whose environment is `production`, still builds every version. The versions left out are
missing from the version menu, and a link to one of them renders as its text, with a warning.
The latest version must be built.

{{% alert title="Quote version numbers" color="warning" %}}
YAML reads an unquoted `1.10` as the number 1.1, and a label that no adapter call has stops the
build: write `"1.10"`.
{{% /alert %}}

## Link to the reference

From any Markdown page, link to an item of the reference with a `doxygen:` destination. docsygen
finds the page that holds it, in whichever placement:

| Markdown | Renders as |
| --- | --- |
| `[the datatype class](doxygen:PDI::Datatype)` | [the datatype class](doxygen:PDI::Datatype) |
| `[](doxygen:PDI_share)` | [](doxygen:PDI_share) |
| `[installing PDI](doxygen:Installation)` | [installing PDI](doxygen:Installation) |
| `[](doxygen:PDI::Array_datatype)` | [](doxygen:PDI::Array_datatype) |
| `[PDI_share in 1.7](doxygen:1.7/PDI_share)` | [PDI_share in 1.7](doxygen:1.7/PDI_share) |

An empty text shows the item's name as code, or a page's title. `PDI::Array_datatype` goes to the
[hand-written page that claims it](#hand-a-page-over), not to the generated one.

The destination is `[VERSION/][KIND:]NAME[(SIGNATURE)][#FRAGMENT]`:

`VERSION`
: a version's label, or `latest`; without it, the latest release. Naming the latest release by its
  number (`doxygen:2.1/…`) links to its alias, so that the link stays on 2.1 after the next
  release.

`KIND`
: a compound kind (`class`, `file`, `dir`, `page`, `group`, …), a member kind, or `member`;
  without it, symbols win, then pages, groups, files and directories.

`NAME`
: the name as Doxygen writes it: `PDI::Datatype`, `PDI_share`, a `\page` name.

`SIGNATURE`
: the parameter types of an overload, and `const`. A destination with spaces needs Markdown's
  angle brackets: `[x](<doxygen:demo::Widget::resize(int, int) const>)`.

`FRAGMENT`
: an anchor of the target page.

{{% alert title="Broken links stop the build" color="warning" %}}
A destination that resolves to nothing stops the build. A target that exists but that no page
of its version holds, because no placement selects it, renders as its text, with a warning
(`docsygen-unplaced`, which `ignoreLogs` can silence).
{{% /alert %}}

The links go through docsygen's `layouts/_markup/render-link.html`, which renders other links as
Hugo's embedded hook does. If your site has its own `render-link.html`, send `doxygen:`
destinations to docsygen from it:

```go-html-template
{{- if hasPrefix .Destination "doxygen:" -}}
  {{- partial "docsygen/link.html" . -}}
{{- else -}}
  …your rendering…
{{- end -}}
```

On a multilingual site with a single host, set `markup.goldmark.renderHooks.link.useEmbedded` to
`fallback`, or Hugo's embedded link hook takes over.

## Place parts of the reference

By default a call places a version's whole tree. With `select`, it places one part of it, so that
a site can arrange the reference as it likes, with one call per part and version. This site is
arranged that way, from its `content/_content.gotmpl`:

```go-html-template
{{- range slice (dict "dir" "doxygen/pdi" "version" "main") (dict "dir" "doxygen/pdi-1.12" "version" "1.12" "latest" true)
    (dict "dir" "doxygen/pdi-1.7" "version" "1.7") -}}
  {{- partial "docsygen/adapter.html" (merge . (dict "store" $ "path" "docs/:version" "select" "" "children" false "title" "About")) -}}
  {{- partial "docsygen/adapter.html" (merge . (dict "store" $ "path" "c-api/:version" "select" "topics" "title" "C API Reference")) -}}
  {{- partial "docsygen/adapter.html" (merge . (dict "store" $ "path" "plugin-api/:version" "select" "api" "title" "Plugin API reference")) -}}
{{- end -}}
```

`select`
: a page key of the whole tree (`pages`, `topics`, `api/mylib`, `pages/install`), or a compound's
  name as a `doxygen:` link writes it (`mylib::Widget`, `page:install`, `group:io`). The
  placement holds that page and every page below it, or the page alone with `children: false`.
  `select: ""` with `children: false` places the main page alone, as [About](/docs/latest/) does
  here. A member has no page of its own: [embed it](#embed-the-reference) instead.

`path`
: a pattern with one `:version` segment, anywhere: `:version`, `guide/:version`,
  `docs/:version/api`. The placed pages keep their place below the selected one. The pages
  between the `:version` segment and a deeper root are sections that docsygen adds; the segments
  above it are your site's own sections.

Titles
: The placement's root keeps the selected page's title unless `title` or `linkTitle` are given. A
  root at the `:version` segment is its version's section: its menu title stays the version
  unless `linkTitle` is given, and its weight orders it as the version menu does.

{{% alert title="One page per item" color="warning" %}}
Two placements of one adapter file that generate the same page stop the build, naming both.
Calls in different adapter files can't see each other: when one adapter file is in a directory
below another's, they must not generate the same paths.
{{% /alert %}}

## Hand a page over

A hand-written page can be the page of an item in one version, in place of the generated one:
links to the item, and to its members, then go to it. It claims the item in its front matter, as
this site's [Array datatype](/guide/latest/array-datatype/) page does:

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
[shortcodes](#embed-the-reference), which take its version: a full member carries its anchor, so
that links to the member land on it, and an `{#details}` heading takes the links to the item's
detailed description. A page that claims an item is a page of its version: it has the version
menu, the notice and the canonical link of the item's page.

Every item has at most one canonical page per version, so the generated page must give way. Mark
it as a duplicate with the call's `duplicate` option, `true` for all its pages, or a list of page
keys and names for those pages and the pages below them:

```go-html-template
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/pdi-1.12" "version" "1.12" "latest" true
    "path" "plugin-api/:version" "select" "api" "duplicate" (slice "PDI::Array_datatype")) -}}
```

A duplicate is still a page of the site, but no link goes to it, it is out of the search index
and the sitemap, and its canonical link is that of the page that holds its item.

{{% alert title="Nested classes" color="info" %}}
A duplicate takes the pages below it along: the nested classes of a class marked as a duplicate
need a claim too, or links to them render as text. A page can claim several items only when their
anchors differ: two classes both have `details`, so each needs its own page.
{{% /alert %}}

## Embed the reference

Any page can show a part of a version's reference with three shortcodes. The generated pages are
built from the same ones, so an embedded part looks as it does on its own page, and its links go
to the version's own pages.

All three take:

| Parameter | Meaning |
| --- | --- |
| `item` | what to show, named as a `doxygen:` link names it (`[KIND:]NAME[(SIGNATURE)]`), without the version |
| `id` | what to show, by its Doxygen id, instead of `item` |
| `version` | the version; by default, that of the version root above the page, or the page's `params.docsygen.version`, else `latest` |

Hugo's shortcodes can't mix positional and named arguments, hence `item=`. A part that the version
lacks stops the build; a version that development mode leaves out embeds nothing, with a warning.

### `docsygen/member`

A member, with `form="full"` (the default), its documentation as its compound's page shows it, or
`form="summary"`, its row of the summary table:

```markdown
{{</* docsygen/member item="PDI_share" form="summary" */>}}
```

{{< docsygen/member item="PDI_share" form="summary" >}}

The full form carries the member's anchor, so that links to the member can land on the page,
unless the page already has it, from the member's heading or an earlier full form:

```markdown
{{</* docsygen/member item="PDI_share" */>}}
```

{{< docsygen/member item="PDI_share" >}}

### `docsygen/members`

Every member that a compound's page documents, in its order, each in full: a hand-written page for
a class lists them all, and keeps up with the members later versions add.

```markdown
{{</* docsygen/members item="PDI::Error" */>}}
```

{{< docsygen/members item="PDI::Error" >}}

### `docsygen/part`

One part of a page, `part` being its type:

| `part` | Shows | Other parameters |
| --- | --- | --- |
| `brief` | the brief description | |
| `includes` | the `#include` lines | |
| `diagram` | the inheritance diagram | |
| `concept-definition` | a concept's definition | |
| `decls` | a summary table | `section`, its key: `public-func`, `func`, `typedef`, … |
| `description` | the detailed description, with its sections | |
| `section` | one section of the description | |
| `inline-classes` | the classes documented inline | |
| `member` | one member | |
| `all-members` | the list of all members, inherited ones included | |
| `tree` | a list (no `item`) | `name`: `annotated`, `namespaces`, `files`, … |
| `index` | an index (no `item`) | `name`, `filter`, `letter` |
| `source` | a file's source listing | |
| `generated-from` | the files a compound's documentation comes from | |

```markdown
{{</* docsygen/part item="PDI::Datatype" part="brief" */>}}
{{</* docsygen/part item="PDI::Datatype" part="diagram" */>}}
```

{{< docsygen/part item="PDI::Datatype" part="brief" >}}

{{< docsygen/part item="PDI::Datatype" part="diagram" >}}

## Doxygen options that matter

`XML_PROGRAMLISTING`
: `YES` gives each file its source listing, which roughly doubles the XML and the build time;
  `NO` is faster, with no source listings.

`SHOW_FILES`
: `NO` leaves out the file pages, as Doxygen's HTML does; directories keep theirs.

`EXTRACT_PRIVATE`, `EXTRACT_STATIC`, `INLINE_SIMPLE_STRUCTS`, `SORT_MEMBER_DOCS`, `IGNORE_PREFIX`, …
: The options that decide what Doxygen's HTML shows are read from the XML's `Doxyfile.xml`, and
  decide what docsygen shows.

## Customize the rendering

Rendered blocks
: Each block goes through a partial named `docsygen/markup/block-<type>.html`, and descriptions
  through `docsygen/markup/doc.html` and `docsygen/markup/doc-node.html`. Override one with a file
  of the same name in your `layouts/_partials/docsygen/markup/`. The markup only uses
  `docsygen-*` classes, which `_docsygen.scss` styles with Bootstrap's `--bs-*` variables.

Page skeletons
: The Markdown of a page comes from `docsygen/skeleton/<kind>.html`, else from
  `docsygen/skeleton/default.html`. The kind is the page's compound kind (`class`, `namespace`,
  `file`, `group`, `page`, …), or `root`, `tree-<name>`, `index-<name>`, `all-members` or
  `source`. The template gets `{entry, paths, dir, pathMap, blocks}` and returns Markdown, with a
  shortcode per block that `partial "docsygen/skeleton/call.html" $block` writes.

The page tree
: It comes from `docsygen/paths/scheme.html`.

For example, a class page without its summary tables, in `layouts/_partials/docsygen/skeleton/class.html`:

```go-html-template
{{- $out := slice -}}
{{- range .blocks -}}
  {{- if not (in (slice "title" "summary-links" "heading" "decls") .type) -}}
    {{- $out = $out | append (partial "docsygen/skeleton/call.html" .) -}}
  {{- end -}}
{{- end -}}
{{- return delimit $out "\n\n" -}}
```

### Your own hooks

docsygen's canonical links and print notice go through Docsy's hooks. If your site has its own
copy of one, call docsygen from it:

| Your file | Add |
| --- | --- |
| `layouts/_partials/hooks/head-end.html` | `{{- partial "docsygen/canonical-link.html" . -}}` |
| `layouts/_partials/print/page-heading-docs.html` | `{{ partial "version-banner.html" .Page }}` |
| `layouts/_markup/render-link.html` | see [Link to the reference](#link-to-the-reference) |
