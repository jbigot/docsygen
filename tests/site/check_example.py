"""Check the example site built with a baseURL that has a path (exampleSite/check-docsy.sh).

Usage: python3 -I check_example.py BASED
  BASED   the example site built with baseURL https://example.org/pdi/, as GitHub Pages serves a
          project site
Checks that every image of the reference exists where its src points.
Exit 1 on any failure.
"""
import os, re, sys


def read(*path):
    with open(os.path.join(*path), encoding='utf-8') as f:
        return f.read()


def main(argv):
    based, = argv
    errors = []
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
