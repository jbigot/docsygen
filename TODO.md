# TODO

Our next steps, as a tree of objectives. Each level-1 objective (a `##` heading) breaks down into
level-2 objectives (top-level list items), which break down into level-3 objectives (nested list
items), and so on, as deep as needed. An objective is done when all of its sub-objectives are.

## A. Make docsygen more idiomatic Hugo and Docsy

Clean up and simplify docsygen so that it reads and renders like a Hugo/Docsy site, even where
that means diverging from Doxygen's HTML.

1. [ ] Replace docsygen's CSS classes with plain Docsy (and Bootstrap) ones where they can do the job
   1. [ ] Tables (`docsygen-summary`, `-enumvalues`, `-fields`, `-members`): Docsy already styles every
    table in `.td-content` as a striped Bootstrap table (`td-table`), and docsygen's padding and
    borders override it. Keep only the layout that Docsy lacks (the type column, the brief row
    joined to the row above), if any.
   2. [ ] Labels (`docsygen-label`): Bootstrap's `badge` (`text-bg-secondary`).
   3. [ ] Secondary text (`docsygen-definition`, `-direction`, `-members-undocumented`, `-tree-desc`,
    `-diagram-title`, the summary's brief and template rows): Bootstrap's `text-body-secondary`;
    figure captions: `figure-caption`.
   4. [ ] Definition lists (`dl[class^="docsygen-"]`, `docsygen-param-items`): Docsy's own `dl`
    styling in `.td-content`.
   5. [ ] Checklists (`docsygen-checklist`, `-checked`, `-unchecked`): the task-list markup that
    Markdown renders (`<input type="checkbox" disabled>`).
   6. [ ] Listings' line numbers (`docsygen-listing`, `docsygen-line`): Chroma's line numbers, as
    Hugo's `highlight` renders them, if the listings can give up their links.
   7. [ ] Signatures (`docsygen-signature`): a Chroma-highlighted code block, if they can give up
    their links.
2. [ ] Simpllify by relying on `unsafe: true` since docsy requires it

## B. Rework the API of the versioning scheme

How versions combine with placements is provisional: rework it as a whole.

1. [ ] Twins and the walk-up fallback: a page's twin in another version is the page with the same
   key, else the nearest existing parent, which can be a plain section list whose notice still
   says "this page in the latest release"
2. [ ] A release newer than the latest comes after it in the sidebar (section weight), before it in
   the version menu: a call can't know which release is the latest
3. [ ] Keep the pages of non-latest versions out of the sitemap and the search index, hand-written
   claim pages included (only generated pages are excluded today)
4. [ ] Let docsygen make the parent of the versions redirect to `latest/`, as the PDI layout's
   `/docs/` does by hand (`exampleSite/layouts/redirect.html`)
5. [ ] Optional: a copy mode for `latest/`, the latest release generated a second time instead of
   redirected to from its number

## C. Improve website design

The design of the example site's PDI layout (`--config hugo.yaml,pdi-layout.yaml`), the draft of
PDI's website. The whole-tree layout (`content/`) stays only as a test that keeps working: its
pages may change slightly, and the diff of its built site before and after a change to docsygen
that this design requires measures that change's impact.

1. [ ] see if we can have a nice selector for language instead of examples in multiple language one after the other
2. [ ] Organize the site in five top-menu entries, each a Docsy docs section with its own sidebar,
   in place of Documentation, Guide, C API and Plugin API, followed by Community as today; the
   current addresses needn't survive
   1. [ ] "User documentation", per version, whose sidebar lists the pages "Installation", "PDI
    usage", "Core concepts", "First steps with PDI", "PDI Examples", "Specification tree
    Reference", "C API Reference" (what `c-api/latest/` holds today) and "FAQ", in that order
      1. [ ] Replace the page generated from PDI's main page (`/docs/<version>/`, "About") with a
       hand-written landing page: the main page's "C API reference" is plain text in the XML (its
       source links Doxygen's `topics.html`), and the sidebar replaces its lists
      2. [ ] Decide between a hand-written landing page per version and one page placed in every
       version (with B)
   2. [ ] "Plugins", per version, PDI's "List of PDI plugins" page, whose sidebar lists its subpages, one per
    plugin (Decl'HDF5, Decl'NetCDF, MPI, Pycall, JSON, …)
   3. [ ] "Plugin developer documentation", per version, whose sidebar lists "How to create a
    plugin" and "Plugin API reference"
   4. [ ] "Tutorial", a single page, from the latest version
      1. [ ] Later, build it separately from PDI's tutorial repository: from a Docsy-style
       `README.md`, or from a Doxygen-style Markdown file (for `\snippet`) whose XML is
       generated independently of the rest of PDI
   5. [ ] "Docsygen documentation", outside PDI's documentation, a single page for now
3. [ ] frame the live examples of docsygen's documentation, so that what a shortcode renders
   stands apart from the prose around it
4. [ ] `array-datatype.md` claims PDI 1.12 from `latest/`: it breaks when 1.13 is the latest
   release
5. [ ] Check in a browser what the tests can't: the version menu's fallback, an embedded member,
   the claiming page
6. [ ] Diff the whole-tree layout's built site between a baseline commit and the working tree in
   one command, as `tests/reference.sh` does for `tests/site` (extend it, or a sibling script)

## D. Iterate on the layout of the reference

1. [ ] One link per name: all the overloads of a function, a class template and its
   specializations
2. [ ] Cross-version markers

## E. Make silent failures loud

1. [ ] A claiming page that embeds members one by one, or a skeleton that drops member blocks,
   leaves links to the other members dangling, without a warning: compare the anchors that links
   target with the ids the page carries
2. [ ] A member's anchor can equal a heading id of the hand-written page that holds it (a member
   named `summary`)
3. [ ] `duplicate` naming an item outside the placement's selection does nothing, silently
4. [ ] Two identical adapter calls replace each other's pages, silently
5. [ ] A `form="summary"` member embedded twice on a page repeats its row's ids
6. [ ] The adapter's path records outlive a `hugo server` rebuild: an edited call can report a false
   collision until restart
7. [ ] Test what isn't: `duplicate: true`, `linkTitle`, `weight`; `check_redirects.py` on the PDI
   layout
8. [ ] Extend the sample project (C and C++: namespaces, templates, overloads, enums, groups,
   `\page`, inheritance, all description markup), regenerated with each supported Doxygen version

## F. Upstream

1. [ ] Open the Hugo PR for `targetType: document` (`.claude/design/hugo-15485-pr.md`, branch
   `unmarshal-xml-document`) once a maintainer accepts gohugoio/hugo#15485, from your own account
   1. [ ] Trim its unit tests: +535/−25 is large for an AI-assisted external PR
   2. [ ] Word its errors as the other decoders do (`unmarshal failed:`)
2. [ ] Decide whether to file, from your own account (drafts in `.claude/scripts/`):
   1. [ ] Docsy: `sidebar_menu_truncate` set in YAML warns about ~1.8e19 truncated entries
      (`report-docsy-sidebar-truncate.sh`)
   2. [ ] Docsy: let a site leave out the version menu's navbar item (`docsy-version-item/`); then
      drop the CSS that hides the empty item
   3. [ ] Docsy: `favicons.html` doesn't see files mounted into `static/`
   4. [ ] Hugo: `merge` fails on maps of strings (`report-hugo-merge-typed-map.sh`)
   5. [ ] Hugo: `{{ with partial … }}` on a plain partial panics instead of erroring

## G. Repository housekeeping

1. [ ] Sort the remote out before any push: `origin/main` is gone, and the default branch is
   `m1-whole-tree`
2. [ ] Delete the merged branches `m1-whole-tree`, `m2-versions` and `m3-composition`
