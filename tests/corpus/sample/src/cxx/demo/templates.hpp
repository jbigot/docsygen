/** @file
 *  @brief Templates, enums and concepts.
 */
#pragma once

namespace demo {

/** @brief A box holding values.
 *  @tparam T the value type
 *  @tparam N the capacity
 */
template <typename T, int N = 3>
class Box {
public:
  /// A nested class.
  class Iterator {
  public:
    /// Moves to the next value.
    Iterator& operator++();
  };
  /// The first value.
  const T& front() const;
};

/** @brief A class template, specialized below.
 *  @tparam T the type
 */
template <typename T>
class Foo {
public:
  /// The value.
  T value;
};

/// The specialization of Foo for int.
template <>
class Foo<int> {
public:
  /// The value, as an int.
  int value;
};

/** @brief Colors, as a scoped enum.
 */
enum class Color {
  red,       ///< The color of blood.
  green,     ///< The color of grass.
  blue = 4,  ///< The color of the sky.
};

/// Levels, as an unscoped enum.
enum Level {
  low,  ///< Low.
  high, ///< High.
};

/** @brief Types that a Box can hold.
 *  @tparam T the type
 */
template <typename T>
concept Boxable = requires(T t) { t; };

/** @brief Puts a value in a Box.
 *  @tparam T the type of the value
 *  @param v the value
 *  @return the box
 */
template <Boxable T>
Box<T> box(T v);

namespace {
/// A helper in an anonymous namespace.
int helper();
} // namespace

} // namespace demo

namespace demo {

/** @brief The partial specialization of Foo for pointers.
 *  @tparam T the pointed type
 */
template <typename T>
class Foo<T*> {
public:
  /// The value, as a pointer.
  T* value;
};

/// A class whose nested class has a nested class.
class Outer {
public:
  /// A class nested in Outer.
  class Inner {
  public:
    /// A class nested in a nested class.
    class Innermost {
    public:
      /// The depth.
      int depth;
    };
  };
};

/** @brief The size of a type, as a variable template.
 *  @tparam T the type
 */
template <typename T>
constexpr int size_of = sizeof(T);
/// The full specialization of size_of for void.
template <>
constexpr int size_of<void> = 0;
/// The partial specialization of size_of for pointers.
template <typename T>
constexpr int size_of<T*> = sizeof(void*);

} // namespace demo

namespace demo {

/** @brief Counts its arguments, as a variadic template.
 *  @tparam Args the types of the arguments
 *  @param args the arguments
 *  @return their number
 */
template <typename... Args>
int count_args(Args... args);

/** @brief Doubles an integral value, under a requires clause.
 *  @tparam T an integral type
 *  @param v the value
 *  @return twice the value
 */
template <typename T>
  requires std::integral<T>
T twice(T v);

/** @brief Repeats a value, with a default template argument.
 *  @tparam T the type of the value
 *  @tparam N the number of times
 *  @param v the value
 *  @return the last copy
 */
template <typename T, int N = 3>
T repeat(T v);

/** @brief Shrinks a widget by one, an operator whose name typography would rewrite.
 *  @param w the widget
 *  @return w
 */
Widget& operator--(Widget& w);

} // namespace demo
