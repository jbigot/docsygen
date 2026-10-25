"""Read the YAML of xml-gaps.yaml and info-rules.yaml: a list of flat maps, in block style.

The Python standard library has no YAML reader, and these files need very little of YAML:
    # a comment
    - key: plain scalar     # an int if it is all digits, else a string
      other: "double-quoted, with JSON escapes"
      third: 'single-quoted, with '' for a quote'
    []                      # the empty list, alone in the file
Anything else is an error, so that a file using more of YAML fails loudly.
"""
import json, re

_ITEM = re.compile(r'^(- |  )([A-Za-z_][A-Za-z0-9_]*):(?: (.*))?$')


def _scalar(text, where):
    text = text.strip()
    if text.startswith('"'):
        try:
            value, end = json.JSONDecoder().raw_decode(text)
        except json.JSONDecodeError as e:
            raise ValueError(f'{where}: bad double-quoted string: {e}') from None
        rest = text[end:].strip()
    elif text.startswith("'"):
        m = re.match(r"'((?:[^']|'')*)'(.*)$", text)
        if not m:
            raise ValueError(f'{where}: unterminated single-quoted string')
        value, rest = m.group(1).replace("''", "'"), m.group(2).strip()
    else:
        value, _, comment = text.partition(' #')
        value, rest = value.strip(), ''
        if not value:
            raise ValueError(f'{where}: missing value')
        if value[0] in '[]{}&*!|>%@`':
            raise ValueError(f'{where}: unsupported YAML in {value!r}')
        return int(value) if value.isdigit() else value
    if rest and not rest.startswith('#'):
        raise ValueError(f'{where}: text after the string: {rest!r}')
    return value


def loads(text, name='<yaml>'):
    items = []
    lines = [(n, l.rstrip()) for n, l in enumerate(text.splitlines(), 1)]
    lines = [(n, l) for n, l in lines if l.strip() and not l.lstrip().startswith('#')]
    if len(lines) == 1 and lines[0][1].strip() == '[]':
        return []
    for n, line in lines:
        where = f'{name}:{n}'
        m = _ITEM.match(line)
        if not m:
            raise ValueError(f'{where}: expected "- key: value" or "  key: value"')
        if m.group(1) == '- ':
            items.append({})
        elif not items:
            raise ValueError(f'{where}: a key before the first item')
        key = m.group(2)
        if key in items[-1]:
            raise ValueError(f'{where}: duplicate key {key}')
        items[-1][key] = _scalar(m.group(3) or '', where)
    return items


def load(path):
    with open(path, encoding='utf-8') as f:
        return loads(f.read(), path)
