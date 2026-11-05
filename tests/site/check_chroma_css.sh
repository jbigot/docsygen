#!/bin/sh
# SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
# SPDX-License-Identifier: MIT
# Check that a built site with Chroma's classes (markup.highlight.noClasses: false) styles them:
# its CSS must hold the rules of Chroma's tokens, as Docsy's `@import 'td/code-dark'` gives.
#
# Usage: sh tests/site/check_chroma_css.sh PUBLIC_DIR
set -eu

public=$1
# A site whose code blocks carry no `chroma` class has nothing to style.
grep -rlq --include='*.html' 'class="chroma' "$public" || exit 0
# Chroma's stylesheets hold one rule per token type: a few dozen at least.
rules=$(find "$public" -name '*.css' -exec grep -oh '\.chroma [^{]*{' {} + | wc -l)
if [ "$rules" -lt 20 ]; then
  echo "check_chroma_css: code blocks use Chroma's classes but the site's CSS has $rules .chroma rules" >&2
  echo "  (Docsy: add \`@import 'td/code-dark';\` to assets/scss/_styles_project.scss)" >&2
  exit 1
fi
