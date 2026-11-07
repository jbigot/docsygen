---
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
title: Placements
description: >-
  Place parts of the reference anywhere in the site.
weight: 40
---

By default a call places a version's whole tree. With `select`, it places one part of it, so that
a site can arrange the reference as it likes, with one call per part and version. [PDI's
website](https://pdi.dev/) is arranged that way, from its `content/_content.gotmpl`:

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
  `select: ""` with `children: false` places the main page alone. PDI's website places its pages
  one by one: its installation page is `page:Installation` at `docs/:version/installation`. A member has no page of its own: [embed it]({{< relref "embedding" >}})
  instead.

Landing pages
: The section of a deeper root's `:version` segment, `docs/1.0/` for a root at
  `docs/:version/api`, has no content unless a call places a page there: `select: ""` with
  `children: false` places the main page, `select: "page:intro"` with `children: false` another
  page. That call must come before the calls that place pages below it, which would otherwise
  have added the section already: the build stops, naming both calls. PDI's example above places
  its main page first.

`content`
: Hand-written Markdown in place of a part of the XML: the call places one page at its path, with
  no `select`, `children`, `duplicate` or `topicMembers`. At the `:version` segment, it is the
  version's landing page, with its version menu, notice and canonical link, titled with the
  project's name and the version unless `title` is given, and the same rule of order applies:

  ```go-html-template
  {{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/mylib" "version" "1.0"
       "path" "dev/:version" "content" (resources.Get "landing/dev.md").Content) -}}
  ```

  The same text given to every version's call is one page shared by all of them. Its shortcodes
  take the version of the page they render on, but a `doxygen:` link without a version goes to
  the latest release: link to the version's own pages with relative links, `[the API](api/)`.

`path`
: a pattern with one `:version` segment, anywhere: `:version`, `guide/:version`,
  `docs/:version/api`. The placed pages keep their place below the selected one. The pages
  between the `:version` segment and a deeper root are sections that docsygen adds, with no
  content; the segments above it are your site's own sections.

`topicMembers`
: Whether the pages of the placement list, besides the entities they document, those that a
  topic (a Doxygen group) documents (default `true`). Every entity is listed in the namespace it
  belongs to, the API reference's root (`api`) being the root namespace's page, and links to its
  canonical page: its topic's when it is in one, its namespace's otherwise. A namespace page
  documents in detail only what has no other canonical page. With `topicMembers: false`, the
  namespace pages leave out the entities of topics, for a site that places its topics as an API
  of their own: a C API's functions are then not listed again under `api`; when every global
  entity is in a topic, the root then lists only the namespaces and global classes, or nothing.
  Topic and class pages always list their members.

{{% alert title="Global entities live on the API reference's root" color="warning" %}}
The functions, variables, types and macros out of any namespace and topic are documented on the
API reference's root, `api`, not on their file's page, whatever the placements. A site that
places `files` but not `api` gets them unplaced: links to them are rendered as text, with a
`docsygen-unplaced` warning. Place `api` too, or put them in a topic.
{{% /alert %}}

Titles
: The placement's root keeps the selected page's title unless `title` or `linkTitle` are given. A
  root at the `:version` segment is its version's section: its menu title stays the version
  unless `linkTitle` is given, and its weight orders it as the version menu does.

{{% alert title="One page per item" color="warning" %}}
Two placements of one adapter file that generate the same page stop the build, naming both, and
so does a call made twice. An adapter file that runs once per language (`EnableAllLanguages`) runs
its calls once in each, which is fine.
Calls in different adapter files can't see each other: when one adapter file is in a directory
below another's, they must not generate the same paths.
{{% /alert %}}
