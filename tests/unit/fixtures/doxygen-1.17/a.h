/** \file a.h
 * A file.
 *
 * \mermaid "Flow caption"
 * graph LR
 *   A --> B
 * \endmermaid
 *
 * \mermaidfile flow.mmd "File caption"
 */
/** A function. */
void f(void);

/** Types with a size. */
template<typename T>
concept Sized = requires(T t) {
  /// The size of a value.
  t.size();
};
