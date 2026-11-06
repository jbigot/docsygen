---
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
title: Customizing
description: >-
  Override the rendered blocks, the page skeletons and the hooks.
weight: 80
---

Rendered blocks
: Each block goes through a partial named `docsygen/markup/block-<type>.html`, and descriptions
  through `docsygen/markup/doc.html` and `docsygen/markup/doc-node.html`. Override one with a file
  of the same name in your `layouts/_partials/docsygen/markup/`. The markup only uses
  `docsygen-*` classes, which `_docsygen.scss` styles with Bootstrap's `--bs-*` variables.

Page skeletons
: The Markdown of a page comes from `docsygen/skeleton/<kind>.html`, else from
  `docsygen/skeleton/default.html`. The kind is the page's compound kind (`class`, `namespace`,
  `file`, `group`, `page`, …), or `root`, `tree-<name>` or `source`. The template
  gets `{entry, paths, dir, pathMap, blocks}` and returns Markdown, with a shortcode per block that `partial "docsygen/skeleton/call.html" $block` writes.

The page tree
: It comes from `docsygen/paths/scheme.html`.

Wording
: Every word docsygen writes goes through Hugo's `i18n`, with keys in
  [`i18n/en.yaml`](https://github.com/jbigot/docsygen/blob/main/i18n/en.yaml): headings
  (`docsygen-section-public-func`), titles (`docsygen-class-reference`), sentences
  (`docsygen-definition-at-line`), and the notice of other versions. Reword or translate them in
  your own `i18n/<lang>.yaml`, keeping the keys; a language's file must hold them all. The
  arguments are named fields (`{{ .name }}`), and a string that depends on a number has plural
  forms (`one`, `other`).

For example, a class page without its list of members, in `layouts/_partials/docsygen/skeleton/class.html`:

```go-html-template
{{- $out := slice -}}
{{- range .blocks -}}
  {{- if not (in (slice "title" "heading" "list") .type) -}}
    {{- $out = $out | append (partial "docsygen/skeleton/call.html" .) -}}
  {{- end -}}
{{- end -}}
{{- return delimit $out "\n\n" -}}
```

## Your own hooks

docsygen's canonical links go through Docsy's hooks. If your site has its own
copy of one, call docsygen from it:

| Your file | Add |
| --- | --- |
| `layouts/_partials/hooks/head-end.html` | `{{- partial "docsygen/canonical-link.html" . -}}` |
| `layouts/_markup/render-link.html` | see [Link to the reference]({{< relref "linking" >}}) |
