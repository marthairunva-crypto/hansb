import 'package:flutter/material.dart';

/// Responsive breakpoints and utilities
class Responsive {
  // Breakpoints
  static const double phone = 600;
  static const double tablet = 900;
  static const double desktop = 1200;

  /// Check if current width is phone
  static bool isPhone(BuildContext context) {
    return MediaQuery.of(context).size.width < phone;
  }

  /// Check if current width is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= phone && width < tablet;
  }

  /// Check if current width is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tablet;
  }

  /// Get current breakpoint name
  static String getBreakpoint(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < phone) return 'phone';
    if (width < tablet) return 'tablet';
    return 'desktop';
  }

  /// Get responsive value based on breakpoint
  static T value<T>({
    required BuildContext context,
    required T phone,
    T? tablet,
    T? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= Responsive.tablet) return desktop ?? tablet ?? phone;
    if (width >= Responsive.phone) return tablet ?? phone;
    return phone;
  }

  /// Get number of grid columns based on screen width
  static int gridColumns(BuildContext context, {int phone = 1, int tablet = 2, int desktop = 3}) {
    return value(context: context, phone: phone, tablet: tablet, desktop: desktop);
  }

  /// Get horizontal padding based on screen size
  static double horizontalPadding(BuildContext context) {
    return value(context: context, phone: 16, tablet: 24, desktop: 32);
  }

  /// Get vertical padding based on screen size
  static double verticalPadding(BuildContext context) {
    return value(context: context, phone: 16, tablet: 20, desktop: 24);
  }

  /// Get content max width for centered layouts
  static double maxContentWidth(BuildContext context) {
    return value(context: context, phone: double.infinity, tablet: 720, desktop: 1200);
  }
}
