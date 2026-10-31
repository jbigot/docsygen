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

## C. Improve website design

1. [ ] see if we can have a nice selector for language instead of examples in multiple language one after the other
2. [ ] see about the brooken link in the about page
3. [ ] remove the "Guide" page and pick its content directly
4. [ ] frame the live examples of the docsygen page (`/docs/docsygen/`), so that what a shortcode
   renders stands apart from the prose around it
