"""Check the versions of the example site where they meet Docsy's own pages (exampleSite/check-docsy.sh).

Usage: python3 -I check_example.py PUBLIC BASED
  PUBLIC  the example site built as it is
  BASED   the same site built with baseURL https://example.org/pdi/
Checks:
  - hand-written pages (/, /docs/) have no version menu: Docsy's navbar item is empty, and the
    site's stylesheet hides an empty one;
  - /docs/ lists the version roots in the order of the version menu, titled with their version,
    and so does its sidebar, by their version label;
  - the sitemap lists the reference's pages under /docs/latest/ only;
  - the print page of /docs/1.7/ has the notice, and one canonical link (Docsy's);
  - in BASED, every image of the reference exists where its src points.
Exit 1 on any failure.
"""
import os, re, sys


def read(*path):
    with open(os.path.join(*path), encoding='utf-8') as f:
        return f.read()


def main(argv):
    public, based = argv
    errors = []
    for page in ('index.html', 'docs/index.html'):
        for item in re.findall(r'<li class="nav-item td-navbar__version-menu">(.*?)</li>', read(public, page), re.S):
            if item.strip():
                errors.append(f'{page}: a version menu')
    css = ''.join(read(d, f) for d, _, fs in os.walk(os.path.join(public, 'scss')) for f in fs if f.endswith('.css'))
    if not re.search(r'\.td-navbar__version-menu:not\(:has\(\*\)\)\s*\{\s*display:\s*none', css):
        errors.append("the stylesheet doesn't hide an empty version menu item")
    text = read(public, 'docs/index.html')
    roots = re.findall(r'<h5>\s*<a href="([^"]+)">([^<]*)</a>', text)
    want = [('/docs/main/', 'PDI main'), ('/docs/latest/', 'PDI 1.12'), ('/docs/1.7/', 'PDI 1.7')]
    if roots != want:
        errors.append(f'/docs/ lists {roots}, not {want}')
    nav = text[text.find('td-sidebar-nav'):]
    sidebar = re.findall(r'<a href="(/docs/[^/"]+/)"[^>]*>\s*<span[^>]*>([^<]*)</span>', nav)
    want = [('/docs/main/', 'main'), ('/docs/latest/', 'latest (1.12)'), ('/docs/1.7/', '1.7')]
    if sidebar != want:
        errors.append(f"/docs/'s sidebar lists {sidebar}, not {want}")
    locs = set(re.findall(r'<loc>https://example.org(/docs/[^/<]+/)', read(public, 'sitemap.xml')))
    if locs != {'/docs/latest/'}:
        errors.append(f'the sitemap lists {sorted(locs)} of the reference, not /docs/latest/ only')
    printed = read(public, '_print/docs/1.7/index.html')
    if 'docsygen-notice' not in printed:
        errors.append('the print page of /docs/1.7/ has no notice')
    if len(re.findall(r'rel="?canonical', printed)) != 1:
        errors.append('the print page of /docs/1.7/ has not one canonical link')
    images = 0
    for d, _, files in os.walk(os.path.join(based, 'docs')):
        for f in files:
            if not f.endswith('.html'):
                continue
            for src in re.findall(r'<img src="(/[^"]+)"', read(d, f)):
                images += 1
                if not src.startswith('/pdi/') or not os.path.exists(os.path.join(based, src[len('/pdi/'):])):
                    errors.append(f'with baseURL https://example.org/pdi/, no image at {src}')
    if not images:
        errors.append('with baseURL https://example.org/pdi/, no image in the reference')
    for e in sorted(set(errors)):
        print(f'check_example.py: {e}')
    print(f'check_example.py: {images} images with a base path, {len(set(errors))} errors')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
