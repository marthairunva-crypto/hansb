import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

/// Service for handling SMS and phone calls
class SmsService {
  /// Send SMS to a phone number
  static Future<void> sendSMS({
    required String phoneNumber,
    String? message,
    BuildContext? context,
  }) async {
    try {
      // Clean phone number (remove spaces, dashes, etc.)
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Build SMS URI
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: cleanPhone,
        queryParameters: message != null && message.isNotEmpty
            ? {'body': message}
            : null,
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        if (context != null && context.mounted) {
          _showError(context, 'Could not open messaging app');
        }
      }
    } catch (e) {
      if (context != null && context.mounted) {
        _showError(context, 'Error: $e');
      }
    }
  }

  /// Make a phone call
  static Future<void> makeCall({
    required String phoneNumber,
    BuildContext? context,
  }) async {
    try {
      // Clean phone number
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      final Uri telUri = Uri(scheme: 'tel', path: cleanPhone);

      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      } else {
        if (context != null && context.mounted) {
          _showError(context, 'Could not open phone app');
        }
      }
    } catch (e) {
      if (context != null && context.mounted) {
        _showError(context, 'Error: $e');
      }
    }
  }

  /// Open WhatsApp chat
  static Future<void> openWhatsApp({
    required String phoneNumber,
    String? message,
    BuildContext? context,
  }) async {
    try {
      // Clean phone number and ensure it has country code
      var cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // If number doesn't start with +, assume it's Uganda (+256)
      if (!cleanPhone.startsWith('+')) {
        // Remove leading 0 if present
        if (cleanPhone.startsWith('0')) {
          cleanPhone = cleanPhone.substring(1);
        }
        cleanPhone = '256$cleanPhone'; // Uganda country code
      } else {
        cleanPhone = cleanPhone.substring(1); // Remove + for WhatsApp
      }
      
      final Uri whatsappUri = Uri.parse(
        'https://wa.me/$cleanPhone${message != null && message.isNotEmpty ? '?text=${Uri.encodeComponent(message)}' : ''}',
      );

      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        if (context != null && context.mounted) {
          _showError(context, 'WhatsApp is not installed');
        }
      }
    } catch (e) {
      if (context != null && context.mounted) {
        _showError(context, 'Error: $e');
      }
    }
  }

  /// Show error message
  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
