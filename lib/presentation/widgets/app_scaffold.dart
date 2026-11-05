import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/responsive.dart';

/// Responsive scaffold with consistent header and footer
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showLogo;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const AppScaffold({
    Key? key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.showLogo = true,
    this.showBackButton = false,
    this.onBackPressed,
  }) : super(key: key);

  static const Color _ink = Color(0xFF14231B);
  static const Color _panel = Color(0xFFF7FAF8);
  static const Color _line = Color(0xFFE3E8E5);
  static const Color _muted = Color(0xFF5F6B64);

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: _panel,
      body: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _line, width: 1)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.horizontalPadding(context),
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    if (showBackButton)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                        color: _ink,
                      ),
                    if (showLogo && isDesktop) ...[
                      _logo(36),
                      const SizedBox(width: 12),
                      Text(
                        AppConstants.companyNameShort,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Container(
                        width: 1,
                        height: 24,
                        color: _line,
                      ),
                      const SizedBox(width: 24),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: isDesktop ? 18 : 16,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                    if (actions != null) ...actions!,
                  ],
                ),
              ),
            ),
          ),

          // Body
          Expanded(child: body),

          // Footer
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _line, width: 1)),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.horizontalPadding(context),
              vertical: 12,
            ),
            child: _footer(isDesktop),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _footer(bool isDesktop) {
    final powered = Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 12, color: _muted),
        children: [
          const TextSpan(text: 'Powered by '),
          TextSpan(
            text: 'Infinitech Innovations Ltd',
            style: TextStyle(
              color: AppTheme.primaryGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    const version = Text(
      'Version 1.0.0',
      style: TextStyle(fontSize: 12, color: _muted),
    );

    if (isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [version, powered],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [powered, const SizedBox(height: 4), version],
    );
  }

  Widget _logo(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.asset(
          'assets/logo.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.coffee,
            size: size * 0.55,
            color: AppTheme.primaryGreen,
          ),
        ),
      ),
    );
  }
}
