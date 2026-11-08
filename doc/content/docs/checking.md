---
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
title: Checking a site
description: >-
  Check a built site for the links and ids that a build can't check.
weight: 90
---

Some mistakes only show once the site is built: a link to a member that lands on a page without
its anchor, because a hand-written page claims the class and embeds only some of its members, or
a member's anchor that equals the id of a heading of the hand-written page that holds it. docsygen
can't see them while Hugo builds the pages, so it offers a check that reads the built site:

```sh
hugo --destination public
docsygen=$(hugo config mounts | awk '/"path": "github.com\/jbigot\/docsygen"/ {found = 1}
  found && /"dir":/ {sub(/.*"dir": "/, ""); sub(/",$/, ""); print; exit}')
python3 -I "$docsygen/tools/check.py" public - -
```

It reports, then exits with 1:

- every internal link whose page or fragment doesn't exist, but those that the documentation's
  authors wrote as URLs, which docsygen leaves as they are;
- every id that appears twice in a page;
- an `<a name>`, or an id of Doxygen's own anchors (`a12_…`, `r_…`), which nothing links to;
- a paragraph that holds a block, such as a list or a table;
- what a docsygen shortcode leaves when it is called as `{{</* */>}}` rather than `{{%/* */%}}`:
  shortcode delimiters out of code, or a heading with its `{#id}` as text;
- a site without any page.

The anchors that docsygen derives from the code start with `dg-` (`#dg-width`), so a hand-written
heading only meets one when it starts with `dg-` too. docsygen's own tests run more checks, which
need the XML of a version root and a site without Docsy's layout: that each documented entity
appears once, and that pages use no class but docsygen's own and the few of Bootstrap's, Docsy's,
KaTeX's and Chroma's that it relies on.

`hugo config mounts` says where Hugo found docsygen: in its module cache, at the version the
site's `go.mod` requires, or in the checkout that replaces it.

A site with versions checks that every page of its latest release has a redirect at its numbered
path, which Hugo's aliases give and a site's own redirects could shadow:

```sh
python3 -I "$docsygen/tools/check_redirects.py" public /docs/latest/ /docs/2.1/
```
