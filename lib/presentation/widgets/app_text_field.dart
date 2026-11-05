import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

/// Styled text field matching design system
class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final IconData? icon;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool readOnly;
  final int? maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;
  final VoidCallback? onTap;
  final bool enabled;

  const AppTextField({
    Key? key,
    required this.label,
    this.hint,
    this.icon,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.focusNode,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.suffix,
    this.onTap,
    this.enabled = true,
  }) : super(key: key);

  static const Color _muted = Color(0xFF5F6B64);
  static const Color _line = Color(0xFFE3E8E5);
  static const Color _panel = Color(0xFFF7FAF8);

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1.2]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      textInputAction: textInputAction,
      focusNode: focusNode,
      readOnly: readOnly,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      onTap: onTap,
      enabled: enabled,
      style: const TextStyle(
        fontSize: 16,
        color: Color(0xFF212121),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: _muted),
        floatingLabelStyle: TextStyle(
          color: AppTheme.primaryGreen,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: icon != null
            ? Icon(icon, color: AppTheme.primaryGreen, size: 20)
            : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: _panel,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: border(_line),
        enabledBorder: border(_line),
        focusedBorder: border(AppTheme.primaryGreen, 2),
        errorBorder: border(AppTheme.errorRed),
        focusedErrorBorder: border(AppTheme.errorRed, 2),
        disabledBorder: border(_line.withOpacity(0.5)),
        counterText: '',
      ),
    );
  }
}
