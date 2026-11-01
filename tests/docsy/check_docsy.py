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
  - the offline search index holds demo::Widget's description from /docs/latest/ only;
  - the sitemap lists the reference's pages under /docs/latest/ only;
  - the print page of /docs/main/ holds a member's signature, and the print page of /docs/1.0/
    has the notice and one canonical link;
  - llms.txt lists pages of /docs/latest/;
  - in BASED, every image of the reference exists where its src points, and every root-relative
    href or src of a page starts with /sub/ and leads to a file.
Exit 1 on any failure.
"""
import glob, json, os, re, sys


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
    if 'docsygen-notice' not in printed:
        errors.append('the print page of /docs/1.0/ has no notice')
    if len(re.findall(r'rel="?canonical', printed)) != 1:
        errors.append('the print page of /docs/1.0/ has not one canonical link')
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
