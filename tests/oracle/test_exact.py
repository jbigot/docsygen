"""Tests of exact.py, the exact Doxygen HTML comparator, and of listyaml.py.

Run: python3 -I -m unittest discover -s tests/oracle -p 'test_exact.py'
"""
import contextlib, io, json, os, subprocess, sys, tempfile, unittest
import exact, listyaml


def doxygen(html, key='page'):
    return exact.normalize(exact.parse(html), exact.doxygen_links(key))


def site(html, key='page', urls=None):
    return exact.normalize(exact.parse(html), exact.site_links(urls or {}, key))


class Whitespace(unittest.TestCase):
    def test_runs_become_one_space(self):
        self.assertEqual(doxygen('<p>a \n\t b</p>'), doxygen('<p>a b</p>'))

    def test_whitespace_next_to_block_tags_is_removed(self):
        self.assertEqual(doxygen('<div>\n <p> a </p>\n text <ul> <li> b </li> </ul></div>'),
                         doxygen('<div><p>a</p>text<ul><li>b</li></ul></div>'))

    def test_whitespace_next_to_inline_tags_is_kept(self):
        self.assertNotEqual(doxygen('<p>a <b>x</b></p>'), doxygen('<p>a<b>x</b></p>'))

    def test_nbsp_is_not_whitespace(self):
        self.assertNotEqual(doxygen('<p>a&#160;</p>'), doxygen('<p>a</p>'))

    def test_pre_keeps_its_spaces(self):
        self.assertNotEqual(doxygen('<pre>a  b</pre>'), doxygen('<pre>a b</pre>'))
        self.assertNotEqual(doxygen('<div><pre> a</pre></div>'), doxygen('<div><pre>a</pre></div>'))

    def test_fragment_keeps_its_spaces(self):
        self.assertNotEqual(doxygen('<div class="fragment"><div class="line">a  b</div>\n</div>'),
                            doxygen('<div class="fragment"><div class="line">a b</div></div>'))


class Markup(unittest.TestCase):
    def test_character_references_are_decoded(self):
        self.assertEqual(doxygen('<p>&#160;&#60;&amp;&lt;</p>'), doxygen('<p> &lt;&#38;&#x3c;</p>'))

    def test_attribute_order_is_ignored(self):
        self.assertEqual(doxygen('<a id="x" class="y">t</a>'), doxygen('<a class="y" id="x">t</a>'))

    def test_void_elements_compare_without_slash(self):
        self.assertEqual(doxygen('<p>a<br/>b<img src="i.png"/></p>'), doxygen('<p>a<br>b<img src="i.png"></p>'))

    def test_comments_are_removed(self):
        self.assertEqual(doxygen('<p>a<!-- c -->b</p>'), doxygen('<p>ab</p>'))

    def test_area_coords_are_ignored(self):
        self.assertEqual(doxygen('<map><area coords="1,2" href="classX.html"></map>'),
                         site('<map><area coords="3,4" href="/ref/classx/"></map>', urls={'/ref/classx/': 'classX'}))

    def test_other_attributes_count(self):
        self.assertNotEqual(doxygen('<td class="a">x</td>'), doxygen('<td class="b">x</td>'))


class Links(unittest.TestCase):
    urls = {'/ref/classx/': 'classX', '/ref/classx-2/': 'classx', '/ref/': 'index'}

    def test_page_links_compare_by_key_and_fragment(self):
        self.assertEqual(doxygen('<a href="classX.html#a1">r</a>'),
                         site('<a href="/ref/classx/#a1">r</a>', urls=self.urls))

    def test_different_fragments_differ(self):
        self.assertNotEqual(doxygen('<a href="classX.html#a1">r</a>'),
                            site('<a href="/ref/classx/#a2">r</a>', urls=self.urls))

    def test_keys_are_case_sensitive(self):
        self.assertNotEqual(doxygen('<a href="classX.html">r</a>'), doxygen('<a href="classx.html">r</a>'))
        self.assertEqual(doxygen('<a href="classx.html">r</a>'), site('<a href="/ref/classx-2/">r</a>', urls=self.urls))

    def test_fragment_only_links_point_at_the_current_page(self):
        self.assertEqual(doxygen('<a href="#a1">r</a>', key='classX'), site('<a href="#a1">r</a>', key='classX'))
        self.assertNotEqual(doxygen('<a href="#a1">r</a>', key='classX'), site('<a href="#a1">r</a>', key='other'))

    def test_local_files_compare_by_basename(self):
        self.assertEqual(doxygen('<img src="classX.png">'), site('<img src="/ref/classx/classX.png">', urls=self.urls))
        self.assertNotEqual(doxygen('<img src="a.png">'), site('<img src="/ref/b.png">', urls=self.urls))

    def test_external_links_compare_as_is(self):
        self.assertEqual(doxygen('<a href="https://example.org/a">x</a>'), site('<a href="https://example.org/a">x</a>'))
        self.assertNotEqual(doxygen('<a href="https://example.org/a">x</a>'), site('<a href="https://example.org/b">x</a>'))


class FirstDiff(unittest.TestCase):
    def test_equal_trees_have_no_difference(self):
        self.assertIsNone(exact.first_diff(doxygen('<p>a<b>x</b></p>'), doxygen('<p>a<b>x</b></p>')))

    def test_the_difference_is_located(self):
        d = exact.first_diff(doxygen('<div><p>a</p><p>b</p></div>'), doxygen('<div><p>a</p><p>c</p></div>'))
        self.assertIn('p[1]', d)
        self.assertIn("'b'", d)


def gap(**kw):
    return dict({'pages': '*', 'reason': 'r', 'evidence': 'e'}, **kw)


class Gaps(unittest.TestCase):
    def pages(self):
        return {'classX': exact.parse('<div class="contents"><p>keep</p><div class="memdoc">x</div>'
                                      '<div class="memdoc">y</div><a class="el" href="h" title="t">l</a></div>'),
                'other': exact.parse('<div class="contents"><div class="memdoc">z</div></div>')}

    def test_a_gap_removes_its_nodes_on_the_doxygen_side_only(self):
        pages = self.pages()
        siteside = exact.parse('<div class="contents"><p>keep</p></div>')
        errors, _ = exact.apply_gaps(pages, [gap(pages='classX', select='div.memdoc', count=2)])
        self.assertEqual(errors, [])
        self.assertEqual(exact.normalize(pages['classX'], exact.doxygen_links('classX')),
                         exact.normalize(exact.parse('<div class="contents"><p>keep</p><a class="el" href="h" title="t">l</a></div>'),
                                         exact.doxygen_links('classX')))
        self.assertEqual(len(exact.find(siteside, 'p')), 1)

    def test_text_narrows_the_match(self):
        pages = self.pages()
        errors, _ = exact.apply_gaps(pages, [gap(select='div.memdoc', text='^[xz]$', count=2)])
        self.assertEqual(errors, [])
        self.assertEqual([exact.text(n) for n in exact.find(pages['classX'], 'div.memdoc')], ['y'])

    def test_attr_removes_only_that_attribute(self):
        pages = self.pages()
        errors, _ = exact.apply_gaps(pages, [gap(select='a.el', attr='title', count=1)])
        self.assertEqual(errors, [])
        (a,) = exact.find(pages['classX'], 'a.el')
        self.assertEqual(a.attrs, {'class': 'el', 'href': 'h'})

    def test_a_wrong_count_fails(self):
        errors, _ = exact.apply_gaps(self.pages(), [gap(select='div.memdoc', count=2)])
        self.assertEqual(len(errors), 1)
        self.assertIn('3 matches', errors[0])

    def test_a_gap_without_matches_is_stale(self):
        errors, _ = exact.apply_gaps(self.pages(), [gap(select='div.nothing', count=0)])
        self.assertEqual(len(errors), 1)
        self.assertIn('stale', errors[0])

    def test_the_report_lists_the_matches(self):
        _, report = exact.apply_gaps(self.pages(), [gap(pages='other', select='div.memdoc', count=1)])
        self.assertTrue(any('other' in line for line in report))


class Run(unittest.TestCase):
    """End to end: a Doxygen HTML directory, a site, its paths.json, and the scopes."""

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        d = self.dir.name
        self.html, self.public = os.path.join(d, 'html'), os.path.join(d, 'public')
        os.makedirs(self.html)
        os.makedirs(os.path.join(self.public, 'ref', 'classx'))
        page = ('<div class="header"><div class="headertitle"><div class="title">X</div></div></div>'
                '<div class="contents"><div class="textblock"><p>T <a href="classX.html#a1">x</a></p></div>'
                '<table class="memberdecls"><tr class="heading"><td colspan="2"><h2 class="groupheader">'
                '<a id="pub-methods" name="pub-methods"></a>Public</h2></td></tr></table>'
                '<a id="a1" name="a1"></a><h2 class="memtitle">f()</h2><div class="memitem">M</div></div>')
        self.write(os.path.join(self.html, 'classX.html'), page)
        self.write(os.path.join(self.html, 'doxygen_crawl.html'), '<p>crawl</p>')
        self.write(os.path.join(self.html, 'classX.png'), 'png')
        self.write(os.path.join(self.public, 'ref', 'classx', 'index.html'),
                   page.replace('classX.html#a1', '/ref/classx/#a1'))
        self.paths = os.path.join(d, 'paths.json')
        self.write(self.paths, json.dumps({'pages': {'classX': {'url': '/ref/classx/', 'roles': []}}}))
        self.gaps = os.path.join(d, 'gaps.yaml')
        self.write(self.gaps, '[]\n')

    def tearDown(self):
        self.dir.cleanup()

    @staticmethod
    def write(path, text):
        with open(path, 'w') as f:
            f.write(text)

    def run_exact(self, *scopes):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            status = exact.main(['--doxygen', self.html, '--site', self.public, '--paths', self.paths,
                                 '--gaps', self.gaps] + [a for s in scopes for a in ('--scope', s)])
        return status, out.getvalue()

    def test_identical_pages_pass_every_scope(self):
        status, out = self.run_exact('pages', 'header', 'textblock', 'memberdecls', 'memitem', 'contents',
                                     'contents:class*')
        self.assertEqual(status, 0, out)

    def test_a_missing_page_fails_the_pages_scope(self):
        self.write(os.path.join(self.html, 'extra.html'), '<p>x</p>')
        status, out = self.run_exact('pages')
        self.assertEqual(status, 1)
        self.assertIn('extra', out)

    def test_a_different_member_fails_the_memitem_scope(self):
        path = os.path.join(self.public, 'ref', 'classx', 'index.html')
        with open(path) as f:
            text = f.read()
        self.write(path, text.replace('>M<', '>N<'))
        self.assertEqual(self.run_exact('memitem')[0], 1)
        self.assertEqual(self.run_exact('memberdecls')[0], 0)

    def test_a_glob_without_pages_fails(self):
        status, out = self.run_exact('contents:other*')
        self.assertEqual(status, 1)
        self.assertIn('no page matches', out)

    def test_the_script_runs_isolated(self):
        """run.sh runs exact.py with python3 -I, which keeps its own directory off sys.path."""
        result = subprocess.run([sys.executable, '-I', exact.__file__, '--doxygen', self.html, '--site', self.public,
                                 '--paths', self.paths, '--gaps', self.gaps, '--scope', 'pages'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_gaps_of_another_oracle_are_ignored(self):
        self.write(self.gaps, '- oracle: pdi\n  pages: "*"\n  select: div.memitem\n  count: 1\n  reason: r\n  evidence: e\n')
        status, out = self.run_exact('pages')
        self.assertEqual(status, 0, out)


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
