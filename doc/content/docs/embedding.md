---
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
title: Embedding
description: >-
  Show a member, a compound or a part of a page anywhere with three shortcodes.
weight: 60
---

Any page can show a part of a version's reference with three shortcodes. The generated pages are
built from the same ones, so an embedded part looks as it does on its own page, and its links go
to the version's own pages.

Call them with `{{%/* */%}}`, as Markdown, and not with `{{</* */>}}`: their output goes through
Hugo's render hooks and goldmark, which needs `markup.goldmark.renderer.unsafe: true`, as Docsy
does. A `{{</* docsygen/… */>}}` call leaves the page's Markdown unread, and the page shows its
headings' `{#id}` as text.

All three take:

| Parameter | Meaning |
| --- | --- |
| `item` | what to show, named as a `doxygen:` link names it (`[KIND:]NAME[(SIGNATURE)]`), without the version |
| `id` | what to show, by its Doxygen id, instead of `item` |
| `version` | the version; by default, that of the version root above the page, or the page's `params.docsygen.version`, else `latest` |

Hugo's shortcodes can't mix positional and named arguments, hence `item=`. A part that the version
lacks stops the build; a version that development mode leaves out embeds nothing, with a warning.

## `docsygen/member`

A member, with `form="full"` (the default), its documentation as its compound's page shows it, or
`form="summary"`, its line of its compound's list:

```markdown
{{%/* docsygen/member item="demo::Widget::width" form="summary" */%}}
```

{{% docsygen/member item="demo::Widget::width" form="summary" %}}

The full form carries the member's anchor, so that links to the member can land on the page,
unless the page already has it, from the member's heading or an earlier full form:

```markdown
{{%/* docsygen/member item="demo::Widget::width" */%}}
```

{{% docsygen/member item="demo::Widget::width" %}}

## `docsygen/members`

Every member that a compound's page documents, in its order, each in full: a hand-written page for
a class lists them all, and keeps up with the members later versions add.

```markdown
{{%/* docsygen/members item="demo::Widget" */%}}
```

{{% docsygen/members item="demo::Widget" %}}

## `docsygen/part`

One part of a page, `part` being its type:

| `part` | Shows | Other parameters |
| --- | --- | --- |
| `brief` | the brief description, which a compound's own page shows as its lead | |
| `includes` | the `#include` lines | |
| `diagram` | the inheritance diagram | |
| `concept-definition` | a concept's definition | |
| `list` | the list of a namespace's, topic's, file's, directory's or class's declarations | |
| `description` | the detailed description, with its sections | |
| `section` | one section of the description | |
| `inline-classes` | the classes documented inline | |
| `member` | one member | |
| `tree` | a list (no `item`) | `name`: `annotated`, `namespaces`, `files`, … |
| `source` | a file's source listing | |
| `generated-from` | the files a compound's documentation comes from | |

```markdown
{{%/* docsygen/part item="demo::Circle" part="brief" */%}}
{{%/* docsygen/part item="demo::Circle" part="diagram" */%}}
```

{{% docsygen/part item="demo::Circle" part="brief" %}}

{{% docsygen/part item="demo::Circle" part="diagram" %}}
