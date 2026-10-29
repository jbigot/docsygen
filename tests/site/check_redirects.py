"""Check that each page of the latest version has a redirect at its numbered path.

Usage: python3 -I check_redirects.py PUBLIC LATEST NUMBERED
  PUBLIC    the built site
  LATEST    the latest version's root URL (/latest/)
  NUMBERED  its numbered root URL (/1.0/)
For each index.html under LATEST, the file at the same path under NUMBERED must be a redirect to
it: a canonical link to the page, a script that keeps the URL's fragment (location.hash), and a
meta refresh. Exit 1 on any failure, or when LATEST has no page.
"""
import os, re, sys


def main(argv):
    public, latest, numbered = argv
    errors, pages = [], 0
    top = os.path.join(public, latest.strip('/'))
    for d, _, files in os.walk(top):
        if 'index.html' not in files:
            continue
        pages += 1
        rel = os.path.relpath(d, top)
        rel = '' if rel == '.' else rel.replace(os.sep, '/') + '/'
        alias = os.path.join(public, numbered.strip('/'), rel, 'index.html')
        if not os.path.exists(alias):
            errors.append(f'{numbered}{rel}: no redirect to {latest}{rel}')
            continue
        with open(alias, encoding='utf-8') as f:
            text = f.read()
        canonical = re.search(r'<link rel="?canonical"? href="?([^" >]+)', text)
        if not canonical or not canonical[1].endswith(latest + rel):
            errors.append(f'{numbered}{rel}: canonical {canonical and canonical[1]!r}, not {latest}{rel}')
        if 'location.hash' not in text:
            errors.append(f'{numbered}{rel}: no script that keeps the fragment')
        if not re.search(r'http-equiv="?refresh"?', text):
            errors.append(f'{numbered}{rel}: no meta refresh')
    for e in errors:
        print(e)
    print(f'check_redirects.py: {pages} pages of {latest}, {len(errors)} errors')
    return 1 if errors or not pages else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
