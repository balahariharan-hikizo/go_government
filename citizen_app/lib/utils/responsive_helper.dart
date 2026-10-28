import 'package:flutter/material.dart';

class Responsive {
  static double screenWidth = _designWidth;
  static double screenHeight = _designHeight;

  // Design sizes from Figma (typically iPhone 14/15 Pro: 390 x 844)
  static const double _designWidth = 390.0;
  static const double _designHeight = 844.0;

  static void init(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    screenWidth = mediaQuery.size.width;
    screenHeight = mediaQuery.size.height;
  }

  /// Adjusts horizontal dimension (widths, horizontal paddings/margins)
  static double w(double width) {
    return (width / _designWidth) * screenWidth;
  }

  /// Adjusts vertical dimension (heights, vertical paddings/margins)
  static double h(double height) {
    return (height / _designHeight) * screenHeight;
  }

  /// Adjusts font sizes based on screen width scaling
  static double sp(double fontSize) {
    return (fontSize / _designWidth) * screenWidth;
  }
}
