! Builds a widget and resizes it.
program main
  use demo
  type(widget) :: w
  w = make_widget()
  call w%resize(3, 4)
end program main
