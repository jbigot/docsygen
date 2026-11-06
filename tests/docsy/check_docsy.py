# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
"""Check how the versions of the Docsy test site meet Docsy's own pages (tests/docsy/check.sh).

Usage: python3 -I check_docsy.py PUBLIC BASED
  PUBLIC  the site built with baseURL https://example.org/
  BASED   the same site built with baseURL https://example.org/sub/, as GitHub Pages serves a
          project site
Checks:
  - hand-written pages (/, /docs/, /docs/guide/, /archive/) have no version menu: Docsy's navbar
    item is empty, and the stylesheet hides an empty one;
  - /docs/ lists the version roots in the order of the version menu, titled with their version,
    and so does its sidebar, by their version label;
  - a class page's brief is its lead and its meta description, and the content does not
    repeat it before its first section (demo::Widget); a brief with Markdown characters
    (demo::Escapes) is its lead as text;
  - a section in a member's documentation (demo::Escapes::sections) is a heading of the page that
    keeps its id, and is in the page's table of contents;
  - the offline search index holds demo::Widget's description from /docs/latest/ only;
  - demo::Widget's members' headings, their declarations, are text in its table of contents,
    with no id, and in the search index, with no markup or escaped character; demo's keep their
    ... and -- there, which goldmark's typographer would rewrite;
  - an overload set (demo::Gadget::set, demo::Widget's constructors) is one entry of the table of
    contents beside the members, "<name> overloads", its overloads below it only (Hugo's default
    endLevel, 3, leaves them out), and their declarations are still text in the search index;
  - the sitemap lists the reference's pages under /docs/latest/ only;
  - the print page of /docs/main/ holds a member's declaration heading and an overload's, and the
    print page of /docs/1.0/ has the notice and one canonical link;
  - a class page with an inheritance diagram (demo::Button) and a page with a <mermaid> (the
    guide) load Docsy's Mermaid script, which the render-codeblock-mermaid hook asks for, and
    demo::Box's page, with no diagram, does not;
  - the example variants of the sample's page variants (five groups) and of demo::grow's
    description are Docsy tabs, headed C and Fortran, whose ids are unique on their page and
    whose tabs control their own panes; a list item's text outside its group stays before the
    tabs; the links to a group and to one variant (page variant-links) land on ids of the page;
    the print page and the search index hold every variant's code; each group is followed by a
    copy of its variants in sequence (div.docsygen-variants-print), with no id, which the
    stylesheet shows only in print, where it hides the tabs;
  - llms.txt lists pages of /docs/latest/, with no markup or escaped character;
  - in BASED, every image of the reference exists where its src points, and every root-relative
    href or src of a page starts with /sub/ and leads to a file.
Exit 1 on any failure.
"""
import collections, glob, html, json, os, re, sys


def read(*path):
    with open(os.path.join(*path), encoding='utf-8') as f:
        return f.read()


def toc_entries(page):
    """The entries of page's table of contents, as [(depth, text)], depth 1 for the outer list."""
    toc = re.search(r'id="TableOfContents">(.*?)</nav>', page, re.S)
    out, depth = [], 0
    for tag, text in re.findall(r'(<ul>|</ul>)|<a href="#[^"]+">(.*?)</a>', toc.group(1) if toc else '', re.S):
        if tag:
            depth += 1 if tag == '<ul>' else -1
        else:
            out.append((depth, html.unescape(re.sub(r'<[^>]*>', '', text))))
    return out


def divs(page, cls):
    """The inner HTML of each <div class="cls"> of page, up to its own closing tag."""
    out = []
    for m in re.finditer(f'<div class="{cls}">', page):
        depth, pos = 1, m.end()
        for t in re.finditer(r'<(/?)div\b', page[pos:]):
            depth += -1 if t.group(1) else 1
            if not depth:
                out.append(page[pos:pos + t.start()])
                break
    return out


def main(argv):
    public, based = argv
    errors = []
    for page in ('index.html', 'docs/index.html', 'docs/guide/index.html', 'archive/index.html'):
        for item in re.findall(r'<li class="nav-item td-navbar__version-menu">(.*?)</li>', read(public, page), re.S):
            if item.strip():
                errors.append(f'{page}: a version menu')
    css = ''.join(read(d, f) for d, _, fs in os.walk(os.path.join(public, 'scss')) for f in fs if f.endswith('.css'))
    if not re.search(r'\.td-navbar__version-menu:not\(:has\(\*\)\)\s*\{\s*display:\s*none', css):
        errors.append("the stylesheet doesn't hide an empty version menu item")
    text = read(public, 'docs/index.html')
    roots = [r for r in re.findall(r'<h5>\s*<a href="([^"]+)">([^<]*)</a>', text) if r[0] != '/docs/guide/']
    want = [('/docs/main/', 'docsygen sample main'), ('/docs/latest/', 'docsygen sample 2.0'),
            ('/docs/1.0/', 'docsygen sample 1.0')]
    if roots != want:
        errors.append(f'/docs/ lists {roots}, not {want}')
    nav = text[text.find('td-sidebar-nav'):]
    sidebar = [r for r in re.findall(r'<a href="(/docs/[^/"]+/)"[^>]*>\s*<span[^>]*>([^<]*)</span>', nav)
               if r[0] != '/docs/guide/']
    want = [('/docs/main/', 'main'), ('/docs/latest/', 'latest (2.0)'), ('/docs/1.0/', '1.0')]
    if sidebar != want:
        errors.append(f"/docs/'s sidebar lists {sidebar}, not {want}")
    widget = read(public, 'docs/latest/api/demo/widget/index.html')
    lead = re.findall(r'<div class="lead">(.*?)</div>', widget, re.S)
    if [re.sub(r'<[^>]*>', '', l).strip() for l in lead] != ['A widget.']:
        errors.append(f"demo::Widget's lead is {lead}, not its brief")
    if 'name="description" content="A widget."' not in widget:
        errors.append("demo::Widget's meta description is not its brief")
    top = widget[widget.find('<div class="lead">'):widget.find('<h2')]
    if top.count('A widget.') != 1:
        errors.append("demo::Widget's brief is not once before its first section")
    escapes = read(public, 'docs/latest/api/demo/escapes/index.html')
    lead = re.findall(r'<div class="lead">(.*?)</div>', escapes, re.S)
    text = html.unescape(re.sub(r'<[^>]*>', '', lead[0])).strip() if lead else None
    if text != 'a*b_c [d] <e> f #g {h}':
        errors.append(f"demo::Escapes's lead is {text!r}, not its brief as text")
    # 1.0 is the sample itself, which has the member (latest is sample-next's).
    escapes = read(public, 'docs/1.0/api/demo/escapes/index.html')
    toc = re.search(r'id="TableOfContents">(.*?)</nav>', escapes, re.S)
    links = re.findall(r'<a href="#([^"]+)">([^<]*)</a>', toc.group(1)) if toc else []
    sections = [(i, t) for i, t in links if t == 'A section of a member']
    if len(sections) != 1:
        errors.append(f"demo::Escapes's table of contents lacks the section of a member: {links}")
    elif f'<h4 id="{sections[0][0]}">A section of a member' not in escapes:
        errors.append("demo::Escapes's section of a member is no heading with the id of its table of contents entry")
    index = glob.glob(os.path.join(public, 'offline-search-index.*.json'))
    refs = sorted({e['ref'] for i in index for e in json.load(open(i)) if 'to build one' in e['body']})
    if not refs or any(not r.startswith('/docs/latest/') for r in refs):
        errors.append(f"the search index has demo::Widget's description from {refs}, not from /docs/latest/ only")
    # Members' headings are their declarations, inline HTML: text in the table of contents and
    # the search index, with no markup left. An overload set's heading names it, its overloads'
    # headings are below the table of contents' depth.
    widget = read(public, 'docs/latest/api/demo/widget/index.html')
    toc = re.search(r'id="TableOfContents">(.*?)</nav>', widget, re.S)
    toc = toc.group(1) if toc else ''
    entries = {i: html.unescape(re.sub(r'<[^>]*>', '', t)) for i, t in re.findall(r'<a href="#([^"]+)">(.*?)</a>', toc, re.S)}
    for want in ('Widget overloads', 'operator<(const Widget &other) const -> bool'):
        if want not in entries.values():
            errors.append(f"demo::Widget's table of contents has no entry {want!r}: {sorted(entries.values())}")
    toc_widget = toc_entries(widget)
    sets = [d for d, t in toc_widget if t == 'Widget overloads']
    if any(t.startswith('Widget(') and d <= sets[0] for d, t in toc_widget if sets):
        errors.append(f"demo::Widget's table of contents lists its constructors beside their set: {toc_widget}")
    if re.search(r'\sid=', toc):
        errors.append("demo::Widget's table of contents repeats an id of its headings")
    bodies = [e['body'] for i in index for e in json.load(open(i)) if e['ref'] == '/docs/latest/api/demo/widget/']
    for want in ('Widget()', 'Widget(int side)', 'Widget(const Widget &)', 'operator<(const Widget &other) const -> bool'):
        if not bodies or want not in bodies[0]:
            errors.append(f"the search index of demo::Widget lacks the declaration {want!r}")
    if bodies and re.search(r'&lt;|&amp;|<code|<span|<strong', bodies[0]):
        errors.append("the search index of demo::Widget holds markup or escaped characters")
    # The set is one entry beside the members, its overloads only below it, as the site's
    # endLevel (here 5) lists level 4 headings; Hugo's default (3) leaves them out.
    entries = toc_entries(read(public, 'docs/latest/api/demo/gadget/index.html'))
    sets = [d for d, t in entries if t == 'set overloads']
    members = [d for d, t in entries if t == 'update() -> void']
    if len(sets) != 1 or members != sets:
        errors.append(f"demo::Gadget's table of contents has not one entry 'set overloads' beside its members: {entries}")
    bodies = [e['body'] for i in index for e in json.load(open(i)) if e['ref'] == '/docs/latest/api/demo/gadget/']
    for want in ('set(int value) -> void', 'set(double value) -> void'):
        if any(t == want and (not sets or d <= sets[0]) for d, t in entries):
            errors.append(f"demo::Gadget's table of contents lists the overload {want!r} beside its set")
        if not bodies or want not in bodies[0]:
            errors.append(f"the search index of demo::Gadget lacks the declaration {want!r}")
    # ... and -- survive goldmark's typographer, which would make them an ellipsis and a dash.
    demo = read(public, 'docs/latest/api/demo/index.html')
    toc = re.search(r'id="TableOfContents">(.*?)</nav>', demo, re.S)
    entries = {html.unescape(re.sub(r'<[^>]*>', '', t)) for t in re.findall(r'<a href="#[^"]+">(.*?)</a>', toc.group(1) if toc else '', re.S)}
    bodies = [e['body'] for i in index for e in json.load(open(i)) if e['ref'] == '/docs/latest/api/demo/']
    for want in ('count_args<typename... Args>(Args... args) -> int', 'operator--(Widget &w) -> Widget &'):
        if want not in entries:
            errors.append(f"demo's table of contents has no entry {want!r}")
        if not bodies or want not in bodies[0]:
            errors.append(f"the search index of demo lacks the declaration {want!r}")
    locs = set(re.findall(r'<loc>https://example.org(/(?:docs/(?:main|latest|1\.0|2\.0)|archive/0\.9)/)', read(public, 'sitemap.xml')))
    if locs != {'/docs/latest/'}:
        errors.append(f'the sitemap lists {sorted(locs)} of the reference, not /docs/latest/ only')
    if not re.search(r'<h3 [^>]*><code class="docsygen-declaration', read(public, '_print/docs/main/index.html')):
        errors.append("the print page of /docs/main/ holds no member's declaration heading")
    if not re.search(r'<h4 [^>]*><code class="docsygen-declaration[^"]*"><strong>set</strong>', read(public, '_print/docs/main/index.html')):
        errors.append("the print page of /docs/main/ holds no overload's declaration heading")
    printed = read(public, '_print/docs/1.0/index.html')
    # Docsy's print heading doesn't call version-banner.html: no notice, until Docsy does.
    if 'docsygen-notice' in printed:
        errors.append('the print page of /docs/1.0/ has a notice')
    if '<h1 class="title">' not in printed:
        errors.append("the print page of /docs/1.0/ has no Docsy print heading")
    if len(re.findall(r'rel="?canonical', printed)) != 1:
        errors.append('the print page of /docs/1.0/ has not one canonical link')
    button = read(public, 'docs/latest/api/demo/button/index.html')
    if 'data-docsy-plugin="mermaid"' not in button or '<pre class="mermaid">' not in button:
        errors.append("demo::Button's page, with an inheritance diagram, doesn't load Mermaid")
    if 'data-docsy-plugin="mermaid"' in read(public, 'docs/latest/api/demo/box/index.html'):
        errors.append("demo::Box's page, with no diagram, loads Mermaid")
    if 'data-docsy-plugin="mermaid"' not in read(public, 'docs/main/pages/guide/index.html'):
        errors.append("the guide page, with a <mermaid>, doesn't load Mermaid")
    # Example variants: one tab per language, each tab controlling its own pane, the groups' ids
    # unique on the page (Docsy's ids collide through RenderString, docsy/docsy#2308).
    codes = ('demo_make_widget();', 'w = make_widget()', 'demo_resize(w, 5, 6);', 'call w%resize(5, 6)',
             'demo_unused(w);', 'call unused(w)', 'w-&gt;resize(3, 4);', 'end program main')
    for page, groups in (('docs/latest/pages/variants/index.html', 5), ('docs/latest/api/demo/index.html', 1)):
        text = read(public, page)
        lists = re.findall(r'<ul class="nav nav-tabs[^"]*" id="([^"]+)" role="tablist">(.*?)</ul>', text, re.S)
        headers = [[h.strip() for h in re.findall(r'<button[^>]*>(.*?)</button>', l, re.S)] for _, l in lists]
        if headers != [['C', 'Fortran']] * groups:
            errors.append(f'{page}: the variants are not {groups} groups of tabs C and Fortran: {headers}')
        ids = collections.Counter(re.findall(r'\sid="([^"]*)"', text))
        if any(k > 1 for k in ids.values()):
            errors.append(f'{page}: repeated ids {sorted(i for i, k in ids.items() if k > 1)}')
        for _, l in lists:
            for target, controls in re.findall(r'data-bs-target="#([^"]+)"[^>]*?aria-controls="([^"]+)"', l, re.S):
                if target != controls or f'id="{target}" role="tabpanel"' not in text:
                    errors.append(f'{page}: a tab controls {target!r}, {controls!r}, not a pane of the page')
    variants = read(public, 'docs/latest/pages/variants/index.html')
    copies = divs(variants, 'docsygen-variants-print')
    if len(copies) != 5:
        errors.append(f'the variants page has {len(copies)} copies of its groups for print, not 5')
    for c in copies:
        if re.search(r'\sid=', c) or 'nav-tabs' in c:
            errors.append('a copy of a group for print has an id or tabs')
    printed_copies = re.sub(r'<[^>]*>', '', ''.join(copies))
    for code in codes:
        if code not in printed_copies:
            errors.append(f"the variants page's copies for print lack the variant code {code!r}")
    if not re.search(r'\.docsygen-variants-print\s*\{\s*display:\s*none', css) or not re.search(
            r'@media print\s*\{\s*\.docsygen-variants\s*\{\s*display:\s*none;?\s*\}\s*\.docsygen-variants-print\s*\{\s*display:\s*block', css):
        errors.append("the stylesheet doesn't show the copies of the variants instead of the tabs in print only")
    if not re.search(r'<li>Step two, in two languages\.\s*<div class="docsygen-variants"><a id="sample_item"></a><ul class="nav nav-tabs', variants):
        errors.append("the variants page's list item lacks its text before its tabs")
    for href in re.findall(r'href="([^"]*sample_ex[^"]*)"', read(public, 'docs/latest/pages/variant-links/index.html')) or ['none']:
        path, _, frag = href.partition('#')
        if path != '/docs/latest/pages/variants/' or f'id="{frag}"' not in variants:
            errors.append(f'the variant-links page links to {href}, not to an id of the variants page')
    printed = re.sub(r'<[^>]*>', '', read(public, '_print/docs/latest/index.html'))
    plain = [e['body'] for i in index for e in json.load(open(i)) if e['ref'] == '/docs/latest/pages/variants/']
    for code in codes:
        if code not in printed:
            errors.append(f'the print page of /docs/latest/ lacks the variant code {code!r}')
        if not plain or html.unescape(code) not in plain[0]:
            errors.append(f'the search index of the variants page lacks the variant code {code!r}')
    if not os.path.exists(os.path.join(public, 'llms.txt')):
        errors.append('no llms.txt')
    elif '/docs/latest/' not in read(public, 'llms.txt'):
        errors.append('llms.txt lists no page of /docs/latest/')
    elif re.search(r'&lt;|<code|<span|<strong', read(public, 'llms.txt')):
        errors.append('llms.txt holds markup or escaped characters')
    images = 0
    for d, _, files in os.walk(based):
        for f in files:
            if not f.endswith('.html'):
                continue
            rel = os.path.relpath(os.path.join(d, f), based)
            for attr, url in re.findall(r'\s(href|src)="(/[^"#?]*)', read(d, f)):
                if url.startswith('//'):
                    continue
                if attr == 'src' and rel.startswith(('docs/', 'archive/')) and url.endswith('.png'):
                    images += 1
                target = os.path.join(based, url[len('/sub/'):])
                if url.endswith('/'):
                    target = os.path.join(target, 'index.html')
                if not url.startswith('/sub/') or not os.path.exists(target):
                    errors.append(f'with baseURL https://example.org/sub/, {rel} has {attr} {url}, which leads to no file')
    if not images:
        errors.append('with baseURL https://example.org/sub/, no image in the reference')
    for e in sorted(set(errors)):
        print(f'check_docsy.py: {e}')
    print(f'check_docsy.py: {images} images with a base path, {len(set(errors))} errors')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
