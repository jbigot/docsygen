---
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
title: Tabs
---

A page with Docsy tabpanes of its own beside an embedded group of example variants
(tests/docsy/check_docsy.py): every id is unique, and each tab controls its own pane.

{{< tabpane text=true >}}
{{% tab header="One" %}}First pane of the page's own tabs.{{% /tab %}}
{{% tab header="Two" %}}Second pane of the page's own tabs.{{% /tab %}}
{{< /tabpane >}}

{{% docsygen/part item="demo::grow" part="member" %}}

{{< tabpane text=true >}}
{{% tab header="Three" %}}First pane of the page's other tabs.{{% /tab %}}
{{% tab header="Four" %}}Second pane of the page's other tabs.{{% /tab %}}
{{< /tabpane >}}
