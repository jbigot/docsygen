---
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
title: Versions
description: >-
  Several versions of the reference, the latest release, the version menu, canonical links and development mode.
weight: 20
---

Call the adapter once per version, each with its own `dir`:

```go-html-template
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/mylib-main" "version" "main" "path" ":version") -}}
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/mylib-2.1" "version" "2.1" "path" ":version" "latest" true) -}}
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/mylib-2.0" "version" "2.0" "path" ":version") -}}
```

The calls of one version, which may [place several parts of it]({{< relref "placements" >}}),
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
  one, and each entry leads to the same page in that version, wherever it is placed. When that
  version lacks the page, the entry leads to the nearest parent that exists at the same path in
  that version, or, for a version placed elsewhere, to its root. Hand-written pages show no
  menu, unless they [claim an item]({{< relref "hand-written-pages" >}}).

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

## Development mode

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
