import 'package:flutter/material.dart';

/// Lets any screen make sure it is shown INSIDE the dashboard's content panel
/// (sidebar stays visible), no matter how the caller opened it
/// (Navigator.push, rootNavigator, or showDialog).
///
/// Put this file at: lib/core/utils/dashboard_host.dart
class DashboardHost {
  DashboardHost._();

  /// Navigator that hosts the dashboard's content area (desktop layout only).
  static final GlobalKey<NavigatorState> contentNav =
      GlobalKey<NavigatorState>();

  /// Call from initState() of a screen that should live inside the dashboard.
  /// If the screen was opened on a different navigator (full screen / dialog),
  /// it closes that copy and reopens the same screen inside the dashboard panel.
  /// On phones (no content navigator) it does nothing.
  static void keepInside(BuildContext context, Widget screen) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final inner = contentNav.currentState;
      if (inner == null) return; // phone layout or dashboard not showing
      final current = Navigator.of(context);
      if (identical(current, inner)) return; // already inside the dashboard
      current.pop(); // close the full-screen / dialog copy
      inner.push(MaterialPageRoute(builder: (_) => screen));
    });
  }
}
