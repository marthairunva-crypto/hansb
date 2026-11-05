import 'package:intl/intl.dart';

/// Utility class for formatting currency values with commas
class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat('#,###', 'en_US');
  
  /// Format a number with commas (e.g., 1234567 -> 1,234,567)
  static String format(double value, {int decimals = 0}) {
    if (decimals > 0) {
      final formatter = NumberFormat('#,###.#' + ('#' * (decimals - 1)), 'en_US');
      return formatter.format(value);
    }
    return _formatter.format(value.round());
  }
  
  /// Format currency with UGX prefix (e.g., UGX 1,234,567)
  static String formatUGX(double value, {int decimals = 0}) {
    return 'UGX ${format(value, decimals: decimals)}';
  }
  
  /// Format with abbreviated suffix for large numbers (e.g., 1.2M, 50K)
  static String formatCompact(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${_formatter.format((value / 1000).round())}K';
    }
    return _formatter.format(value.round());
  }
  
  /// Format currency with UGX prefix and compact notation
  static String formatUGXCompact(double value) {
    if (value >= 1000000) {
      return 'UGX ${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return 'UGX ${(value / 1000).toStringAsFixed(0)}K';
    }
    return formatUGX(value);
  }
}
