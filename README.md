<!--
SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
SPDX-License-Identifier: MIT
-->

# docsygen

docsygen is a [Hugo](https://gohugo.io/) module that turns the XML output of
[Doxygen](https://www.doxygen.nl/) into native pages of a [Docsy](https://www.docsy.dev/) site:
the C and C++ API reference (classes, namespaces, files, groups, pages, examples, indexes), with
links between them and from your hand-written pages.

It reads the XML directly, from a content adapter: no tool runs between `doxygen` and `hugo`.

**Documentation: <https://jbigot.github.io/docsygen/>**, which is itself built with docsygen.

## Requirements

- Hugo 0.169.0 or later, extended edition.
- Docsy 0.18 (module `github.com/docsy/docsy/theme`), with its usual requirements: the `sass`
  CLI on `PATH`, and Bootstrap and Font Awesome from npm. npm 11.18 or later installs the right
  `sass`. This specific version of Docsy is required for now.
- Doxygen's XML output (`GENERATE_XML = YES`), from Doxygen 1.17 to 1.18.

## Set up a site

Import the module in `hugo.yaml`, **before** Docsy:

```yaml
module:
  imports:
    - path: github.com/jbigot/docsygen
    - path: github.com/docsy/docsy/theme
```

Import its styles from `assets/scss/_styles_project.scss`:

```scss
@import 'docsygen';
```

Copy Doxygen's XML directory under `assets/doxygen/mylib/`, and generate the pages from a content
adapter, `content/docs/_content.gotmpl`:

```go-html-template
{{- partial "docsygen/adapter.html" (dict "store" . "dir" "doxygen/mylib" "version" "1.0" "path" ":version" "latest" true) -}}
```

The reference is at `/docs/latest/`. The [documentation](https://jbigot.github.io/docsygen/docs/)
covers the rest: versions, links from your pages, placements, hand-written pages, embedding,
and customizing.

## Related projects

No other maintained tool brings Doxygen's XML into Hugo. Elsewhere,
[Breathe](https://github.com/breathe-doc/breathe) renders it in Sphinx,
[m.css](https://mcss.mosra.cz/documentation/doxygen/) as HTML, and
[moxygen](https://github.com/sourcey/moxygen) and the archived
[doxybook2](https://github.com/matusnovak/doxybook2) as Markdown.

## Contributing

How to build, test and change docsygen is in [CONTRIBUTING.md](CONTRIBUTING.md).

## License

docsygen is released under the [MIT license](LICENSE). The repository follows the [REUSE
specification](https://reuse.software/spec/): each file carries its own copyright and license in
an `SPDX-` header, or in a `.license` file next to it when it can't hold one (images, JSON,
Doxygen's generated files, and test inputs whose exact content matters), and the texts are in
[LICENSES/](LICENSES/). Files that come from elsewhere keep their own: PDI's Doxygen XML, images
and site assets under BSD-3-Clause, and the schemas and stylesheet that Doxygen copies into its
XML output under GPL-2.0-or-later (`xml.xsd`: W3C-20150513). Two partials that reuse Docsy's
markup are Apache-2.0, and the PDI home page, adapted from PDI's site, BSD-3-Clause.
