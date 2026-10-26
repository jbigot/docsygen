"""Check that a Docsy site shows all the information of Doxygen's HTML for the same XML.

Usage: python3 -I info.py --doxygen HTMLDIR --compat C.json --site PUBLIC --paths D.json
                          --gaps GAPS.yaml --rules RULES.yaml [--oracle NAME]
  HTMLDIR    Doxygen's html/ directory
  C.json     the compat site's paths.json, {pages: {key: {url, roles}}, targets, anchors}, whose
             keys are Doxygen's file stems
  PUBLIC     the built Docsy site, and D.json its paths.json, of the same shape
  GAPS.yaml  xml-gaps.yaml, applied to the Doxygen side as exact.py applies it
  RULES.yaml the intentional differences, [{rule: drop|tokens|unwrap, select, phrase?, count,
             reason, oracle?}],
             on the Doxygen side: drop removes the nodes that select (exact.py's selectors)
             matches, those whose text matches the regex phrase if given; tokens matches the text
             of those nodes word by word; unwrap keeps their children only. count is the exact number of matches, as for the gaps.
Pairing: a Doxygen page and a Docsy page that hold the same role (role and id or name; filter
and letter are ignored) are compared together, as are all the pages connected that way. The
Doxygen side is div.header and div.contents, the Docsy side main .td-content (main without it).
In both, a member is its own container: the memitem with anchor A, documenting id I in the
compat targets, pairs with the Docsy element [data-doxygen-id=I]; the rest of the pages pair
with each other. Each container checks, as multisets:
  1. text: each run of inline text between block boundaries (code left out) is found as a
     substring of the Docsy text, on word boundaries, and that occurrence is consumed;
  2. links: an internal link maps to its page's roles, the id it targets (the targets of C.json
     or D.json), or its page's roles and anchor key (anchors) or fragment: see accepts();
  3. code: the text of each div.fragment (its lines joined with newlines) and each pre equals the
     text of a Docsy pre, trailing blanks of each line left out.
Formulas compare as their TeX (formulas()). What is missing makes the exit status 1; the text left over on the Docsy side is reported only.
"""
import argparse, collections, json, os, re, sys
# python3 -I keeps this script's directory off sys.path.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import exact, listyaml

SPLIT = exact.BLOCK | {'caption', 'pre', 'blockquote', 'hr', 'br', 'section', 'article', 'nav', 'header',
                       'footer', 'main', 'details', 'summary', 'figure', 'figcaption', 'img'}
Result = collections.namedtuple('Result', 'missing extra errors report')


def identity(role):
    return (role.get('role'), role.get('id') or role.get('name') or '')


def is_code(node):
    """Whether node is a code block: a div.fragment or a pre, but a member's signature (Docsy's
    pre.docsygen-signature), which is the text of Doxygen's prototype."""
    if node.tag == 'pre':
        return 'docsygen-signature' not in exact.classes(node)
    return node.tag == 'div' and 'fragment' in exact.classes(node)


def code_text(node):
    def raw(n):
        return ''.join(c if isinstance(c, str) else raw(c) for c in n.children)
    if node.tag == 'pre':
        text = raw(node)
    else:
        text = '\n'.join(raw(line) for line in exact.find(node, 'div.line'))
    text = text[:-1] if text.endswith('\n') else text
    # Doxygen writes a blank on an empty line (htmlgen.cpp, endCodeLine).
    return '\n'.join(line.rstrip() for line in text.split('\n'))


def units(node, tokens=False):
    """The runs of inline text under node, between block boundaries, code left out, as
    [(text, tokens)]: tokens when the run is under a node marked by a tokens rule."""
    out, run = [], []

    def flush(tok):
        text = exact.SPACE.sub(' ', ''.join(run)).strip()
        if text:
            out.extend([(t, True) for t in text.split()] if tok else [(text, False)])
        run.clear()

    def walk(n, tok):
        for c in n.children:
            if isinstance(c, str):
                run.append(c)
            elif is_code(c):
                flush(tok)
            elif c.tag in SPLIT:
                flush(tok)
                walk(c, tok or 'data-info-tokens' in c.attrs)
                flush(tok or 'data-info-tokens' in c.attrs)
            else:
                walk(c, tok or 'data-info-tokens' in c.attrs)
    walk(node, tokens or 'data-info-tokens' in node.attrs)
    flush(tokens or 'data-info-tokens' in node.attrs)
    return out


class Side:
    """One side of a comparison: its paths.json, and how its links map to targets."""

    def __init__(self, paths, doxygen):
        self.pages, self.doxygen = paths['pages'], doxygen
        self.by_url = {p['url']: k for k, p in self.pages.items()}
        self.ids = {(t['page'], t.get('anchor', '')): i for i, t in (paths.get('targets') or {}).items()}
        self.keys = {page: {a: k for k, a in m.items()} for page, m in (paths.get('anchors') or {}).items()}

    def roles(self, key):
        return [identity(r) for r in self.pages.get(key, {}).get('roles', [])]

    def page_of(self, path, key):
        """The page key of a link's path from page key, or None for a file."""
        if not path:
            return key
        if self.doxygen:
            base = path.rsplit('/', 1)[-1]
            return base[:-5] if base.endswith('.html') else None
        for candidate in (path, path + '/', path.removesuffix('index.html')):
            if candidate in self.by_url:
                return self.by_url[candidate]
        return None

    def target(self, href, key):
        """('page', roles) for a page, ('id', I), ('anchor', roles, anchorKey) for a fixed anchor,
        ('fragment', roles, fragment) for another one, ('file', name), ('external', href) or
        ('unknown', page, fragment) for a page that paths.json doesn't have."""
        if exact.EXTERNAL.match(href):
            return ('external', href)
        path, _, fragment = href.partition('#')
        page = self.page_of(path, key)
        if page is None:
            return ('file', path.rsplit('/', 1)[-1])
        if page not in self.pages:
            return ('unknown', page, fragment)
        roles = tuple(self.roles(page))
        if not fragment:
            return ('page', roles)
        if (page, fragment) in self.ids:
            return ('id', self.ids[(page, fragment)])
        if fragment in self.keys.get(page, {}):
            return ('anchor', roles, self.keys[page][fragment])
        return ('fragment', roles, fragment)


def accepts(theirs, ours):
    """Whether a Docsy link target satisfies a Doxygen one. A link to a page, an anchor or another
    fragment reaches a Docsy page that holds the first role of the Doxygen page: a page link
    anywhere on it, the others at the same anchor key or fragment."""
    paged = ('page', 'anchor', 'fragment')
    if theirs[0] in paged and ours[0] in paged:
        if not theirs[1] or theirs[1][0] not in ours[1]:
            return False
        return theirs[0] == 'page' or (theirs[0] == ours[0] and theirs[2] == ours[2])
    return theirs == ours


class Container:
    def __init__(self):
        self.units, self.links, self.code = [], [], []

    def add(self, node, side, key):
        self.units.extend(units(node))
        for a in exact.find(node, 'a'):
            if 'href' in a.attrs and not a.attrs['href'].startswith('javascript:'):
                self.links.append(side.target(a.attrs['href'], key))
        nodes = [node] + [n for n in exact.find(node, 'pre') + exact.find(node, 'div.fragment')]
        self.code.extend(code_text(n) for n in nodes if is_code(n) and not any(is_code(p) for p in ancestors(n, node)))


def ancestors(node, stop):
    n = node.parent
    while n is not None and n is not stop:
        yield n
        n = n.parent


MATHJAX = re.compile(r'\\\(\s*(.*?)\s*\\\)|\\\[\s*(.*?)\s*\\\]', re.S)


def formulas(root, doxygen):
    """Formulas as their TeX: Doxygen's MathJax delimiters removed, a KaTeX element (span.katex)
    replaced by the text of its annotation."""
    def walk(node):
        for i, c in enumerate(node.children):
            if isinstance(c, str):
                if doxygen:
                    node.children[i] = MATHJAX.sub(lambda m: m.group(1) if m.group(1) is not None else m.group(2), c)
            elif not doxygen and 'katex' in exact.classes(c):
                tex = next((exact.text(a) for a in exact.find(c, 'annotation')), '')
                node.children[i] = tex
            else:
                walk(c)
    walk(root)


def detach(node):
    node.parent.children.remove(node)
    node.parent = None


def doxygen_members(root, key, side):
    """Detach each memitem of a Doxygen page that documents a known id, with its title (when a
    rule left it): {id: [nodes]}. Its anchor is the a[id] before it, the title in between."""
    out = {}
    for item in exact.find(root, 'div.memitem'):
        if item.parent is None:
            continue
        siblings = [c for c in item.parent.children if isinstance(c, exact.Node)]
        i = siblings.index(item)
        nodes = [item]
        j = i - 1
        if j >= 0 and siblings[j].tag == 'h2' and 'memtitle' in exact.classes(siblings[j]):
            nodes.insert(0, siblings[j])
            j -= 1
        anchor = None
        if j >= 0 and siblings[j].tag == 'a':
            anchor = siblings[j].attrs.get('id') or siblings[j].attrs.get('name')
        ident = side.ids.get((key, anchor))
        if ident is None:
            continue
        for n in nodes:
            detach(n)
        out.setdefault(ident, []).extend(nodes)
    return out


def docsy_members(root, ids):
    """Detach each element that documents one of ids: {id: [nodes]}. The others, such as enum
    values, stay in their container."""
    out = {}
    for node in reversed(exact.find(root, '[data-doxygen-id]')):
        if node.attrs['data-doxygen-id'] not in ids:
            continue
        detach(node)
        out.setdefault(node.attrs['data-doxygen-id'], []).append(node)
    return out


def apply_rules(pages, rules, oracle=None):
    errors, report = [], []
    for n, rule in enumerate(rules, 1):
        if rule.get('oracle', oracle) != oracle:
            continue
        found = []
        for key in sorted(pages):
            for node in exact.find(pages[key], rule['select']):
                if 'phrase' in rule and not re.search(rule['phrase'], exact.text(node)):
                    continue
                found.append((key, node))
        name = f'rule {n} ({rule["rule"]} {rule["select"]})'
        report.append(f'{name}: {len(found)} matches, {rule.get("reason", "")}')
        report.extend(f'  {key}: {exact.text(node)[:80]!r}' for key, node in found)
        if not found:
            errors.append(f'{name}: no matches, the rule is stale')
        elif len(found) != rule['count']:
            errors.append(f'{name}: {len(found)} matches, not {rule["count"]}')
        for _, node in found:
            if rule['rule'] == 'drop':
                if node.parent is not None:
                    detach(node)
            elif rule['rule'] == 'tokens':
                node.attrs['data-info-tokens'] = ''
            elif rule['rule'] == 'unwrap':
                if node.parent is not None:
                    siblings = node.parent.children
                    i = siblings.index(node)
                    for c in node.children:
                        if isinstance(c, exact.Node):
                            c.parent = node.parent
                    siblings[i:i + 1] = node.children
            else:
                errors.append(f'{name}: unknown rule {rule["rule"]!r}')
    return errors, report


def check(name, theirs, ours):
    """The missing items of container theirs in container ours, and the text left over."""
    missing = []
    text = ' '.join(t for t, _ in ours.units)
    for unit, _ in sorted(theirs.units, key=lambda u: -len(u[0])):
        pattern = re.escape(unit)
        if re.match(r'\w', unit):
            pattern = r'(?<!\w)' + pattern
        if re.search(r'\w$', unit):
            pattern += r'(?!\w)'
        m = re.search(pattern, text)
        if m:
            text = text[:m.start()] + '\x00' + text[m.end():]
        else:
            missing.append(f'{name}: text {unit[:100]!r}')
    links = list(ours.links)
    for t in theirs.links:
        i = next((i for i, o in enumerate(links) if accepts(t, o)), None)
        if i is None:
            missing.append(f'{name}: link {t}')
        else:
            del links[i]
    code = collections.Counter(ours.code)
    for c in theirs.code:
        if code[c]:
            code[c] -= 1
        else:
            missing.append(f'{name}: code {c[:100]!r}')
    rest = exact.SPACE.sub(' ', text.replace('\x00', ' ')).strip()
    return missing, ([f'{name}: extra text {rest[:200]!r}'] if rest else [])


def compare(doxygen_pages, compat, docsy_pages, site, rules, oracle=None):
    """Compare Doxygen pages {key: tree} (gaps applied) with Docsy pages {key: tree}, through the
    compat and site paths.json; rules apply to the Doxygen side, those of the oracle given if
    they name one. Return a Result."""
    theirs, ours = Side(compat, True), Side(site, False)
    errors, report = apply_rules(doxygen_pages, rules, oracle)
    # Connected components of pages through the roles they share.
    parent = {}

    def find(x):
        while parent.setdefault(x, x) != x:
            x = parent[x]
        return x
    for side, tag, pages in ((theirs, 'd', doxygen_pages), (ours, 's', docsy_pages)):
        for key in pages:
            find((tag, key))
            for r in side.roles(key):
                parent[find((tag, key))] = find(('r',) + r)
    groups = collections.defaultdict(lambda: ([], []))
    for key in doxygen_pages:
        groups[find(('d', key))][0].append(key)
    for key in docsy_pages:
        groups[find(('s', key))][1].append(key)
    missing, extra = [], []
    for dkeys, skeys in sorted(groups.values(), key=lambda g: (sorted(g[0]), sorted(g[1]))):
        label = ','.join(sorted(dkeys)) or '-'
        if not dkeys:
            continue
        if not skeys:
            missing.append(f'{label}: no Docsy page holds its roles')
            continue
        dmembers, drest = {}, Container()
        for key in sorted(dkeys):
            root = doxygen_pages[key]
            formulas(root, True)
            for ident, nodes in doxygen_members(root, key, theirs).items():
                for n in nodes:
                    dmembers.setdefault(ident, Container()).add(n, theirs, key)
            for part in exact.find(root, 'div.header')[:1] + exact.find(root, 'div.contents')[:1]:
                drest.add(part, theirs, key)
        smembers, srest = {}, Container()
        for key in sorted(skeys):
            root = docsy_pages[key]
            main = (exact.find(root, 'main .td-content') or exact.find(root, 'main') or [root])[0]
            formulas(main, False)
            for ident, nodes in docsy_members(main, dmembers).items():
                for n in nodes:
                    smembers.setdefault(ident, Container()).add(n, ours, key)
            srest.add(main, ours, key)
        m, e = check(label, drest, srest)
        missing += m
        extra += e
        for ident in sorted(dmembers):
            if ident not in smembers:
                missing.append(f'{label}: member {ident} has no [data-doxygen-id] element')
                continue
            m, e = check(f'{label} {ident}', dmembers[ident], smembers[ident])
            missing += m
            extra += e
    return Result(missing, extra, errors, report)


def main(argv):
    ap = argparse.ArgumentParser()
    for opt in ('--doxygen', '--compat', '--site', '--paths', '--gaps', '--rules'):
        ap.add_argument(opt, required=True)
    ap.add_argument('--oracle')
    args = ap.parse_args(argv)

    def load(path):
        with open(path) as f:
            return json.load(f)

    def read(path):
        with open(path, encoding='utf-8') as f:
            return exact.parse(f.read())
    compat, site = load(args.compat), load(args.paths)
    keys = sorted(f[:-5] for f in os.listdir(args.doxygen) if f.endswith('.html') and f != 'doxygen_crawl.html')
    doxy = {k: read(os.path.join(args.doxygen, k + '.html')) for k in keys}
    errors, report = exact.apply_gaps(doxy, listyaml.load(args.gaps), args.oracle)
    doxy = {k: v for k, v in doxy.items() if k in compat['pages']}
    docsy = {}
    for key, p in site['pages'].items():
        path = os.path.join(args.site, p['url'].lstrip('/'))
        if p['url'].endswith('/'):
            path = os.path.join(path, 'index.html')
        docsy[key] = read(path)
    result = compare(doxy, compat, docsy, site, listyaml.load(args.rules), args.oracle)
    for line in report + result.report:
        print(line)
    for line in result.extra:
        print('info', line)
    for line in errors + result.errors:
        print('RULE', line)
    for line in result.missing:
        print('missing', line)
    print(f'{len(result.missing)} missing, {len(result.extra)} containers with extra text')
    return 1 if errors or result.errors or result.missing else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
