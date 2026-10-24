"""Compare the trees dumped by layouts/home.html with expat's parse of the same files.

Usage: python3 -I compare.py trees.json NAME=DIR [NAME=DIR ...]
  trees.json  keys are corpus/NAME/<path>, as produced by mounting DIR at assets/corpus/NAME
"""
import json, sys, os
import xml.parsers.expat as E

def ref_tree(path):
    root = []; stack = [root]
    p = E.ParserCreate()   # no namespace processing: qualified names kept as written
    p.buffer_text = True
    def start(name, attrs):
        node = {"#" + k: v for k, v in attrs.items()}; node[name] = []
        stack[-1].append(node); stack.append(node[name])
    def end(name): stack.pop()
    def text(s): stack[-1].append(s)
    p.StartElementHandler, p.EndElementHandler, p.CharacterDataHandler = start, end, text
    with open(path, 'rb') as f: p.ParseFile(f)
    return root

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

trees = json.load(open(sys.argv[1])); mounts = dict(m.split('=', 1) for m in sys.argv[2:])
ok = bad = 0
seen = {top: set() for top in mounts}
for name, tree in sorted(trees.items()):
    top, rest = name.lstrip('/').split('/', 2)[1:]
    seen[top].add(rest)
    ref = norm([n for n in ref_tree(os.path.join(mounts[top], rest)) if isinstance(n, dict)])
    got = norm([n for n in tree if isinstance(n, dict)])
    d = first_diff(got, ref)
    if d: bad += 1; print('DIFF', name, d)
    else: ok += 1
# Every XML file of every corpus must have been parsed: a missing tree means a lost file.
missing = 0
for top, root in sorted(mounts.items()):
    files = {os.path.relpath(os.path.join(d, f), root) for d, _, fs in os.walk(root) for f in fs if f.endswith('.xml')}
    for rest in sorted(files - seen[top]): missing += 1; print('MISSING', f'corpus/{top}/{rest}')
    print(f'{top}: {len(seen[top])} of {len(files)} files parsed')
print(f'{ok} identical, {bad} different, {missing} missing, of {len(trees)}')
sys.exit(1 if bad or missing else 0)
