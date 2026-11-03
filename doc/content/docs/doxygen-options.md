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

`EXTRACT_PRIVATE`, `EXTRACT_STATIC`, `INLINE_SIMPLE_STRUCTS`, `SORT_MEMBER_DOCS`, …
: The options that decide what Doxygen's HTML shows are read from the XML's `Doxyfile.xml`, and
  decide what docsygen shows.
