"""HTML trees, CSS-like selectors, and the gaps of xml-gaps.yaml, for the oracles (info.py) and
tests/site/check.py.

A tree is a Node('#document'), with Node elements and str text as children (parse()).
A SELECTOR is TAG, TAG.CLASS, TAG#ID, .CLASS or #ID, each optionally followed by [ATTR],
[ATTR=VALUE] or [ATTR^=PREFIX] and by :contains(TEXT) (jQuery's), or those alone; a space selects
descendants and ~ later siblings, as in CSS.
GAPS.yaml: what Doxygen's HTML shows and the XML cannot give, removed from the Doxygen side:
[{pages: GLOB, select: SELECTOR, text?: REGEX, attr?: NAME, unwrap?: true, empty?: true,
  replace?: REGEX, with?: STRING, count: N, reason, evidence, oracle?: NAME}]. attr removes that
attribute only, unwrap the element but not its children, empty its children only, and replace
substitutes with for the matches of replace in the element's own text, not in its descendants',
and selects only an element that has one. count is the exact number of matches over all pages:
any other number is an error, and so is an entry without matches (stale); the counts are those of
Doxygen 1.18.0's HTML. An entry with an oracle applies only when that oracle is named.
"""
import fnmatch, html.parser, re

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
