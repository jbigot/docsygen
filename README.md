# docsygen

docsygen is a [Hugo](https://gohugo.io/) module that turns the XML output of
[Doxygen](https://www.doxygen.nl/) into native pages of a [Docsy](https://www.docsy.dev/) site:
the C and C++ API reference (classes, namespaces, files, groups, pages, examples, indexes), with
links between them and from your hand-written pages.

It reads the XML directly, from a content adapter: no tool runs between `doxygen` and `hugo`.

## Requirements

- Hugo extended 0.160.1 or later (Docsy 0.18's floor; the module itself needs 0.146.0).
- Docsy 0.18 (module `github.com/docsy/docsy/theme`), with its usual requirements: the `sass`
  CLI on `PATH`, and Bootstrap and Font Awesome from npm.
- Doxygen's XML output: `GENERATE_XML = YES`.

## Set up a site

Import the module next to Docsy, in `hugo.yaml`:

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
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/mylib" "version" "main" "path" "main" "latest" true) -}}
```

| Option | Required | Meaning |
| --- | --- | --- |
| `store` | yes | the adapter's context, `.` |
| `dir` | yes | the XML directory, under `assets/` |
| `version` | yes | the version's label, as `doxygen:` links name it |
| `path` | yes | where the reference goes, relative to the adapter's directory |
| `latest` | no | whether links without a version go to this one (default `false`; one version at most) |
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

## Link to the reference

From any Markdown page, link with a `doxygen:` destination:

```markdown
[the widget](doxygen:demo::Widget)
[](doxygen:demo::Widget)          <!-- empty text: `demo::Widget` as code, a page's title -->
[a section](doxygen:guide#first-section)
[an older version](doxygen:1.9/demo::Widget)
[a directory](doxygen:dir:src)
[one overload](<doxygen:demo::Widget::resize(int, int) const>)
```

The destination is `[VERSION/][KIND:]NAME[(SIGNATURE)][#FRAGMENT]`:

- `VERSION`, a version's label, else the `latest` one;
- `KIND`, a compound kind (`class`, `file`, `dir`, `page`, …), a member kind, or `member`; without
  it, symbols win, then pages, groups, files and directories;
- `NAME`, as Doxygen writes it: `PDI::Datatype`, `PDI_share`, a `\page` name;
- `SIGNATURE`, the parameter types of an overload, and `const`; a destination with spaces needs
  Markdown's angle brackets, `[x](<doxygen:… const>)`;
- `FRAGMENT`, an anchor of the target page.

A destination that resolves to nothing stops the build.

The links go through docsygen's `layouts/_markup/render-link.html`, which renders other links as
Goldmark does. If your site has its own `render-link.html`, it shadows docsygen's: send
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

`exampleSite/` renders [PDI](https://pdi.dev)'s reference from its committed XML. From that
directory, `npx npm@11 install` then `npm run serve`. `exampleSite/check-docsy.sh` builds it and
checks its output.
