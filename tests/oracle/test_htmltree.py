"""Tests of htmltree.py, the HTML tree, selectors and gaps of the oracles, and of listyaml.py.

Run: python3 -I -m unittest discover -s tests/oracle -p 'test_htmltree.py'
"""
import unittest
import htmltree, listyaml


def shape(node):
    """node as nested (tag, attributes, children) tuples, adjacent texts merged, empty ones left out."""
    children = []
    for c in node.children:
        if not isinstance(c, str):
            children.append(shape(c))
        elif children and isinstance(children[-1], str):
            children[-1] += c
        elif c:
            children.append(c)
    return (node.tag, node.attrs, children)


def gap(**kw):
    return dict({'pages': '*', 'reason': 'r', 'evidence': 'e'}, **kw)


class Gaps(unittest.TestCase):
    def pages(self):
        return {'classX': htmltree.parse('<div class="contents"><p>keep</p><div class="memdoc">x</div>'
                                      '<div class="memdoc">y</div><a class="el" href="h" title="t">l</a></div>'),
                'other': htmltree.parse('<div class="contents"><div class="memdoc">z</div></div>')}

    def test_a_gap_removes_its_nodes_on_the_doxygen_side_only(self):
        pages = self.pages()
        siteside = htmltree.parse('<div class="contents"><p>keep</p></div>')
        errors, _ = htmltree.apply_gaps(pages, [gap(pages='classX', select='div.memdoc', count=2)])
        self.assertEqual(errors, [])
        self.assertEqual(shape(pages['classX']),
                         shape(htmltree.parse('<div class="contents"><p>keep</p><a class="el" href="h" title="t">l</a></div>')))
        self.assertEqual(len(htmltree.find(siteside, 'p')), 1)

    def test_text_narrows_the_match(self):
        pages = self.pages()
        errors, _ = htmltree.apply_gaps(pages, [gap(select='div.memdoc', text='^[xz]$', count=2)])
        self.assertEqual(errors, [])
        self.assertEqual([htmltree.text(n) for n in htmltree.find(pages['classX'], 'div.memdoc')], ['y'])

    def test_attr_removes_only_that_attribute(self):
        pages = self.pages()
        errors, _ = htmltree.apply_gaps(pages, [gap(select='a.el', attr='title', count=1)])
        self.assertEqual(errors, [])
        (a,) = htmltree.find(pages['classX'], 'a.el')
        self.assertEqual(a.attrs, {'class': 'el', 'href': 'h'})

    def test_unwrap_keeps_the_children(self):
        pages = self.pages()
        errors, _ = htmltree.apply_gaps(pages, [gap(select='a.el', unwrap=True, count=1)])
        self.assertEqual(errors, [])
        self.assertEqual(htmltree.find(pages['classX'], 'a'), [])
        self.assertIn('l', [c for c in htmltree.find(pages['classX'], 'div.contents')[0].children if isinstance(c, str)])

    def test_empty_keeps_the_element(self):
        pages = {'p': htmltree.parse('<table><tr><td class="desc">a <span class="tt">b</span> c</td></tr></table>')}
        errors, _ = htmltree.apply_gaps(pages, [gap(select='td.desc', empty=True, count=1)])
        self.assertEqual(errors, [])
        (td,) = htmltree.find(pages['p'], 'td.desc')
        self.assertEqual(td.children, [])

    def test_a_removed_line_takes_its_newline(self):
        pages = {'p': htmltree.parse('<div class="fragment"><div class="line">a</div>\n<div class="ttc">t</div>\n</div>')}
        errors, _ = htmltree.apply_gaps(pages, [gap(select='div.ttc', count=1)])
        self.assertEqual(errors, [])
        self.assertEqual(shape(pages['p']), shape(htmltree.parse('<div class="fragment"><div class="line">a</div>\n</div>')))

    def test_an_attribute_value_narrows_the_match(self):
        pages = {'p': htmltree.parse('<ol type="1"><li>a</li></ol><ol type="a" start="3"><li>b</li></ol>')}
        errors, _ = htmltree.apply_gaps(pages, [gap(select='ol[type=1]', attr='type', count=1)])
        self.assertEqual(errors, [])
        self.assertEqual([n.attrs for n in htmltree.find(pages['p'], 'ol')], [{}, {'type': 'a', 'start': '3'}])

    def test_an_attribute_prefix_matches_any_tag(self):
        pages = {'p': htmltree.parse('<table class="markdownTable"><tr class="markdownTableHead">'
                                  '<th class="markdownTableHeadLeft">a</th></tr></table><table class="doxtable"></table>')}
        errors, _ = htmltree.apply_gaps(pages, [gap(select='[class^=markdownTable]', attr='class', count=3)])
        self.assertEqual(errors, [])
        self.assertEqual([n.attrs for n in htmltree.find(pages['p'], 'table')], [{}, {'class': 'doxtable'}])

    def test_an_attribute_alone_selects_the_elements_that_have_it(self):
        pages = {'p': htmltree.parse('<div data-x="1">a</div><div data-x="">b</div><div>c</div>')}
        errors, _ = htmltree.apply_gaps(pages, [gap(select='[data-x]', count=2)])
        self.assertEqual(errors, [])
        self.assertEqual(htmltree.text(pages['p']), 'c')

    def test_a_space_selects_descendants(self):
        pages = {'p': htmltree.parse('<table class="memname"><tr><td class="memname"><span><a class="el" href="h">x</a></span>'
                                  '</td></tr></table><p><a class="el" href="h">x</a></p>')}
        errors, _ = htmltree.apply_gaps(pages, [gap(select='td.memname a.el', unwrap=True, count=1)])
        self.assertEqual(errors, [])
        self.assertEqual([htmltree.text(n.parent) for n in htmltree.find(pages['p'], 'a.el')], ['x'])
        self.assertEqual(htmltree.find(pages['p'], 'a.el')[0].parent.tag, 'p')

    def test_a_tilde_selects_later_siblings(self):
        pages = {'p': htmltree.parse('<table><tr><td class="memItemRight"><a class="el" href="h">size</a> (int '
                                  '<a class="el" href="h">size</a>)</td></tr></table>')}
        errors, _ = htmltree.apply_gaps(pages, [gap(select='td.memItemRight a.el ~ a.el', text='^size$', unwrap=True, count=1)])
        self.assertEqual(errors, [])
        self.assertEqual(htmltree.text(htmltree.find(pages['p'], 'td')[0]), 'size (int size)')
        self.assertEqual(len(htmltree.find(pages['p'], 'a.el')), 1)

    def test_contains_narrows_an_element_by_its_text(self):
        pages = {'p': htmltree.parse('<table><tr><td class="memname">enum <a class="el" href="h">S</a></td></tr>'
                                  '<tr><td class="memname">typedef void(* f) (<a class="el" href="h">S</a> s)</td></tr></table>')}
        errors, _ = htmltree.apply_gaps(pages, [gap(select='td.memname:contains(typedef void) a.el', unwrap=True, count=1)])
        self.assertEqual(errors, [])
        self.assertEqual([htmltree.text(a.parent) for a in htmltree.find(pages['p'], 'a.el')], ['enum S'])

    def test_replace_rewrites_the_own_text_of_an_element(self):
        pages = {'p': htmltree.parse('<div class="contents"><hr/>from the following files:<ul><li>files:</li></ul></div>')}
        errors, _ = htmltree.apply_gaps(pages, [gap(select='div.contents', replace='files:$', **{'with': 'file:'}, count=1)])
        self.assertEqual(errors, [])
        self.assertEqual(htmltree.text(pages['p']), 'from the following file:files:')

    def test_replace_without_a_match_does_not_select(self):
        errors, _ = htmltree.apply_gaps({'p': htmltree.parse('<div class="contents">a file</div>')},
                                     [gap(select='div.contents', replace='files', **{'with': 'file'}, count=1)])
        self.assertIn('stale', errors[0])

    def test_a_wrong_count_fails(self):
        errors, _ = htmltree.apply_gaps(self.pages(), [gap(select='div.memdoc', count=2)])
        self.assertEqual(len(errors), 1)
        self.assertIn('3 matches', errors[0])

    def test_a_gap_without_matches_is_stale(self):
        errors, _ = htmltree.apply_gaps(self.pages(), [gap(select='div.nothing', count=0)])
        self.assertEqual(len(errors), 1)
        self.assertIn('stale', errors[0])

    def test_the_report_lists_the_matches(self):
        _, report = htmltree.apply_gaps(self.pages(), [gap(pages='other', select='div.memdoc', count=1)])
        self.assertTrue(any('other' in line for line in report))


class ListYaml(unittest.TestCase):
    def test_a_list_of_flat_maps(self):
        text = ('# gaps\n- pages: "class*"\n  select: div.memdoc  # a comment\n  count: 3\n'
                "  reason: 'it''s so'\n- pages: x\n  count: 1\n")
        self.assertEqual(listyaml.loads(text), [
            {'pages': 'class*', 'select': 'div.memdoc', 'count': 3, 'reason': "it's so"},
            {'pages': 'x', 'count': 1}])

    def test_the_empty_list(self):
        self.assertEqual(listyaml.loads('# none yet\n[]\n'), [])

    def test_unsupported_yaml_is_an_error(self):
        for text in ('- a: [1, 2]\n', '- a: |\n    x\n', 'a: 1\n', '- a: 1\n  a: 2\n'):
            with self.assertRaises(ValueError, msg=text):
                listyaml.loads(text)



if __name__ == '__main__':
    unittest.main()
