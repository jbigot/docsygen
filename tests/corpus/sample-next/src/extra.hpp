// SPDX-FileCopyrightText: 2026 Julien Bigot <julien@julien-bigot.fr>
// SPDX-License-Identifier: MIT
/// @file
/// @brief What the release after the sample adds.
#pragma once

namespace demo {

/// @brief A class that only the later release has.
/// @details It links to Widget, which both releases document.
class Extra {
public:
  /// @brief The only member.
  int value() const;
};

}  // namespace demo
