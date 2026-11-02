---
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
title: Get started
description: >-
  Requirements, importing the module, bringing in Doxygen's XML and calling the content adapter.
weight: 10
---

## Requirements

| Tool | Versions | Notes |
| --- | --- | --- |
| Hugo | 0.169.0 or later, extended edition | docsygen reads the XML with Hugo's own decoder when Hugo has its document layout, and with its own reader otherwise, with the same result |
| Docsy | 0.18 (`github.com/docsy/docsy/theme`) | with its usual requirements: the `sass` CLI on `PATH`, Bootstrap and Font Awesome from npm |
| Doxygen | 1.17 to 1.18 | with `GENERATE_XML = YES` |

## Set up

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

Then load its styles from your `assets/scss/_styles_project.scss`:

```scss
@use 'docsygen';
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
| `version` | yes | the version's label, as [`doxygen:` links]({{< relref "linking" >}}) name it |
| `path` | yes | where the pages go, relative to the adapter's directory: a pattern with one `:version` segment, which the label fills (`:version`, `docs/:version/api`) |
| `select` | no | what to place, by default the whole tree: see [Place parts of the reference]({{< relref "placements" >}}) |
| `children` | no | whether the pages below the selected one come too (default `true`) |
| `title`, `linkTitle`, `weight` | no | the placed root's title, menu title and weight |
| `duplicate` | no | `true`, or the page keys and names whose pages are duplicates: see [Hand a page over]({{< relref "hand-written-pages" >}}) |
| `latest` | no | whether this is the latest release (default `false`): see [Versions]({{< relref "versions" >}}) |
| `search` | no | whether its pages are in Docsy's search index (default: the value of `latest`) |
| `pathMap` | no | rewrites of file locations for the file tree, `[{from, to}]` (default `[]`) |

The whole tree holds `pages/`, `topics/`, `api/`, `files/`, `examples/` and `indexes/` sections,
each only when Doxygen has something for it.

`pathMap` matches each file location after the common leading directories are stripped, and
rewrites it with the first `from` that starts it: `[{from: "build/gen/", to: ""}]` moves
generated headers next to the sources. A directory left without files joins its parent's page.
