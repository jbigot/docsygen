/** @file
 *  @brief Alias templates, and a member with a qualifier.
 */
#pragma once

#include <vector>

/// @brief Aliases.
namespace demo::aliases {

/** @brief A vector of values, as an alias template.
 *  @tparam T the value type
 */
template <typename T>
using Vec = std::vector<T>;

/** @brief Repeats a value.
 *  @qualifier experimental
 *  @param v the value
 *  @param n how many times
 *  @return n copies of v
 */
template <typename T>
Vec<T> repeat(T v, int n);

} // namespace demo::aliases
