"""Check the versions of the example site where they meet Docsy's own pages (exampleSite/check-docsy.sh).

Usage: python3 -I check_example.py PUBLIC BASED
  PUBLIC  the example site built as it is
  BASED   the same site built with baseURL https://example.org/pdi/
Checks:
  - /docs/ lists the version roots in the order of the version menu, titled with their version,
    and so does its sidebar, by their version label;
  - the sitemap lists the reference's pages under /docs/latest/ only;
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
