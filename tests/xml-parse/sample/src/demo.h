/** @file demo.h
 *  @brief A demo header.
 */
namespace demo {
/** @brief A widget.
 *
 * Use @ref make_widget to build one, it is **fast** and `cheap`.
 * @warning Not thread-safe.
 */
class Widget {
public:
  /** @brief Resize &amp; "redraw" <em>now</em> -- ok.
   *  @param w the new width, see @ref Widget
   *  @param h the new height
   *  @return true on success
   */
  bool resize(int w, int h = 0) const noexcept;
};
/// Build a widget.
Widget make_widget();
}
