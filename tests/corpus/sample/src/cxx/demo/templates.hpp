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
