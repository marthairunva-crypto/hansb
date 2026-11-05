import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Status chip for displaying states (active, inactive, pending, etc.)
class StatusChip extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final bool small;

  const StatusChip({
    Key? key,
    required this.label,
    this.color,
    this.icon,
    this.small = false,
  }) : super(key: key);

  // Predefined status constructors
  factory StatusChip.active({bool small = false}) {
    return StatusChip(
      label: 'Active',
      color: AppTheme.successGreen,
      icon: Icons.check_circle_outline,
      small: small,
    );
  }

  factory StatusChip.inactive({bool small = false}) {
    return StatusChip(
      label: 'Inactive',
      color: const Color(0xFF757575),
      icon: Icons.cancel_outlined,
      small: small,
    );
  }

  factory StatusChip.pending({bool small = false}) {
    return StatusChip(
      label: 'Pending',
      color: AppTheme.warningAmber,
      icon: Icons.schedule_outlined,
      small: small,
    );
  }

  factory StatusChip.completed({bool small = false}) {
    return StatusChip(
      label: 'Completed',
      color: AppTheme.successGreen,
      icon: Icons.check_circle,
      small: small,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primaryGreen;
    final fontSize = small ? 11.0 : 12.0;
    final iconSize = small ? 14.0 : 16.0;
    final hPadding = small ? 8.0 : 10.0;
    final vPadding = small ? 4.0 : 6.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: chipColor),
            SizedBox(width: small ? 4 : 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}
