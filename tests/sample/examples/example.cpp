// Builds a widget and resizes it.
#include "demo/widget.hpp"

int main() {
  demo::Widget* w = demo::make_widget();
  w->resize(3, 4);
  return 0;
}
