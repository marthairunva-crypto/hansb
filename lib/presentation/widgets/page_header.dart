import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';

/// Page header with title, subtitle, and optional action
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;

  const PageHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.icon,
    this.action,
  }) : super(key: key);

  static const Color _ink = Color(0xFF14231B);
  static const Color _muted = Color(0xFF5F6B64);

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: Responsive.verticalPadding(context),
      ),
      child: isDesktop && action != null
          ? Row(
              children: [
                Expanded(child: _content(isDesktop)),
                const SizedBox(width: 16),
                action!,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _content(isDesktop),
                if (action != null) ...[
                  const SizedBox(height: 16),
                  action!,
                ],
              ],
            ),
    );
  }

  Widget _content(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: isDesktop ? 24 : 20,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.only(left: icon != null ? 54 : 0),
            child: Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 14,
                color: _muted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
