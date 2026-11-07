---
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
title: Doxygen options
description: >-
  The Doxygen options that change what docsygen shows.
weight: 70
---

`XML_PROGRAMLISTING`
: `YES` gives each file its source listing, which roughly doubles the XML and the build time;
  `NO` is faster, with no source listings.

`SHOW_FILES`
: `NO` leaves out the file pages, as Doxygen's HTML does; directories keep theirs.

`SHOW_USED_FILES`
: `NO` leaves out the list of files a class's documentation was generated from, as Doxygen's HTML
  does.

`EXTENSION_MAPPING`, `TAB_SIZE`
: A listing is highlighted in the language of its extension: a file's, or the one Doxygen gives a
  fence (```` ```C ```` is `.C`). Fortran's form follows Doxygen: an extension that
  `EXTENSION_MAPPING` maps to `FortranFixed` or `FortranFree` sets it, and otherwise (`.f`, `.f90`,
  … and a ```` ```Fortran ```` fence, which Doxygen writes `.f`) Doxygen's rule reads it from the
  code, a tab counting `TAB_SIZE` columns: fixed form when its first line of code starts from
  column 7 (but with a `C` or a `*`), or when a `C` or `*` in column 1 starts a comment. A fence
  can't name the form: Doxygen writes ```` ```fortranfree ```` as `.f90`, which it reads that same
  way.

`EXTRACT_PRIVATE`, `EXTRACT_STATIC`, `INLINE_SIMPLE_STRUCTS`, `SORT_MEMBER_DOCS`, …
: The options that decide what Doxygen's HTML shows are read from the XML's `Doxyfile.xml`, and
  decide what docsygen shows.
