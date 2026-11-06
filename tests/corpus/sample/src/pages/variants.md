@page variants Example variants

The same example in several languages.

@anchor sample_ex
@anchor sample_ex-C
C source code:
```C
demo_widget* w = demo_make_widget();
demo_resize(w, 3, 4);
```

@anchor sample_ex-Fortran
Fortran source code:
```Fortran
w = make_widget()
call w%resize(3, 4)
```

The same, with the variants in one paragraph.

@anchor sample_shared
@anchor sample_shared-C
C source code:
```C
demo_resize(w, 5, 6);
```
@anchor sample_shared-Fortran
Fortran source code:
```Fortran
call w%resize(5, 6)
```

Variants of two paragraphs each.

@anchor sample_pb
@parblock
@anchor sample_pb-C
C source code:
```C
demo_resize(w, 7, 8);
```

is the same as:
```C
demo_resize(w, 7, 8);
demo_unused(w);
```
@endparblock

@parblock
@anchor sample_pb-Fortran
Fortran source code:
```Fortran
call w%resize(7, 8)
```

is the same as:
```Fortran
call w%resize(7, 8)
call unused(w)
```
@endparblock

A second group, from files.

@anchor sample_inc
@anchor sample_inc-C
C++ source code:
@include example.cpp
@anchor sample_inc-Fortran
Fortran source code:
@include example.f90

A group in a list:

- Step one.
- Step two, in two languages.
  @anchor sample_item
  @anchor sample_item-C
  C source code:
  ```C
  demo_resize(w, 3, 4);
  ```
  @anchor sample_item-Fortran
  Fortran source code:
  ```Fortran
  call w%resize(3, 4)
  ```
- Step three.

An anchor with no group before it:

@anchor plain-dashed
```C
demo_resize(w, 1, 1);
```
