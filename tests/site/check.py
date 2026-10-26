"""Check the output of the Docsy-flavor test site.

Usage: python3 -I check.py PUBLIC XMLDIR ROOT_URL [--links PAGE EXPECTED.json]
  PUBLIC    the built site, with the paths.json of its version root
  XMLDIR    the Doxygen XML it was built from
  ROOT_URL  the version root's URL (/ref/)
Checks:
  - every compound with a role (paths.json), and every memberdef and enumvalue id with a target,
    appears exactly once as data-doxygen-id;
  - every internal href resolves to a file, and its fragment to an id in that file, but the
    links the documentation's authors wrote (class docsygen-ulink), left as they are;
  - no id appears twice in a file;
  - no <p> holds a block element;
  - no class but docsygen-*, Docsy's alert classes, and mermaid, outside KaTeX's output
    (.katex*) and the highlighted code of listings (pre.docsygen-listing), on the pages of the
    test site (those without Docsy's .td-content, whose own classes are Docsy's business);
  - no {{<, HAHAHUGOSHORTCODE or ZgotmplZ is left;
  - with --links, the hrefs of PAGE's main element (a path under PUBLIC) are, in order, the list
    of EXPECTED.json.
Docsy's print pages (_print/), which repeat every page of a section, are link targets only.
Exit 1 on any failure.
"""
import collections, glob, json, os, re, sys, urllib.parse
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'oracle'))
import exact

BLOCKS = {'div', 'table', 'ul', 'ol', 'dl', 'pre', 'p', 'blockquote', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'hr'}
LEFTOVERS = ('{{<', 'HAHAHUGOSHORTCODE', 'ZgotmplZ')
ALLOWED = re.compile(r'^(docsygen-.*|alert|alert-.*|h4|mermaid|katex.*)$')


def foreign_classes(node, out):
    """The classes of node and its descendants that ALLOWED rejects, as {class: count}, skipping
    KaTeX's output and the highlighted code of listings."""
    for c in node.children:
        if not isinstance(c, exact.Node):
            continue
        cls = exact.classes(c)
        if any(x.startswith('katex') for x in cls) or (c.tag == 'pre' and 'docsygen-listing' in cls):
            continue
        for x in cls:
            if not ALLOWED.match(x):
                out[x] += 1
        foreign_classes(c, out)


def walk(node):
    for c in node.children:
        if isinstance(c, exact.Node):
            yield c
            yield from walk(c)


def main(argv):
    links = None
    if '--links' in argv:
        i = argv.index('--links')
        links, argv = argv[i + 1:i + 3], argv[:i] + argv[i + 3:]
    public, xmldir, root_url = argv
    with open(os.path.join(public, root_url.strip('/'), 'paths.json') if os.path.exists(
            os.path.join(public, root_url.strip('/'), 'paths.json')) else os.path.join(public, 'paths.json')) as f:
        paths = json.load(f)
    member_ids = set()
    for name in glob.glob(os.path.join(xmldir, '*.xml')):
        with open(name, encoding='utf-8') as f:
            member_ids.update(re.findall(r'<(?:memberdef|enumvalue)\b[^>]*\bid="([^"]+)"', f.read()))
    expected = {r['id'] for p in paths['pages'].values() for r in p['roles'] if r.get('role') == 'compound'}
    expected |= {i for i in paths.get('targets', {}) if i in member_ids}
    errors = []
    marks = collections.Counter()
    ids = {}
    trees = {}
    for path in sorted(glob.glob(os.path.join(public, '**', '*.html'), recursive=True)):
        with open(path, encoding='utf-8') as f:
            text = f.read()
        rel = os.path.relpath(path, public)
        printed = rel.split(os.sep)[0] == '_print'
        for s in LEFTOVERS:
            if s in text:
                errors.append(f'{rel}: {s} left')
        tree = exact.parse(text)
        trees[rel] = tree
        seen = collections.Counter()
        if printed:
            ids[rel] = {n.attrs['id'] for n in walk(tree) if 'id' in n.attrs}
            continue
        for n in walk(tree):
            if 'id' in n.attrs:
                seen[n.attrs['id']] += 1
            if 'data-doxygen-id' in n.attrs:
                marks[n.attrs['data-doxygen-id']] += 1
            if n.tag == 'p':
                inner = next((d.tag for d in walk(n) if d.tag in BLOCKS), None)
                if inner:
                    errors.append(f'{rel}: a <p> holds a <{inner}>')
        ids[rel] = set(seen)
        for main in ([] if exact.find(tree, '.td-content') else exact.find(tree, 'main')):
            foreign = collections.Counter()
            foreign_classes(main, foreign)
            errors += [f'{rel}: class {x!r} appears {k} times' for x, k in sorted(foreign.items())]
        errors += [f'{rel}: id {i!r} appears {k} times' for i, k in sorted(seen.items()) if k > 1]
    for i in sorted(expected):
        if marks[i] != 1:
            errors.append(f'data-doxygen-id {i!r} appears {marks[i]} times')
    for i, k in sorted(marks.items()):
        if k > 1 and i not in expected:
            errors.append(f'data-doxygen-id {i!r} appears {k} times')
    for rel, tree in sorted(trees.items()):
        base = '/' + rel.replace(os.sep, '/')
        for n in walk(tree):
            href = n.attrs.get('href') if n.tag == 'a' else None
            # docsygen-ulink: a link its author wrote, which docsygen leaves as is.
            if not href or exact.EXTERNAL.match(href) or href.startswith('javascript:') or 'docsygen-ulink' in exact.classes(n):
                continue
            url = urllib.parse.urljoin(base, href)
            target, _, fragment = url.partition('#')
            target = urllib.parse.unquote(target).lstrip('/')
            if target.endswith('/') or target == '':
                target += 'index.html'
            if target not in ids:
                errors.append(f'{rel}: {href} leads to no file')
            elif fragment and urllib.parse.unquote(fragment) not in ids[target]:
                errors.append(f'{rel}: {href} leads to no id in {target}')
    if links:
        page, want_file = links
        with open(want_file) as f:
            want = json.load(f)
        got = [n.attrs.get('href') for m in exact.find(trees[page], 'main') for n in walk(m) if n.tag == 'a' and 'href' in n.attrs]
        if got != want:
            errors.append(f'{page}: links {got} instead of {want}')
    for e in errors:
        print(e)
    print(f'check.py: {len(trees)} files, {len(expected)} ids, {len(errors)} errors')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
