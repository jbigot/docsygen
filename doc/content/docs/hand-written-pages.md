---
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
title: Hand-written pages
description: >-
  Hand a page over: a hand-written page in place of the generated one of an item.
weight: 50
---

A hand-written page can be the page of an item in one version, in place of the generated one:
links to the item, and to its members, then go to it. It claims the item in its front matter:

```yaml
---
title: Circle
params:
  docsygen:
    version: "1.0"
    claims: ["demo::Circle"]
---
```

Each claim is a page key or a name, as `select` takes them. Write the page with the
[shortcodes]({{< relref "embedding" >}}), which take its version: a full member carries its anchor, so
that links to the member land on it, and an `{#details}` heading takes the links to the item's
detailed description. A page that claims an item is a page of its version: it has the version
menu, the notice and the canonical link of the item's page.

Every item has at most one canonical page per version, so the generated page must give way. Mark
it as a duplicate with the call's `duplicate` option, `true` for all its pages, or a list of page
keys and names for those pages and the pages below them:

```go-html-template
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/sample" "version" "1.0" "latest" true
    "path" "docs/:version/api" "select" "api" "duplicate" (slice "demo::Circle")) -}}
```

A duplicate is still a page of the site, but no link goes to it, it is out of the search index
and the sitemap, and its canonical link is that of the page that holds its item.

{{% alert title="Nested classes" color="info" %}}
A duplicate takes the pages below it along: the nested classes of a class marked as a duplicate
need a claim too, or links to them render as text. A page can claim several items only when their
anchors differ: two classes both have `details`, so each needs its own page.
{{% /alert %}}
