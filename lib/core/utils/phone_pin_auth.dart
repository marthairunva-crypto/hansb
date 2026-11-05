/// Phone number + PIN login on top of Firebase email/password auth.
///
/// Firebase Auth only understands email + password, so a phone number is turned
/// into a hidden email address and the PIN into a password. THIS FILE IS THE
/// SINGLE SOURCE OF TRUTH: any place that creates or resets a user account
/// (e.g. User Management, default admin setup) must use [emailFor] and
/// [passwordFor] so that the account can sign in with phone + PIN.
///
/// Put this file at: lib/core/utils/phone_pin_auth.dart
class PhonePinAuth {
  PhonePinAuth._();

  /// Hidden email domain used for phone accounts. Change once, here, if needed.
  static const String emailDomain = ''; // No domain, just phone number

  /// Suffix added to the PIN because Firebase needs passwords of 6+ characters
  /// (so 4-digit PINs work too).
  static const String _pinSuffix = '@HansB';

  static const int minPinLength = 4;
  static const int maxPinLength = 6;

  /// "0700 123 456", "+256 700 123 456", "700123456" -> "0778474686" (keeps original format)
  static String normalizePhone(String input) {
    // Remove all spaces and special characters except digits
    final digits = input.replaceAll(RegExp(r'[^\d]'), '');
    
    // If starts with +256, remove it and add 0
    if (input.startsWith('+256')) {
      return '0${digits.substring(3)}';
    }
    
    // If already starts with 0, keep as is
    if (digits.startsWith('0')) {
      return digits;
    }
    
    // If 9 digits (no country code, no leading 0), add 0
    if (digits.length == 9) {
      return '0$digits';
    }
    
    // Otherwise return as is
    return digits;
  }

  static bool isValidPhone(String input) {
    final n = normalizePhone(input);
    // Uganda phone: starts with 0, then 10 digits total (like 0778474686)
    return n.startsWith('0') && n.length == 10;
  }

  static bool isValidPin(String pin) {
    return RegExp(r'^\d+$').hasMatch(pin) &&
        pin.length >= minPinLength &&
        pin.length <= maxPinLength;
  }

  /// Email used behind the scenes for this phone number.
  static String emailFor(String phone) {
    final normalized = normalizePhone(phone);
    // Return just phone number if no domain, otherwise add @domain
    return emailDomain.isEmpty ? normalized : '$normalized@$emailDomain';
  }

  /// Firebase password used behind the scenes for this PIN.
  static String passwordFor(String pin) => '$pin$_pinSuffix';
}
