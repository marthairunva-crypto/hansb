import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:device_preview/device_preview.dart';
import 'core/services/firebase_config.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/user_init_service.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home/dashboard_screen.dart';
import 'presentation/screens/branch/branch_selector_screen.dart';
import 'presentation/screens/branch/branch_management_screen.dart';

/// Runs an init task but never lets it block the app:
///  - errors are logged and ignored
///  - a task that hangs (no network, blocked request, etc.) is abandoned
///    after [timeout] so runApp() is always reached
Future<void> _safeInit(
  String name,
  Future<void> Function() task, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  try {
    await task().timeout(timeout);
  } on TimeoutException {
    debugPrint('Init timed out ($name) after ${timeout.inSeconds}s');
  } catch (e, st) {
    debugPrint('Init failed ($name): $e\n$st');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Transparent status bar (individual screens choose light/dark icons)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Firebase must be ready first (with a time limit)
  await _safeInit('Firebase', () => FirebaseConfig.initialize(),
      timeout: const Duration(seconds: 10));

  // Load user session (with a time limit)
  await _safeInit('Auth Service', () => AuthService.instance.initializeSession(),
      timeout: const Duration(seconds: 6));

  // Initialize notifications (with a time limit)
  await _safeInit('Notifications', () => NotificationService.instance.initialize(),
      timeout: const Duration(seconds: 5));

  // NOTE: orientation is not locked, so tablets, foldables and landscape
  // phones work with the responsive screens.

  runApp(
    DevicePreview(
      enabled: false, // set to true to preview different devices
      builder: (context) => const HansBCoffeeApp(),
    ),
  );

  // Not needed to show the UI, so it runs in the background AFTER the app is up
  unawaited(_safeInit(
      'Default admin', () => UserInitService.initializeDefaultAdmin(),
      timeout: const Duration(seconds: 20)));
}

/// Lets mouse / trackpad drag PageViews and lists on desktop & web
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class HansBCoffeeApp extends StatelessWidget {
  const HansBCoffeeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${AppConstants.companyName} - Coffee Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppTheme.primaryGreen,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.light(
          primary: AppTheme.primaryGreen,
          secondary: AppTheme.primaryGreen,
        ),
        useMaterial3: true,
      ),
      scrollBehavior: const AppScrollBehavior(),

      // Device Preview configuration (v1.x)
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,

      // Routes
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/branch-selector': (context) => const BranchSelectorScreen(),
        '/branch-management': (context) => const BranchManagementScreen(),
        '/home': (context) => const DashboardScreen(),
      },
    );
  }
}