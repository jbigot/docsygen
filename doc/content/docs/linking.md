---
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
title: Linking
description: >-
  Link to any item of the reference from a Markdown page with a doxygen: destination.
weight: 30
---

From any Markdown page, link to an item of the reference with a `doxygen:` destination. docsygen
finds the page that holds it, in whichever placement:

| Markdown | Renders as |
| --- | --- |
| `[the widget class](doxygen:demo::Widget)` | [the widget class](doxygen:demo::Widget) |
| `[](doxygen:demo::Widget::width)` | [](doxygen:demo::Widget::width) |
| `[the guide](doxygen:guide)` | [the guide](doxygen:guide) |
| `[](doxygen:demo::Circle)` | [](doxygen:demo::Circle) |
| `[Widget in 1.0](doxygen:1.0/demo::Widget)` | [Widget in 1.0](doxygen:1.0/demo::Widget) |

An empty text shows the item's name as code, or a page's title.

The destination is `[VERSION/][KIND:]NAME[(SIGNATURE)][#FRAGMENT]`:

`VERSION`
: a version's label, or `latest`; without it, the latest release. Naming the latest release by its
  number (`doxygen:2.1/…`) links to its alias, so that the link stays on 2.1 after the next
  release.

`KIND`
: a compound kind (`class`, `file`, `dir`, `page`, `group`, …), a member kind, or `member`;
  without it, symbols win, then pages, groups, files and directories.

`NAME`
: the name as Doxygen writes it: `demo::Widget`, `demo::Widget::width`, a `\page` name.

`SIGNATURE`
: the parameter types of an overload, and `const`. A destination with spaces needs Markdown's
  angle brackets: `[x](<doxygen:demo::Widget::resize(int, int) const>)`.

`FRAGMENT`
: an anchor of the target page. The anchors docsygen derives from the code start with `dg-`: a
  member's (`dg-width`), an overload set's (`dg-resize-overloads`), the detailed description's
  (`dg-details`), so that none meets an id of Docsy's or a heading of a hand-written page. The ones
  an author names, `\anchor` and `\section`, keep their names, but for Docsy's own ids (`print`,
  `TableOfContents`, …), which they leave to Docsy (`print-1`). A fragment written by hand, in a
  Markdown link (`#width`, the anchor before `dg-`), isn't checked by the build: `tools/check.py`
  reports one that its page lacks ([Checking a site]({{< relref "checking" >}})).

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
