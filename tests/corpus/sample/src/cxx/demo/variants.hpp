/** @file
 *  @brief A member whose description gives its example in several languages.
 */
#pragma once

namespace demo {

/** @brief Grows a widget.
 *
 * @anchor sample_member
 * @anchor sample_member-C
 * C source code:
 * ```C
 * demo_grow(w);
 * ```
 * @anchor sample_member-Fortran
 * Fortran source code:
 * ```Fortran
 * call w%grow()
 * ```
 */
void grow();

} // namespace demo
