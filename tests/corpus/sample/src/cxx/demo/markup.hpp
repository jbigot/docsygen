/** @file
 *  @brief Every kind of description markup, one function per family.
 */
#pragma once

namespace demo {
/// Description markup, one function per family.
namespace markup {

/** @brief Inline elements.
 *
 * **bold**, <b>b</b>, <s>s</s>, <strike>strike</strike>, <u>underline</u>, *emphasis*,
 * <em>em</em>, `code`, <tt>tt</tt>, H<sub>2</sub>O, x<sup>2</sup>, <small>small</small>,
 * <cite>cite</cite>, <del>del</del>, <ins>ins</ins>, <a href="https://example.org/">a link</a>,
 * https://example.org/auto, a reference to demo::Widget and to
 * @ref demo::Widget::resize(int) "resize", a line<br>break, an anchor @anchor inline-anchor
 * here, an emoji @emoji smile, {@literal a < b} and {@code x + y}, and a rule:
 * <hr>
 * <center>Centered.</center>
 */
void inline_elements();

/** @brief Entities.
 *
 * &nbsp; &iexcl; &cent; &pound; &curren; &yen; &brvbar; &sect; &uml; &copy; &ordf; &laquo;
 * &not; &shy; &reg; &macr; &deg; &plusmn; &sup2; &sup3; &acute; &micro; &para; &middot;
 * &cedil; &sup1; &ordm; &raquo; &frac14; &frac12; &frac34; &iquest; &Agrave; &Aacute; &Acirc;
 * &Atilde; &Auml; &Aring; &AElig; &Ccedil; &Egrave; &Eacute; &Ecirc; &Euml; &Igrave; &Iacute;
 * &Icirc; &Iuml; &ETH; &Ntilde; &Ograve; &Oacute; &Ocirc; &Otilde; &Ouml; &times; &Oslash;
 * &Ugrave; &Uacute; &Ucirc; &Uuml; &Yacute; &THORN; &szlig; &agrave; &aacute; &acirc; &atilde;
 * &auml; &aring; &aelig; &ccedil; &egrave; &eacute; &ecirc; &euml; &igrave; &iacute; &icirc;
 * &iuml; &eth; &ntilde; &ograve; &oacute; &ocirc; &otilde; &ouml; &divide; &oslash; &ugrave;
 * &uacute; &ucirc; &uuml; &yacute; &thorn; &yuml; &fnof; &Alpha; &Beta; &Gamma; &Delta;
 * &Epsilon; &Zeta; &Eta; &Theta; &Iota; &Kappa; &Lambda; &Mu; &Nu; &Xi; &Omicron; &Pi; &Rho;
 * &Sigma; &Tau; &Upsilon; &Phi; &Chi; &Psi; &Omega; &alpha; &beta; &gamma; &delta; &epsilon;
 * &zeta; &eta; &theta; &iota; &kappa; &lambda; &mu; &nu; &xi; &omicron; &pi; &rho; &sigmaf;
 * &sigma; &tau; &upsilon; &phi; &chi; &psi; &omega; &thetasym; &upsih; &piv; &bull; &hellip;
 * &prime; &Prime; &oline; &frasl; &weierp; &image; &real; &trade; &alefsym; &larr; &uarr;
 * &rarr; &darr; &harr; &crarr; &lArr; &uArr; &rArr; &dArr; &hArr; &forall; &part; &exist;
 * &empty; &nabla; &isin; &notin; &ni; &prod; &sum; &minus; &lowast; &radic; &prop; &infin;
 * &ang; &and; &or; &cap; &cup; &int; &there4; &sim; &cong; &asymp; &ne; &equiv; &le; &ge;
 * &sub; &sup; &nsub; &sube; &supe; &oplus; &otimes; &perp; &sdot; &lceil; &rceil; &lfloor;
 * &rfloor; &lang; &rang; &loz; &spades; &clubs; &hearts; &diams; &OElig; &oelig; &Scaron;
 * &scaron; &Yuml; &circ; &tilde; &ensp; &emsp; &thinsp; &zwnj; &zwj; &lrm; &rlm; &ndash;
 * &mdash; &lsquo; &rsquo; &sbquo; &ldquo; &rdquo; &bdquo; &dagger; &Dagger; &permil; &lsaquo;
 * &rsaquo; &euro; &tm;
 */
void entities();

/** @brief Lists.
 *
 * - one
 * - two
 *   1. nested
 *   2. ordered
 * - three
 *
 * <ol type="a" start="3"><li>c</li><li>d</li></ol>
 *
 * - [ ] to do
 * - [x] done
 */
void lists();

/** @brief A table.
 *
 * <table>
 * <caption>The caption</caption>
 * <tr><th>Name</th><th>Value</th></tr>
 * <tr><td>one</td><td>1</td></tr>
 * <tr><td colspan="2">spanning</td></tr>
 * </table>
 *
 * | Left | Right |
 * |:-----|------:|
 * | a    | b     |
 */
void tables();

/** @brief Code.
 *
 * @code{.cpp}
 * int x = demo::markup::code(); // a comment
 * @endcode
 *
 * @verbatim
   verbatim   text <b>not bold</b>
   @endverbatim
 *
 * <pre>preformatted
 *   text</pre>
 */
int code();

/** @brief Formulas.
 *
 * Inline \f$ a^2 + b^2 = c^2 \f$, display
 * \f[ \int_0^1 x\,dx = \frac{1}{2} \f]
 * and an environment
 * \f{eqnarray*}{ a &=& b \\ c &=& d \f}
 */
void formulas();

/** @brief Images.
 *
 * A block image:
 * @image html diagram.png "The diagram"
 *
 * and an inline one, @image{inline} html diagram.png "inline", in a sentence.
 */
void images();

/** @brief Headings and anchors.
 *
 * @anchor block-anchor
 * ### A Markdown heading
 * <h4>An HTML heading</h4>
 * @par A paragraph title
 * The paragraph.
 */
void headings();

/** @brief Every simplesect kind.
 *
 * @see demo::Widget
 * @return a value
 * @author Ann
 * @authors Ann and Bob
 * @version 1.0
 * @since 0.9
 * @date 2026
 * @note A note.
 * @warning A warning.
 * @pre A precondition.
 * @post A postcondition.
 * @copyright Somebody.
 * @invariant An invariant.
 * @remark A remark.
 * @attention An attention.
 * @important An important point.
 * @par Custom title
 * A paragraph with a custom title.
 *
 * $Id: markup.hpp 1 $
 */
int simplesects();

/** @brief Parameters.
 *
 * @tparam T the type
 * @param[in] in an input
 * @param[out] out an output
 * @param[in,out] both both ways
 * @retval 0 success
 * @retval -1 failure
 * @throws std::runtime_error on error
 * @exception std::logic_error never
 */
template <typename T>
int parameters(T in, T* out, T& both);

/** @brief Blocks.
 *
 * <details><summary>More</summary>Hidden text.</details>
 *
 * <blockquote>A quote.</blockquote>
 *
 * > A Markdown quote.
 *
 * @parblock
 * The first paragraph of a block.
 *
 * The second paragraph.
 * @endparblock
 *
 * <dl><dt>Term</dt><dd>Its definition.</dd></dl>
 *
 * @htmlonly <b>HTML only</b> @endhtmlonly
 * @latexonly \textbf{LaTeX only} @endlatexonly
 * @manonly man only @endmanonly
 * @rtfonly rtf only @endrtfonly
 * @docbookonly docbook only @enddocbookonly
 *
 * @dot
 * digraph G { a -> b; }
 * @enddot
 *
 * @addindex indexed term
 * @~english English only. @~
 *
 * @internal
 * Internal documentation.
 * @endinternal
 */
void blocks();

/** @brief Cross-reference lists.
 *
 * @todo Something to do.
 * @bug A bug.
 * @deprecated Deprecated.
 * @test A test.
 * @xrefitem custom "Custom" "Custom items" A custom item.
 */
void xrefsects();

} // namespace markup
} // namespace demo
