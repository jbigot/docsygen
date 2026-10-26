"""Tests of info.py, the information comparator of the Docsy output.

Run: python3 -I -m unittest discover -s tests/oracle -p 'test_info.py'
"""
import contextlib, io, json, os, tempfile, unittest
import exact, info


def compound(key):
    return [{'role': 'compound', 'id': key}]


def doxygen(body, title='X'):
    return exact.parse(f'<div class="header"><div class="title">{title}</div></div>'
                       f'<div class="contents">{body}</div>')


def docsy(body, title='X'):
    return exact.parse(f'<main><div class="td-content"><h1>{title}</h1>{body}</div></main>')


class Compare(unittest.TestCase):
    """compare() on one Doxygen page classX and one Docsy page x, unless a test says otherwise."""

    def setUp(self):
        self.compat = {'pages': {'classX': {'url': '/ref/classX/', 'roles': compound('classX')}},
                       'targets': {'classX': {'page': 'classX', 'anchor': ''}}, 'anchors': {}}
        self.site = {'pages': {'x': {'url': '/ref/x/', 'roles': compound('classX')}},
                     'targets': {'classX': {'page': 'x', 'anchor': ''}}, 'anchors': {}}

    def compare(self, theirs, ours, rules=()):
        if not isinstance(theirs, dict):
            theirs = {'classX': doxygen(theirs)}
        if not isinstance(ours, dict):
            ours = {'x': docsy(ours)}
        return info.compare(theirs, self.compat, ours, self.site, list(rules))

    def test_the_same_paragraph_wrapped_differently_passes(self):
        result = self.compare('<p>The quick brown\nfox jumps.</p>', '<p>The quick\n  brown fox jumps.</p>')
        self.assertEqual(result.missing, [])

    def test_a_dropped_word_fails(self):
        result = self.compare('<p>The quick brown fox.</p>', '<p>The quick fox.</p>')
        self.assertEqual(len(result.missing), 1)
        self.assertIn('quick brown fox', result.missing[0])

    def test_a_brief_shown_twice_by_doxygen_and_once_by_docsy_fails(self):
        result = self.compare('<p>A widget.</p><table><tr><td>A widget.</td></tr></table>', '<p>A widget.</p>')
        self.assertEqual(len(result.missing), 1)

    def test_a_short_unit_cannot_use_the_same_occurrence_twice(self):
        result = self.compare('<table><tr><td>int</td></tr><tr><td>int</td></tr></table>', '<p>int x; print</p>')
        self.assertEqual(len(result.missing), 1)

    def test_a_scoped_drop_rule_removes_its_nodes(self):
        theirs = '<table><tr><td class="mdescRight">Brief. <a href="#details">More...</a></td></tr></table>'
        rule = {'rule': 'drop', 'select': 'td.mdescRight a', 'phrase': '^More\\.\\.\\.$', 'count': 1, 'reason': 'r'}
        self.assertNotEqual(self.compare(theirs, '<p>Brief.</p>').missing, [])
        result = self.compare(theirs, '<p>Brief.</p>', [rule])
        self.assertEqual((result.missing, result.errors), ([], []))
        self.assertTrue(any('More...' in line for line in result.report))

    def test_a_rule_with_a_wrong_count_fails(self):
        theirs = '<p>Brief. <a href="#details">More...</a></p>'
        rule = {'rule': 'drop', 'select': 'a', 'phrase': 'More', 'count': 2, 'reason': 'r'}
        self.assertEqual(len(self.compare(theirs, '<p>Brief.</p>', [rule]).errors), 1)

    def test_a_tokens_rule_matches_word_by_word(self):
        theirs = '<table><tr><td class="memname">int f</td></tr></table>'
        rule = {'rule': 'tokens', 'select': 'td.memname', 'count': 1, 'reason': 'r'}
        self.assertNotEqual(self.compare(theirs, '<p>f returns int</p>').missing, [])
        self.assertEqual(self.compare(theirs, '<p>f returns int</p>', [rule]).missing, [])

    def test_a_member_link_through_a_differently_named_anchor_passes(self):
        self.compat['targets']['m1'] = {'page': 'classX', 'anchor': 'a1b2'}
        self.site['targets']['m1'] = {'page': 'x', 'anchor': 'resize'}
        result = self.compare('<p><a class="el" href="classX.html#a1b2">resize</a></p>',
                              '<p><a href="/ref/x/#resize">resize</a></p>')
        self.assertEqual(result.missing, [])
        result = self.compare('<p><a class="el" href="classX.html#a1b2">resize</a></p>',
                              '<p><a href="/ref/x/#other">resize</a></p>')
        self.assertEqual(len(result.missing), 1)

    def test_a_link_without_a_model_id_maps_through_the_anchors(self):
        self.compat['anchors'] = {'classX': {'pub-methods': 'pub-methods'}}
        self.site['anchors'] = {'x': {'pub-methods': 'public-member-functions'}}
        result = self.compare('<p><a href="#pub-methods">Public</a></p>',
                              '<p><a href="#public-member-functions">Public</a></p>')
        self.assertEqual(result.missing, [])

    def test_a_link_to_a_page_reaches_the_page_that_holds_its_role(self):
        self.compat['pages']['f_source'] = {'url': '/ref/f_source/', 'roles': [{'role': 'source', 'id': 'f'}]}
        self.site['pages']['x']['roles'] = compound('classX') + [{'role': 'source', 'id': 'f'}]
        result = self.compare('<p><a href="f_source.html">source</a> <a href="f_source.html#l00012">12</a></p>',
                              '<p><a href="/ref/x/">source</a> <a href="/ref/x/#l00012">12</a></p>')
        self.assertEqual(result.missing, [])
        result = self.compare('<p><a href="f_source.html#l00012">12</a></p>', '<p><a href="/ref/x/#l00013">12</a></p>')
        self.assertEqual(len(result.missing), 1)

    def test_rules_of_another_oracle_are_ignored(self):
        rule = {'rule': 'drop', 'select': 'p', 'count': 5, 'reason': 'r', 'oracle': 'other'}
        result = info.compare({'classX': doxygen('<p>A.</p>')}, self.compat, {'x': docsy('<p>A.</p>')}, self.site, [rule], 'mine')
        self.assertEqual(result.errors, [])

    def test_reindented_code_fails(self):
        theirs = '<div class="fragment"><div class="line">if (a)</div>\n<div class="line">  b();</div>\n</div>'
        self.assertEqual(self.compare(theirs, '<pre><code>if (a)\n  b();\n</code></pre>').missing, [])
        self.assertEqual(len(self.compare(theirs, '<pre><code>if (a)\n    b();\n</code></pre>').missing), 1)

    def test_code_is_not_checked_as_text(self):
        theirs = '<div class="fragment"><div class="line">b();</div>\n</div>'
        self.assertEqual(len(self.compare(theirs, '<p>b();</p>').missing), 1)

    def test_two_doxygen_index_pages_map_onto_one_docsy_page(self):
        self.compat['pages'] = {
            'functions': {'url': '/ref/functions/', 'roles': [{'role': 'index', 'name': 'class-members', 'filter': 'all', 'letter': ''}]},
            'functions_func': {'url': '/ref/functions_func/', 'roles': [{'role': 'index', 'name': 'class-members', 'filter': 'functions', 'letter': ''}]}}
        self.site['pages'] = {'members': {'url': '/ref/members/', 'roles': [{'role': 'index', 'name': 'class-members'}]}}
        theirs = {'functions': doxygen('<ul><li>f() : X</li><li>v : X</li></ul>', 'All'),
                  'functions_func': doxygen('<ul><li>f() : X</li></ul>', 'All')}
        ours = '<ul><li>f() : X</li><li>v : X</li></ul><h2>Functions</h2><ul><li>f() : X</li></ul>'
        self.assertEqual(self.compare(theirs, {'members': docsy(ours, 'All All')}).missing, [])
        self.assertEqual(len(self.compare(theirs, {'members': docsy(ours.split('<h2>')[0], 'All All')}).missing), 1)

    def test_a_member_is_compared_with_its_own_element(self):
        self.compat['targets']['m1'] = {'page': 'classX', 'anchor': 'a1'}
        theirs = '<p>Intro.</p><a id="a1"></a><h2 class="memtitle">f()</h2><div class="memitem">Resizes.</div>'
        inside = '<p>Intro.</p><div data-doxygen-id="m1"><h3>f()</h3><p>Resizes.</p></div>'
        outside = '<p>Intro. Resizes.</p><div data-doxygen-id="m1"><h3>f()</h3></div>'
        self.assertEqual(self.compare(theirs, inside).missing, [])
        self.assertEqual(len(self.compare(theirs, outside).missing), 1)

    def test_extra_text_is_reported_but_passes(self):
        result = self.compare('<p>A.</p>', '<p>A. And more.</p>')
        self.assertEqual(result.missing, [])
        self.assertTrue(any('And more.' in line for line in result.extra))


class Run(unittest.TestCase):
    def test_the_script_compares_directories(self):
        with tempfile.TemporaryDirectory() as d:
            def write(path, text):
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, 'w') as f:
                    f.write(text)
            write(f'{d}/html/classX.html', '<div class="header"><div class="title">X</div></div><div class="contents"><p>A b.</p></div>')
            write(f'{d}/html/doxygen_crawl.html', '<p>crawl</p>')
            write(f'{d}/site/ref/x/index.html', '<main><div class="td-content"><h1>X</h1><p>A b.</p></div></main>')
            write(f'{d}/compat.json', json.dumps({'pages': {'classX': {'url': '/c/', 'roles': compound('classX')}}, 'targets': {}, 'anchors': {}}))
            write(f'{d}/paths.json', json.dumps({'pages': {'x': {'url': '/ref/x/', 'roles': compound('classX')}}, 'targets': {}, 'anchors': {}}))
            write(f'{d}/gaps.yaml', '[]\n')
            write(f'{d}/rules.yaml', '[]\n')
            args = ['--doxygen', f'{d}/html', '--compat', f'{d}/compat.json', '--site', f'{d}/site',
                    '--paths', f'{d}/paths.json', '--gaps', f'{d}/gaps.yaml', '--rules', f'{d}/rules.yaml']
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(info.main(args), 0, out.getvalue())
            write(f'{d}/site/ref/x/index.html', '<main><div class="td-content"><h1>X</h1><p>A.</p></div></main>')
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(info.main(args), 1)


if __name__ == '__main__':
    unittest.main()
