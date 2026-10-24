"""Compare the trees dumped by layouts/home.html with expat's parse of the same files.

Usage: python3 -I compare.py [--layout document] trees.json NAME=DIR [NAME=DIR ...]
       python3 -I compare.py --cases CASES.json
  trees.json  keys are corpus/NAME/<path>, as produced by mounting DIR at assets/corpus/NAME
  --layout document  the trees are transform.Unmarshal's document layout ({tag, attributes,
              children}), compared as is so that its invariants are checked too
  --cases     check the case tables of Hugo's document layout tests against expat:
              {"ok": [...], "lenient": [...], "errors": [...]}, entries {name, in, want},
              with `in` base64-encoded (it can hold invalid UTF-8)
Attribute values that differ from expat only by unnormalized tabs and newlines are reported as
KNOWN go#20614 and don't fail the run.
"""
import base64, json, re, sys, os
import xml.parsers.expat as E

def ref_tree_bytes(data):
    root = []; stack = [root]
    p = E.ParserCreate()   # no namespace processing: qualified names kept as written
    p.buffer_text = True
    def start(name, attrs):
        node = {"#" + k: v for k, v in attrs.items()}; node[name] = []
        stack[-1].append(node); stack.append(node[name])
    def end(name): stack.pop()
    def text(s): stack[-1].append(s)
    p.StartElementHandler, p.EndElementHandler, p.CharacterDataHandler = start, end, text
    p.Parse(data, True)
    return root

def ref_tree(path):
    with open(path, 'rb') as f: return ref_tree_bytes(f.read())

def norm(x):
    """Merge adjacent strings, drop empty ones; keep top-level elements only."""
    if isinstance(x, list):
        out = []
        for c in x:
            c = norm(c)
            if isinstance(c, str):
                if not c: continue
                if out and isinstance(out[-1], str): out[-1] += c; continue
            out.append(c)
        return out
    if isinstance(x, dict): return {k: norm(v) for k, v in x.items()}
    return x

def document(nodes):
    """Turn expat's tree into the document layout: the single top-level element."""
    def el(node):
        (tag,) = [k for k in node if not k.startswith('#')]
        return {'tag': tag, 'attributes': {k[1:]: v for k, v in node.items() if k.startswith('#')},
                'children': [el(c) if isinstance(c, dict) else c for c in norm(node[tag])]}
    (root,) = [n for n in nodes if isinstance(n, dict)]
    return el(root)

def first_diff(a, b, path='$'):
    if type(a) != type(b): return f'{path}: {type(a).__name__} {a!r:.80} vs {type(b).__name__} {b!r:.80}'
    if isinstance(a, dict):
        if a.keys() != b.keys(): return f'{path}: keys {sorted(a)} vs {sorted(b)}'
        for k in a:
            d = first_diff(a[k], b[k], f'{path}.{k}')
            if d: return d
    elif isinstance(a, list):
        for i, (x, y) in enumerate(zip(a, b)):
            d = first_diff(x, y, f'{path}[{i}]')
            if d: return d
        if len(a) != len(b): return f'{path}: len {len(a)} vs {len(b)}'
    elif a != b: return f'{path}: {a!r:.120} vs {b!r:.120}'
    return None

def known_20614(got, ref, layout, found, path='$', attrs=False):
    """Replace in got each attribute value that differs from ref only by tabs and newlines
    not normalized to spaces (golang/go#20614), and record its path in found."""
    if isinstance(got, list) and isinstance(ref, list):
        for i, (x, y) in enumerate(zip(got, ref)): known_20614(x, y, layout, found, f'{path}[{i}]')
    elif isinstance(got, dict) and isinstance(ref, dict):
        for k in got.keys() & ref.keys():
            x, y = got[k], ref[k]
            if attrs or (layout == 'template' and k.startswith('#')):
                if isinstance(x, str) and x != y and re.sub('[\t\n\r]', ' ', x) == y:
                    got[k] = y; found.append(f'{path}.{k}')
            else:
                known_20614(x, y, layout, found, f'{path}.{k}', layout == 'document' and k == 'attributes')

def check_cases(path):
    """Every ok input must give its want with expat, every lenient and error input must be
    rejected by expat, except the errors that are rejections by design."""
    by_design = {'entity from the internal subset', 'non-UTF-8 encoding'}
    cases = json.load(open(path)); failed = 0
    def parse(case):
        try: return document(ref_tree_bytes(base64.b64decode(case['in'])))
        except E.ExpatError: return None
    for case in cases['ok']:
        got = parse(case)
        d = 'rejected by expat' if got is None else first_diff(case['want'], got)
        if d: failed += 1; print('MISMATCH', case['name'], d)
    for case in cases['lenient']:
        if parse(case) is not None: failed += 1; print('NOT LENIENT', case['name'])
    for case in cases['errors']:
        accepted = parse(case) is not None
        if case['name'] in by_design and not accepted: failed += 1; print('NOT ACCEPTED', case['name'])
        if case['name'] not in by_design and accepted: failed += 1; print('NOT REJECTED', case['name'])
    print(f"{len(cases['ok'])} ok, {len(cases['lenient'])} lenient, {len(cases['errors'])} errors, {failed} failed")
    sys.exit(1 if failed else 0)

args = sys.argv[1:]
if args[0] == '--cases': check_cases(args[1])
layout = 'template'
if args[0] == '--layout': layout = args[1]; args = args[2:]
trees = json.load(open(args[0])); mounts = dict(m.split('=', 1) for m in args[1:])
ok = bad = known = 0
seen = {top: set() for top in mounts}
for name, tree in sorted(trees.items()):
    top, rest = name.lstrip('/').split('/', 2)[1:]
    seen[top].add(rest)
    nodes = ref_tree(os.path.join(mounts[top], rest))
    if layout == 'document': ref, got = document(nodes), tree
    else: ref, got = norm([n for n in nodes if isinstance(n, dict)]), norm([n for n in tree if isinstance(n, dict)])
    found = []; known_20614(got, ref, layout, found)
    if found: known += 1; print('KNOWN go#20614', name, ' '.join(sorted(found)))
    d = first_diff(got, ref)
    if d: bad += 1; print('DIFF', name, d)
    else: ok += 1
# Every XML file of every corpus must have been parsed: a missing tree means a lost file.
missing = 0
for top, root in sorted(mounts.items()):
    files = {os.path.relpath(os.path.join(d, f), root) for d, _, fs in os.walk(root) for f in fs if f.endswith('.xml')}
    for rest in sorted(files - seen[top]): missing += 1; print('MISSING', f'corpus/{top}/{rest}')
    print(f'{top}: {len(seen[top])} of {len(files)} files parsed')
print(f'{ok} identical, {bad} different, {missing} missing, {known} known, of {len(trees)}')
sys.exit(1 if bad or missing else 0)
