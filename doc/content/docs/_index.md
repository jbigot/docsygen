---
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
title: Documentation
description: >-
  How to generate the C and C++ API reference of a Docsy site from Doxygen's XML.
weight: 1
---

docsygen is a [Hugo](https://gohugo.io/) module that turns the XML output of
[Doxygen](https://www.doxygen.nl/) into native pages of a [Docsy](https://www.docsy.dev/) site:
the C and C++ API reference (classes, namespaces, files, groups, pages, examples, class hierarchy), with
links between them and from your hand-written pages. It reads the XML directly, from a content
adapter: no tool runs between `doxygen` and `hugo`.

The [reference](reference/latest/) of this site comes from docsygen, and the examples on these
pages run on its XML: a small C++ project that uses every construct docsygen renders.
