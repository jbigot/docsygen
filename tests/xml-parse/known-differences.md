# Known differences between the XML readers and expat

`run.sh` compares two readers with expat:

- the template reader, `layouts/_partials/docsygen/xml/parse.html`;
- `unmarshal`, the native decoder that `transform.Unmarshal` gets with `targetType: document`
  (gohugoio/hugo#15485), built on Go's `encoding/xml`.

The rule is that whatever the template reader accepts, the native decoder accepts too, with the
same tree. A site that builds with the template reader then builds identically with the native
decoder. The template reader may reject more. Expat is the reference for well-formed input only,
and both readers differ from it as listed below. Each difference is tested by the file named with
it, under `edge/`.

## Accepted by both readers and by encoding/xml, rejected by expat

| Input | Tree | Test |
| --- | --- | --- |
| A character reference to a surrogate, `&#xD800;` | U+FFFD, as `string(rune(n))` gives in Go | `lenient/surrogate-ref.xml` |
| A duplicate attribute (golang/go#68295) | the last value | `lenient/duplicate-attr.xml` |

`run.sh` checks the tree of each of them, for both readers.

## Attribute whitespace is not normalized, as in encoding/xml

XML 1.0 §3.3.3 turns each tab, newline and carriage return in an attribute value into a space.
`encoding/xml` doesn't (golang/go#20614), and neither does the template reader: line ends become
`\n` everywhere, and tabs stay. `run.sh` reports these attributes as `KNOWN go#20614`.

| Input | Test |
| --- | --- |
| A tab and a newline in an attribute value | `good/attr-ws.xml` |
| CRLF and a lone CR in an attribute value | `good/crlf.xml` |

## Rejected by the template reader, accepted by unmarshal

The template reader is stricter here, which the rule allows. `run.sh` reports them as "accepted
by design" with `READER=unmarshal`.

| Input | Why unmarshal accepts it | Test |
| --- | --- | --- |
| A second root element | reading stops when the root closes | `bad/second-root.xml` |
| A stray end tag after the root | the same | `bad/extra.xml` |
| Text after the root | the same | `bad/text-outside.xml` |
| A non-ASCII element or attribute name | `encoding/xml` accepts Unicode names, as expat does | `bad/non-ascii-name.xml` |
| Attributes without whitespace between them (golang/go#68385) | `encoding/xml` doesn't require it | `lenient/no-space-between-attrs.xml` |
| A `<!…>` declaration other than DOCTYPE, outside a DOCTYPE | `encoding/xml` returns it as a directive, which is dropped | `bad/declaration.xml` |

## Rejected by both readers, accepted by expat

| Input | Test |
| --- | --- |
| `version="1.1"` in the XML declaration | `bad/xml-version.xml` |
| An encoding other than UTF-8 (`encoding/xml` has no `CharsetReader`) | `bad/encoding.xml` |

Both readers also reject names with more than one colon (`<a:b:c/>`), which XML 1.0 allows and
expat accepts, but which aren't namespace well-formed. No test pins this, in either direction:
either behaviour is acceptable for the native decoder.
