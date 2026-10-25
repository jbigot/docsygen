/** @file
 *  @brief Shapes, to exercise inheritance.
 */
#pragma once
#include "widget.hpp"

namespace demo {

/// The base of all shapes.
class Shape {
public:
  /// Destroys the shape.
  virtual ~Shape();
  /// The area of the shape.
  virtual double area() const = 0;
};

/// Something with a name.
class Named {
public:
  /// The name.
  const char* name() const;
};

/// A circle, which inherits publicly.
class Circle : public Shape {
public:
  /// The area of the circle.
  double area() const override;
  /// The radius.
  double radius;
};

/// A labelled circle, which inherits from several bases.
class LabelledCircle : public Circle, protected Named {
public:
  /// The label.
  const char* label() const;
};

/// The left side of a diamond, which inherits virtually.
class Left : public virtual Shape {};

/// The right side of a diamond, which inherits virtually.
class Right : public virtual Shape {};

/// The bottom of a diamond.
class Diamond : public Left, public Right {
public:
  /// The area of the diamond.
  double area() const override;
};

/// A widget that can be pressed.
class Button : public Widget {
public:
  /// Draws the button.
  void draw() const override;
  /// Presses the button.
  void press();
};

} // namespace demo
