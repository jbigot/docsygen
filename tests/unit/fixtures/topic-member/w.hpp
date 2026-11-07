/** \file w.hpp
 * A class with a member in a topic.
 */
/** \defgroup tools Tools
 * A topic.
 */
/** A widget. */
class W {
public:
  /** \ingroup tools
   * A method documented in a topic.
   */
  void grouped();
  /** A method of no topic. */
  void plain();
};
/** A namespace with a class in a topic. */
namespace ns {
/** \ingroup tools
 * A class in a topic.
 */
class Grouped {};
/** A class of no topic. */
class Plain {};
}
