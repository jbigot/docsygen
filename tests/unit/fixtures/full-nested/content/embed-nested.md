---
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
title: A member twice, each in a wrapper
params:
  docsygen:
    version: "1.0"
    claims: ["demo::Button"]
---

{{% wrap %}}
{{% docsygen/member item="demo::Button::press" %}}
{{% /wrap %}}

And again:

{{% wrap %}}
{{% docsygen/member item="demo::Button::press" %}}
{{% /wrap %}}
