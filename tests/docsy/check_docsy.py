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
  - the sitemap lists the reference's pages under /docs/latest/ only;
  - the print page of /docs/main/ holds a member's signature, and the print page of /docs/1.0/
    has the notice and one canonical link;
  - a class page with an inheritance diagram (demo::Button) and a page with a <mermaid> (the
    guide) load Docsy's Mermaid script, which the render-codeblock-mermaid hook asks for, and
    demo::Box's page, with no diagram, does not;
  - llms.txt lists pages of /docs/latest/;
  - in BASED, every image of the reference exists where its src points, and every root-relative
    href or src of a page starts with /sub/ and leads to a file.
Exit 1 on any failure.
"""
import glob, html, json, os, re, sys


def read(*path):
    with open(os.path.join(*path), encoding='utf-8') as f:
        return f.read()


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
    locs = set(re.findall(r'<loc>https://example.org(/(?:docs/(?:main|latest|1\.0|2\.0)|archive/0\.9)/)', read(public, 'sitemap.xml')))
    if locs != {'/docs/latest/'}:
        errors.append(f'the sitemap lists {sorted(locs)} of the reference, not /docs/latest/ only')
    if 'docsygen-signature' not in read(public, '_print/docs/main/index.html'):
        errors.append('the print page of /docs/main/ holds no member signature')
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
    if not os.path.exists(os.path.join(public, 'llms.txt')):
        errors.append('no llms.txt')
    elif '/docs/latest/' not in read(public, 'llms.txt'):
        errors.append('llms.txt lists no page of /docs/latest/')
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
