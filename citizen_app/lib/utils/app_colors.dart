import 'package:flutter/material.dart';

class AppColors {
  // Prevent instantiation
  AppColors._();

  // Primary branding colors from Figma
  static const Color primary = Color(0xFFF3410B); // Primary color (Orange-Red)
  static const Color outliner = Color(0xFFFFA88E); // Out liner (Warm peach outline)
  static const Color screenColor = Color(0xFFFFF8F5); // Screen color (Warm cream background)
  
  // Neutral colors
  static const Color black = Color(0xFF1E1E1E); // Black font/headings
  static const Color white = Color(0xFFFFFFFF); // White card background
  static const Color lightGray = Color(0xFFF5F5F5); // Light gray
  static const Color grayFont = Color(0xFF7A7A7A); // Gray font
  
  // Feedback & Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA000);
}
