---
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
title: Formulas
description: >-
  Formulas render through KaTeX; one it can't render stops the build, and says how to get out.
weight: 77
---

Doxygen's formulas, `\f$…\f$` inline and `\f[…\f]` or `\f{env}{…\f}` displayed, render through
KaTeX when the site is built, as Docsy renders its own: an inline formula in the text, a display
formula through the site's math code-block hook (Docsy's).

## A formula KaTeX can't render

KaTeX lacks some of LaTeX: `eqnarray*`, for one, or a macro of the project's own. Such a formula
stops the build, with a message that quotes it as the XML writes it and says where it is:

```text
docsygen: formula "\begin{eqnarray*} a &=& b \end{eqnarray*}" can't be rendered (KaTeX parse error: No such environment: eqnarray* at position 7: …), on page /docs/latest/api/demo/markup, member formulas. Fix it in the documentation that generates the XML, or show its source instead: list it in sourceFormulas, an option of the adapter call or of the page's params.docsygen.
```

For a display formula, the message is a warning just before the error of the math hook, which
stops the build on Docsy; a site whose hook doesn't use KaTeX only gets the warning.

There are two ways out:

- change the formula in the documentation that generates the XML: `align*` in place of
  `eqnarray*`, for instance;
- or, for a site that can't change the XML, show it as its LaTeX source, highlighted, instead of
  rendering it.

## Show formulas as their source

The adapter's option `sourceFormulas` lists the formulas to show as source on the pages of its
placement, each as the message quotes it, or is `true` for all of them:

```go-html-template
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/pdi" "version" "1.0"
     "path" ":version" "sourceFormulas" (slice `\begin{eqnarray*} a &=& b \end{eqnarray*}`)) -}}
```

A hand-written page that embeds parts of the reference lists more in its front matter, for what
it renders; they add to its placement's:

```yaml
params:
  docsygen:
    sourceFormulas:
      - '$ \nosuchmacro $'
```

In YAML, single quotes keep the backslashes as they are. A listed formula shows as written,
Doxygen's delimiters (`$…$`, `\[…\]`) included, in a LaTeX listing for a display formula and as
inline code for an inline one.
