"""Compare a site's pages with Doxygen's HTML for the same XML, as exactly as possible.

Usage: python3 -I exact.py --doxygen HTMLDIR --site PUBLIC --paths PATHS.json --gaps GAPS.yaml
                           [--oracle NAME] [--scope SCOPE ...]
  HTMLDIR    Doxygen's html/ directory
  PUBLIC     the built site; PATHS.json is its dump, {pages: {key: {url, roles}}, ...}
  GAPS.yaml  what Doxygen's HTML shows and the XML cannot give, removed from the Doxygen side:
             [{pages: GLOB, select: SELECTOR, text?: REGEX, attr?: NAME, unwrap?: true,
               empty?: true, replace?: REGEX, with?: STRING, count: N, reason, evidence,
               oracle?: NAME}]. attr removes that attribute only, unwrap the element but not
             its children, empty its children only, and replace substitutes with for the
             matches of replace in the element's own text, not in its descendants', and
             selects only an element that has one. count is the exact number of matches over
             all pages: any other number fails, and so does an entry without matches (stale). An
             entry with an oracle applies only when --oracle names it. A SELECTOR is TAG,
             TAG.CLASS, TAG#ID, .CLASS or #ID, each optionally followed by [ATTR], [ATTR=VALUE]
             or [ATTR^=PREFIX] and by :contains(TEXT) (jQuery's), or those alone; a space selects
             descendants and ~ later siblings, as in CSS.
Doxygen's X.html pairs with the site page whose key is X. The div.header and div.contents of
both are compared after these normalizations, and no others:
  1. whitespace runs become one space, and whitespace next to a block element's tags is
     removed, except in pre and div.fragment;
  2. character references are decoded, attribute order is ignored, void elements compare
     without /, and comments are removed;
  3. an href or src to a page compares as (page key, fragment), to another local file as its
     basename, and an external one as is; on the site, a relative X.html is the page of key X;
  4. the coords of an area are ignored;
  5. the nodes of GAPS.yaml are removed from the Doxygen side.
Scopes: pages (the sets of keys are equal), header, textblock (each div.textblock, by page and
position), memberdecls (each table.memberdecls, by the anchor of its heading), memitem (each
h2.memtitle with its div.memitem, by anchor), contents, and contents:GLOB (contents, for the
pages whose key matches GLOB, but those matching any !GLOB after it; a glob that matches nothing
is reported). Exit 1 on any
difference.
"""
import argparse, fnmatch, html.parser, json, os, re, sys
# python3 -I keeps this script's directory off sys.path.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import listyaml

VOID = {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param',
        'source', 'track', 'wbr'}
BLOCK = {'div', 'p', 'table', 'tr', 'td', 'th', 'ul', 'ol', 'li', 'dl', 'dt', 'dd',
         'h1', 'h2', 'h3', 'h4', 'h5', 'h6', '#document'}
SPACE = re.compile('[ \t\n\r\f]+')
EXTERNAL = re.compile(r'^(?:[A-Za-z][A-Za-z0-9+.-]*:|//)')


class Node:
    def __init__(self, tag, attrs, parent=None):
        self.tag, self.attrs, self.children, self.parent = tag, attrs, [], parent

    def __repr__(self):
        return f'<{self.tag} {self.attrs}>'


class _Builder(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node('#document', {})
        self.stack = [self.root]

    def _append(self, node):
        node.parent = self.stack[-1]
        self.stack[-1].children.append(node)

    def handle_starttag(self, tag, attrs):
        node = Node(tag, {k: v or '' for k, v in attrs})
        self._append(node)
        if tag not in VOID:
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        self._append(Node(tag, {k: v or '' for k, v in attrs}))

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i].tag == tag:
                del self.stack[i:]
                return

    def handle_data(self, data):
        siblings = self.stack[-1].children
        if siblings and isinstance(siblings[-1], str):
            siblings[-1] += data
        else:
            siblings.append(data)


def parse(text):
    """The document tree of an HTML string; comments, declarations and PIs are dropped."""
    builder = _Builder()
    builder.feed(text)
    builder.close()
    return builder.root


def classes(node):
    return node.attrs.get('class', '').split()


def _simple(node, selector):
    """Whether node matches TAG, TAG.CLASS[.CLASS…], TAG#ID, .CLASS or #ID, each optionally
    followed by [ATTR], [ATTR=VALUE] or [ATTR^=PREFIX] and by :contains(TEXT), or those alone."""
    m = re.fullmatch(r'([a-z0-9]*)((?:\.[^.#\[:]+)*)(?:#([^\[:]+))?(?:\[([a-z-]+)(?:(\^?=)([^\]]*))?\])?'
                     r'(?::contains\((.*)\))?', selector)
    if not m or not selector:
        raise ValueError(f'unsupported selector {selector!r}')
    tag, cls, ident, attr, op, value, contained = m.groups()
    if attr is not None:
        actual = node.attrs.get(attr)
        if actual is None or (op is not None and not (actual.startswith(value) if op == '^=' else actual == value)):
            return False
    if contained is not None and contained not in text(node):
        return False
    return ((not tag or node.tag == tag) and all(c in classes(node) for c in cls.split('.')[1:])
            and (ident is None or node.attrs.get('id') == ident))


def _steps(selector):
    """selector as [(combinator, simple selector)], the first combinator None: ' ' or '~',
    outside brackets and parentheses."""
    steps, simple, combinator, depth = [], '', None, 0
    for c in selector.strip() + ' ':
        if c in '[(':
            depth += 1
        elif c in '])':
            depth -= 1
        if depth or c not in ' ~':
            simple += c
            continue
        if simple:
            steps.append((combinator, simple))
            simple, combinator = '', ' '
        if c == '~':
            combinator = '~'
    return steps or [(None, '')]


def _matches(node, steps):
    combinator, simple = steps[-1]
    if not _simple(node, simple):
        return False
    if len(steps) == 1:
        return True
    if combinator == '~':
        siblings = [c for c in node.parent.children if isinstance(c, Node)] if node.parent else []
        return any(_matches(s, steps[:-1]) for s in siblings[:siblings.index(node)])
    n = node.parent
    while n is not None:
        if _matches(n, steps[:-1]):
            return True
        n = n.parent
    return False


def matches(node, selector):
    """Whether node matches selector: simple selectors (see _simple) separated by a space, for
    a descendant, or by ~, for a later sibling, as in CSS."""
    return _matches(node, _steps(selector))


def find(node, selector):
    """Every descendant of node that matches selector, in document order."""
    out = []
    for c in node.children:
        if isinstance(c, Node):
            if matches(c, selector):
                out.append(c)
            out.extend(find(c, selector))
    return out


def text(node):
    """The text content of node, with whitespace runs collapsed."""
    def walk(n):
        return ''.join(c if isinstance(c, str) else walk(c) for c in n.children)
    return SPACE.sub(' ', walk(node)).strip()


def doxygen_links(key):
    """Map href and src values of the Doxygen page key, whose links are relative file names."""
    def link(value):
        if EXTERNAL.match(value):
            return value
        path, hash_, fragment = value.partition('#')
        base = path.rsplit('/', 1)[-1]
        if not path:
            return f'page:{key}#{fragment}'
        if base.endswith('.html'):
            return f'page:{base[:-5]}{hash_}{fragment}'
        return f'file:{base}'
    return link


def site_links(urls, key):
    """Map href and src values of the site page key, whose links are site paths; urls maps
    each page's URL to its key."""
    def link(value):
        if EXTERNAL.match(value):
            return value
        path, hash_, fragment = value.partition('#')
        if not path:
            return f'page:{key}#{fragment}'
        for candidate in (path, path + '/', path.removesuffix('index.html')):
            if candidate in urls:
                return f'page:{urls[candidate]}{hash_}{fragment}'
        base = path.rsplit('/', 1)[-1]
        if not path.startswith('/') and base.endswith('.html'):
            return f'page:{base[:-5]}{hash_}{fragment}'
        return f'file:{base}'
    return link


def normalize(node, link, keep=False):
    """node as a comparable value: (tag, attributes, children) for an element, a string for
    text, with the normalizations of the module docstring applied."""
    keep = keep or node.tag == 'pre' or (node.tag == 'div' and 'fragment' in classes(node))
    merged = []
    for c in node.children:
        if isinstance(c, str) and merged and isinstance(merged[-1], str):
            merged[-1] += c
        else:
            merged.append(c)
    out = []
    for i, c in enumerate(merged):
        if isinstance(c, Node):
            out.append(normalize(c, link, keep))
            continue
        if not keep:
            prev = merged[i - 1] if i > 0 else None
            next_ = merged[i + 1] if i + 1 < len(merged) else None
            c = SPACE.sub(' ', c)
            if (prev.tag in BLOCK) if isinstance(prev, Node) else node.tag in BLOCK:
                c = c.lstrip(' ')
            if (next_.tag in BLOCK) if isinstance(next_, Node) else node.tag in BLOCK:
                c = c.rstrip(' ')
        if c:
            out.append(c)
    attrs = []
    for k, v in node.attrs.items():
        if node.tag == 'area' and k == 'coords':
            continue
        attrs.append((k, link(v) if k in ('href', 'src') else v))
    return (node.tag, tuple(sorted(attrs)), tuple(out))


def _label(x, i):
    return f'text[{i}]' if isinstance(x, str) else f'{x[0]}[{i}]'


def _show(x):
    if isinstance(x, str):
        return repr(x[:80])
    return f'<{x[0]}{"".join(f" {k}={v!r}" for k, v in x[1])}>'


def first_diff(a, b, path=''):
    """The path to the first difference between two normalized nodes, or None."""
    if isinstance(a, str) or isinstance(b, str) or a[0] != b[0]:
        return None if a == b else f'{path or "/"}: {_show(a)} vs {_show(b)}'
    if a[1] != b[1]:
        return f'{path or "/"}: attributes {dict(a[1])} vs {dict(b[1])}'
    for i, (x, y) in enumerate(zip(a[2], b[2])):
        d = first_diff(x, y, f'{path}/{_label(x, i)}')
        if d:
            return d
    if len(a[2]) != len(b[2]):
        longer, n = (a[2], 'missing on the site') if len(a[2]) > len(b[2]) else (b[2], 'extra on the site')
        i = min(len(a[2]), len(b[2]))
        return f'{path or "/"}: {_show(longer[i])} {n}'
    return None


def apply_gaps(pages, gaps, oracle=None):
    """Remove the nodes of each gap from the Doxygen pages (key → tree). Return the errors
    and the report, which lists each gap's matches."""
    errors, report = [], []
    for n, gap in enumerate(gaps, 1):
        if gap.get('oracle', oracle) != oracle:
            continue
        found = []
        for key in sorted(pages):
            if not fnmatch.fnmatchcase(key, gap['pages']):
                continue
            for node in find(pages[key], gap['select']):
                if 'text' in gap and not re.search(gap['text'], text(node)):
                    continue
                if 'attr' in gap and gap['attr'] not in node.attrs:
                    continue
                if 'replace' in gap and not any(isinstance(c, str) and re.search(gap['replace'], c) for c in node.children):
                    continue
                found.append((key, node))
        name = f'gap {n} ({gap["pages"]} {gap["select"]})'
        report.append(f'{name}: {len(found)} matches, {gap.get("reason", "")}')
        report.extend(f'  {key}: {text(node)[:80]!r}' for key, node in found)
        if not found:
            errors.append(f'{name}: no matches, the entry is stale')
        elif len(found) != gap['count']:
            errors.append(f'{name}: {len(found)} matches, not {gap["count"]}')
        for _, node in found:
            if 'attr' in gap:
                del node.attrs[gap['attr']]
            elif 'replace' in gap:
                node.children = [re.sub(gap['replace'], gap['with'], c) if isinstance(c, str) else c
                                 for c in node.children]
            elif gap.get('empty'):
                node.children = []
            elif gap.get('unwrap'):
                siblings = node.parent.children
                i = siblings.index(node)
                for c in node.children:
                    if isinstance(c, Node):
                        c.parent = node.parent
                siblings[i:i + 1] = node.children
            else:
                # A removed line takes its newline: Doxygen ends lines, tooltips and blocks with one.
                siblings = node.parent.children
                i = siblings.index(node)
                if i + 1 < len(siblings) and isinstance(siblings[i + 1], str) and siblings[i + 1].startswith('\n'):
                    siblings[i + 1] = siblings[i + 1][1:]
                del siblings[i]
    return errors, report


def _anchor(a):
    return a.attrs.get('id') or a.attrs.get('name')


def fragments(root, scope):
    """The fragments of a page for a scope, as {name: [nodes]}."""
    if scope in ('header', 'contents') or scope.startswith('contents:'):
        found = find(root, 'div.' + scope.split(':')[0])
        return {scope.split(':')[0]: found[:1]} if found else {}
    if scope == 'textblock':
        return {f'textblock[{i}]': [n] for i, n in enumerate(find(root, 'div.textblock'))}
    if scope == 'memberdecls':
        out = {}
        for i, table in enumerate(find(root, 'table.memberdecls')):
            anchors = [_anchor(a) for a in find(table, 'a') if _anchor(a)]
            out[f'memberdecls#{anchors[0]}' if anchors else f'memberdecls[{i}]'] = [table]
        return out
    if scope == 'memitem':
        out = {}
        for title in find(root, 'h2.memtitle'):
            siblings = [c for c in title.parent.children if isinstance(c, Node)]
            i = siblings.index(title)
            anchor = next((_anchor(s) for s in reversed(siblings[:i]) if s.tag == 'a' and _anchor(s)), None)
            nodes = [title] + [s for s in siblings[i + 1:i + 2] if 'memitem' in classes(s)]
            out[f'memitem#{anchor}'] = nodes
        return out
    raise ValueError(f'unknown scope {scope!r}')


def main(argv):
    ap = argparse.ArgumentParser()
    for opt in ('--doxygen', '--site', '--paths', '--gaps'):
        ap.add_argument(opt, required=True)
    ap.add_argument('--oracle')
    ap.add_argument('--scope', action='append', default=[])
    args = ap.parse_args(argv)

    with open(args.paths) as f:
        site_pages = json.load(f)['pages']
    urls = {p['url']: key for key, p in site_pages.items()}
    keys = sorted(f[:-5] for f in os.listdir(args.doxygen)
                  if f.endswith('.html') and f != 'doxygen_crawl.html')

    def read(path):
        with open(path, encoding='utf-8') as f:
            return parse(f.read())

    doxy = {k: read(os.path.join(args.doxygen, k + '.html')) for k in keys}
    errors, report = apply_gaps(doxy, listyaml.load(args.gaps), args.oracle)
    for line in report:
        print(line)
    for e in errors:
        print('GAP', e)

    different = len(errors)
    for scope in args.scope:
        compared = failed = 0
        if scope == 'pages':
            for k in sorted(set(keys) - set(site_pages)):
                print(f'pages: {k} missing on the site'); failed += 1
            for k in sorted(set(site_pages) - set(keys)):
                print(f'pages: {k} extra on the site'); failed += 1
            compared = len(keys)
        else:
            glob = scope.split(':', 1)[1] if scope.startswith('contents:') else '*'
            glob, *excluded = glob.split('!')
            if not any(fnmatch.fnmatchcase(key, glob) for key in keys):
                # Not a failure: the scopes are shared by projects that have different pages.
                print(f'{scope}: no page matches {glob}')
            for key in keys:
                if not fnmatch.fnmatchcase(key, glob) or any(fnmatch.fnmatchcase(key, x) for x in excluded):
                    continue
                if key not in site_pages:
                    print(f'{scope}: {key} has no site page'); failed += 1
                    continue
                url = site_pages[key]['url']
                path = os.path.join(args.site, url.lstrip('/'))
                if url.endswith('/'):
                    path = os.path.join(path, 'index.html')
                ours = fragments(read(path), scope)
                theirs = fragments(doxy[key], scope)
                for name in sorted(set(theirs) | set(ours)):
                    compared += 1
                    if name not in ours:
                        d = 'missing on the site'
                    elif name not in theirs:
                        d = 'extra on the site'
                    else:
                        a = tuple(normalize(n, doxygen_links(key)) for n in theirs[name])
                        b = tuple(normalize(n, site_links(urls, key)) for n in ours[name])
                        d = first_diff(('#fragment', (), a), ('#fragment', (), b))
                    if d:
                        print(f'{scope}: {key} {name} {d}'); failed += 1
        print(f'scope {scope}: {compared - failed} of {compared} identical')
        different += failed
    return 1 if different else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
