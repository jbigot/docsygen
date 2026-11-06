---
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
title: Example variants
description: >-
  Show one example given in several languages as tabs, one per language.
weight: 75
---

An example given in several languages, C and Fortran for instance, shows as Docsy's tabs, one
per language: [](doxygen:variants) has a few. The language a reader picks is remembered, and
every tabbed example of the site then shows it. Printed, the page shows the variants one after
the other, with no tabs, as Doxygen's own HTML does, where anchors are invisible.

Since neither a printed page nor Doxygen's HTML shows the tabs' headers, name the language in
each variant's own text, as in "C source code:" below.

## Mark the variants

Anchors mark them, nothing else: one for the example, then one per language, made of the
example's name, a dash and the language, each just before its variant.

~~~markdown
@anchor resize
@anchor resize-C
C source code:
```C
demo_resize(w, 3, 4);
```
@anchor resize-Fortran
Fortran source code:
```Fortran
call w%resize(3, 4)
```
~~~

- A variant runs from its anchor to the next variant's, or to the end of its paragraph.
- The tabs are headed with the language as the anchor writes it: `C`, `Fortran`.
- The example's anchor must come just before its first variant's, with only other anchors
  between them. An anchor with a dash and no example's anchor before it, `@anchor plain-dashed`,
  is an ordinary anchor.
- The example ends at the first content that isn't one of its variants.

A variant of several paragraphs is a `@parblock` that starts with its anchor:

~~~markdown
@anchor resize
@parblock
@anchor resize-C
C source code:
```C
demo_resize(w, 7, 8);
```

is the same as:
```C
demo_resize(w, 7, 8);
demo_unused(w);
```
@endparblock

@parblock
@anchor resize-Fortran
…
@endparblock
~~~

## The separator

The adapter's option `variantSeparator` (default `-`) separates the example's name from the
language: with `_`, the anchors are `resize_C` and `resize_Fortran`. Doxygen ends an anchor's name
at `:` and `.`, which therefore can't separate.

## Links

`@ref resize` links to the example, and `@ref resize-Fortran` to its Fortran variant. Both
scroll to the top of the example's tabs, whichever tab is selected: a link to one language
doesn't select its tab, since Docsy can't select a tab from a link yet.

## Without Docsy

A site without Docsy's `tabpane` shortcode shows the variants one after the other, as Doxygen
does.
