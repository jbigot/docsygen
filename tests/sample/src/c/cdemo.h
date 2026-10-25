/** @file
 *  @brief A C API.
 */
#ifndef CDEMO_H
#define CDEMO_H

/** @defgroup cdemo The C demo
 *  @brief The C demo API, as a group.
 *  @{
 */

/** @defgroup cdemo_shapes Shapes
 *  @brief Shapes, a subgroup.
 *  @{
 */

/// A point.
struct cpoint {
  int x; ///< The abscissa.
  int y; ///< The ordinate.
};

/// A value of one of several kinds.
union cvalue {
  int i;    ///< As an integer.
  double d; ///< As a double.
};

/** @} */

/// Status codes.
enum cstatus {
  CSTATUS_OK,    ///< Success.
  CSTATUS_ERROR, ///< Failure.
};

/// A point, as a typedef.
typedef struct cpoint cpoint_t;

/** @brief A callback.
 *  @param data the user data
 *  @param code the event code
 *  @return 0 to continue
 */
typedef int (*ccallback)(void* data, int code);

/// The larger of two values.
#define CMAX(a, b) ((a) > (b) ? (a) : (b))

/// The version of the C demo.
#define CDEMO_VERSION 3

/// A global counter.
extern int cdemo_counter;

/** @name Lifecycle
 *  Initialization and finalization, as a member group.
 *  @{
 */
/// Initializes the library.
int cdemo_init(void);
/// Finalizes the library.
void cdemo_finalize(void);
/** @} */

/** @} */

#endif
