"""Check the example site in PDI's organization (exampleSite/check-layout.sh).

Usage: python3 -I check_layout.py PUBLIC EXPECTED.json
EXPECTED.json is {"pages": {URL: TITLE}, "links": [[URL, HREF]]}:
  - each page exists, and its <title> is TITLE, before Docsy's " | <site title>";
  - each page's main content links HREF (tests/site/check.py checks that every link resolves).
Exit 1 on any failure.
"""
import json, os, re, sys


def main(argv):
    public, expected = argv
    with open(expected) as f:
        want = json.load(f)
    errors = []
    texts = {}

    def page(url):
        if url not in texts:
            path = os.path.join(public, url.strip('/'), 'index.html')
            texts[url] = open(path, encoding='utf-8').read() if os.path.isfile(path) else None
        return texts[url]

    for url, title in want.get('pages', {}).items():
        text = page(url)
        m = re.search(r'<title>([^<]*?)(?: \| [^<]*)?</title>', text or '')
        if text is None:
            errors.append(f'{url}: no page')
        elif not m or m.group(1) != title:
            errors.append(f'{url}: titled {m.group(1) if m else None!r}, not {title!r}')
    for url, href in want.get('links', []):
        text = page(url)
        main = re.search(r'<main\b.*</main>', text or '', re.S)
        if text is None:
            errors.append(f'{url}: no page')
        elif not main or f'href="{href}"' not in main.group(0):
            errors.append(f'{url}: no link to {href}')
    for e in errors:
        print(e)
    print(f'check_layout.py: {len(want.get("pages", {}))} pages, {len(want.get("links", []))} links, {len(errors)} errors')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
