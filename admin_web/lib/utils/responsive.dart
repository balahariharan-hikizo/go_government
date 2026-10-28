import 'package:flutter/material.dart';

/// Screen Breakpoint Definitions:
/// - Mobile: < 700 px (Smartphones)
/// - Tablet: 700 px - 1149 px (iPads, Tablets, Small Laptops)
/// - Desktop: >= 1150 px (Laptops, Monitors, 4K Screens)
class ResponsiveBreakpoints {
  static const double mobileMax = 700;
  static const double tabletMax = 1150;
}

/// Extension on BuildContext for quick and intuitive responsive queries
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  bool get isMobile => screenWidth < ResponsiveBreakpoints.mobileMax;
  bool get isTablet => screenWidth >= ResponsiveBreakpoints.mobileMax && screenWidth < ResponsiveBreakpoints.tabletMax;
  bool get isDesktop => screenWidth >= ResponsiveBreakpoints.tabletMax;

  /// Returns responsive value based on current breakpoint
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop) return desktop;
    if (isTablet) return tablet ?? mobile;
    return mobile;
  }
}

/// A responsive widget builder that renders appropriate UI for current screen size
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isDesktop) {
      return desktop;
    }
    if (context.isTablet) {
      return tablet ?? mobile;
    }
    return mobile;
  }
}
