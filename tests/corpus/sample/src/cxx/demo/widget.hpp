/** @file
 *  @brief Widgets, spelled in two cases.
 */
#pragma once
#include <cstddef>

/// The demo namespace, spread over several headers.
namespace demo {

/** @brief A widget.
 *
 * Use make_widget() to build one: it is **fast** and `cheap`.
 */
class Widget {
public:
  /// Builds an empty widget.
  Widget();
  /// Builds a square widget.
  explicit Widget(int side);
  /// Copying is forbidden.
  Widget(const Widget&) = delete;
  /// Destroys the widget.
  virtual ~Widget();

  /** @brief Resizes to a square.
   *  @param side the new side
   */
  void resize(int side);
  /** @brief Resizes.
   *  @param w the new width
   *  @param h the new height
   *  @return true on success
   */
  bool resize(int w, int h) const noexcept;

  /// Compares the sizes.
  bool operator<(const Widget& other) const;
  /// Draws at a scale and returns the number of pixels drawn.
  int operator()(int scale) const;
  /// Allocates a widget.
  static void* operator new(std::size_t size);

  /// Draws the widget.
  virtual void draw() const = 0;

  /** @name Accessors
   *  Getters and setters, as a member group.
   *  @{
   */
  /// The width.
  int width() const;
  /// Sets the width.
  void set_width(int w);
  /** @} */

  /** @brief Resizes in place.
   *  @deprecated Use resize() instead.
   */
  void old_resize(int side);
  /** @brief Measures the widget.
   *  @todo Make it faster.
   *  @bug Fails on an empty widget.
   */
  int measure() const;

  /// A member named like a section of the page.
  int details;
  /// The number of widgets alive.
  static int count;
  /// The default side.
  static constexpr int default_side = 10;

protected:
  /// The width, for derived classes.
  int width_;

private:
  /// A secret.
  int secret_;
  /// A friend that peeks at the secret.
  friend bool peek(const Widget& w);
};

/** @brief A lowercase widget, which differs from Widget only by case.
 */
class widget {
public:
  /// A member named like one of Widget's.
  void resize(int side);
};

/** @brief Builds a widget.
 *  @relates Widget
 */
Widget* make_widget();

/** @brief a*b_c [d] \<e\> `f` \#g {h}
 */
class Escapes {
public:
  /// A member of a class with a difficult brief.
  int value;
  /** @brief A member whose documentation has sections.
   *
   *  @section member-section A section of a member
   *  Its text.
   *  @subsection member-subsection A subsection of a member
   *  Its own text.
   */
  void sections();
};

/** @example example.cpp
 *  Builds a widget and resizes it.
 */

} // namespace demo

namespace demo {

/** @name Conversions
 *  An overload set, as a member group of a namespace.
 *  @{
 */
/// Converts an int to a string.
const char* to_string(int value);
/// Converts a double to a string.
const char* to_string(double value);
/** @} */

/// Scales an int, overloaded outside any group.
int scale(int value);
/// Scales a double, overloaded outside any group.
double scale(double value);

/** @name Lookup
 *  A member group of one function.
 *  @{
 */
/// Finds a widget by name.
Widget* find_widget(const char* name);
/** @} */

/** @brief A gadget, whose member groups hold overload sets.
 */
class Gadget {
public:
  /** @name Construction
   *  The constructors, as a member group.
   *  @{
   */
  /// Builds an empty gadget.
  Gadget();
  /// Builds a gadget of a size.
  explicit Gadget(int size);
  /// Builds a gadget from a name.
  explicit Gadget(const char* name);
  /** @} */

  /** @name set
   *  An overload set, as a member group named after its function, as PDI's are.
   *  @{
   */
  /// Sets an int.
  void set(int value);
  /// Sets a double.
  void set(double value);
  /** @} */

  /// Updates the whole gadget; its other overload is private.
  void update();

private:
  /// Updates a part of the gadget.
  void update(int part);

protected:
  /// Updates the gadget by a ratio, for derived gadgets.
  void update(double ratio);
};

/// A gadget that inherits the set of setters its base describes.
class Gizmo : public Gadget {
public:
  /// Spins the gizmo.
  void spin();
};

} // namespace demo
