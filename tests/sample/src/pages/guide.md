@page guide The guide

The guide has sections, an image, a table and code, and a subpage, @subpage details-page.

@secreflist
@refitem first-section
@refitem second-section
@endsecreflist

@section first-section First section

Some text, with a link to demo::Widget.

@subsection a-subsection A subsection

@image html diagram.png "The diagram, in a page"

@subsubsection a-subsubsection A subsubsection

| Option | Meaning |
|--------|---------|
| `-v`   | verbose |
| `-q`   | quiet   |

@section second-section Second section

```cpp
demo::Widget* w = demo::make_widget();
```
