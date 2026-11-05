import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

/// Splash Screen - Professional design matching login/onboarding screens
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const String _poweredBy = 'Infinitech Innovations Ltd';
  static const Color _ink = Color(0xFF14231B);
  static const Color _muted = Color(0xFF5F6B64);
  static const Color _panel = Color(0xFFF7FAF8);
  static const Color _darkGreen = Color(0xFF0B2016);

  late final AnimationController _intro;
  late final AnimationController _progress;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _fade = CurvedAnimation(parent: _intro, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _intro, curve: Curves.easeOutBack),
    );

    _intro.forward();
    _progress.forward();
    _navigateToNextScreen();
  }

  @override
  void dispose() {
    _intro.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted || _hasNavigated) return;
    
    _hasNavigated = true;
    // Skip onboarding, go directly to login
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false, // Remove all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _panel,
                Colors.white,
                _panel,
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                final shortest = w < h ? w : h;

                final double logoSize = (shortest * 0.30).clamp(96.0, 180.0);
                final double nameSize = (shortest * 0.055).clamp(18.0, 30.0);
                final double divisionSize =
                    (shortest * 0.037).clamp(13.0, 20.0);
                final double locationSize =
                    (shortest * 0.03).clamp(12.0, 16.0);
                final double gap = (h * 0.04).clamp(14.0, 36.0);
                final double barWidth = (shortest * 0.5).clamp(140.0, 240.0);

                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Logo with green accent
                                  FadeTransition(
                                    opacity: _fade,
                                    child: ScaleTransition(
                                      scale: _scale,
                                      child: Container(
                                        width: logoSize,
                                        height: logoSize,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(logoSize * 0.25),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primaryGreen
                                                  .withOpacity(0.2),
                                              blurRadius: 30,
                                              spreadRadius: 2,
                                            ),
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.08),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(logoSize * 0.25),
                                          child: Image.asset(
                                            'assets/logo.jpg',
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stack) {
                                              return Icon(
                                                Icons.coffee,
                                                size: logoSize * 0.5,
                                                color: AppTheme.primaryGreen,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  SizedBox(height: gap),

                                  // Brand chip
                                  FadeTransition(
                                    opacity: _fade,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppTheme.primaryGreen.withOpacity(0.2),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.coffee,
                                            color: AppTheme.primaryGreen,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'COFFEE MANAGEMENT',
                                            style: TextStyle(
                                              color: AppTheme.primaryGreen,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  SizedBox(height: gap * 0.6),

                                  // Company text
                                  FadeTransition(
                                    opacity: _fade,
                                    child: Column(
                                      children: [
                                        Text(
                                          AppConstants.companyNameShort,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _ink,
                                            fontSize: nameSize,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                            height: 1.2,
                                          ),
                                        ),
                                        SizedBox(height: gap * 0.25),
                                        Text(
                                          AppConstants.companyDivision,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _muted,
                                            fontSize: divisionSize,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        SizedBox(height: gap * 0.15),
                                        Text(
                                          AppConstants.companyLocation,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _muted.withOpacity(0.7),
                                            fontSize: locationSize,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(height: gap * 1.6),

                                  // Progress bar - clean green style
                                  FadeTransition(
                                    opacity: _fade,
                                    child: SizedBox(
                                      width: barWidth,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: AnimatedBuilder(
                                          animation: _progress,
                                          builder: (context, _) =>
                                              LinearProgressIndicator(
                                            value: _progress.value,
                                            minHeight: 6,
                                            backgroundColor:
                                                AppTheme.primaryGreen.withOpacity(0.15),
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                    Color>(AppTheme.primaryGreen),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  FadeTransition(
                                    opacity: _fade,
                                    child: Text(
                                      'Initializing system...',
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Footer
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      child: FadeTransition(
                        opacity: _fade,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                ),
                                children: const [
                                  TextSpan(text: 'Powered by '),
                                  TextSpan(
                                    text: _poweredBy,
                                    style: TextStyle(
                                      color: AppTheme.primaryGreen,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Version 1.0.0',
                              style: TextStyle(
                                color: _muted.withOpacity(0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}