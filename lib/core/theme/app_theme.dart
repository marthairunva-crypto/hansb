import 'package:flutter/material.dart';

/// Light Clean Theme - AgriVision Style
/// Modern light UI with green accents for coffee management
class AppTheme {
  // Light Mode Colors - matching AgriVision design
  static const Color backgroundLight = Color(0xFFF5F5F5); // Light grey background
  static const Color surfaceWhite = Colors.white;
  static const Color primaryGreen = Color(0xFF2E7D32); // Forest green
  static const Color darkGreen = Color(0xFF1B5E20); // Darker green
  static const Color lightGreen = Color(0xFF81C784); // Light green
  static const Color accentGreen = Color(0xFF4CAF50); // Bright green for accents
  static const Color textDark = Color(0xFF1A1A1A); // Almost black
  static const Color textGrey = Color(0xFF757575); // Medium grey
  static const Color textLight = Color(0xFF9E9E9E); // Light grey
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color successGreen = Color(0xFF388E3C);
  static const Color warningAmber = Color(0xFFFFA000);
  static const Color infoBlue = Color(0xFF1976D2);
  
  // Legacy aliases for backward compatibility
  static const Color accentOrange = primaryGreen;
  static const Color lightOrange = lightGreen;
  static const Color darkBackground = backgroundLight;
  static const Color cardBackground = surfaceWhite;
  static const Color darkBrown = textDark;
  static const Color mediumBrown = backgroundLight;
  static const Color lightBrown = borderLight;
  static const Color borderBrown = borderLight;
  static const Color cardBrown = surfaceWhite;
  static const Color backgroundDark = backgroundLight;
  static const Color creamWhite = surfaceWhite;
  static const Color darkTeal = textDark;
  static const Color lightTeal = borderLight;
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Color Scheme
      colorScheme: ColorScheme.light(
        primary: primaryGreen,
        secondary: accentGreen,
        error: errorRed,
        surface: surfaceWhite,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textDark,
        onError: Colors.white,
        background: backgroundLight,
      ),
      
      // Scaffold
      scaffoldBackgroundColor: backgroundLight,
      
      // Text Selection Theme
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primaryGreen,
        selectionColor: primaryGreen.withOpacity(0.2),
        selectionHandleColor: primaryGreen,
      ),
      
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceWhite,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textDark),
      ),
      
      // Card - Clean with subtle shadow
      cardTheme: CardThemeData(
        elevation: 1,
        color: surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadowColor: Colors.black.withOpacity(0.08),
        margin: EdgeInsets.zero,
      ),
      
      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorRed),
        ),
        labelStyle: TextStyle(color: textGrey, fontSize: 14),
        hintStyle: TextStyle(color: textLight, fontSize: 14),
        prefixIconColor: textGrey,
        suffixIconColor: textGrey,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      
      // Elevated Button - Green pill style
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), // Pill shape
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      
      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textDark,
          side: BorderSide(color: borderLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: borderLight,
        thickness: 1,
      ),
      
      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceWhite,
        selectedItemColor: primaryGreen,
        unselectedItemColor: textGrey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      
      // Typography - Clean and modern
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textDark, height: 1.2),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textDark, height: 1.2),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: textDark, height: 1.2),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: textDark, height: 1.3),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textDark, height: 1.3),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textDark, height: 1.3),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textDark, height: 1.4),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark, height: 1.4),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark, height: 1.4),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: textDark, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textGrey, height: 1.5),
        bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: textLight, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textGrey),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textLight),
      ),
      
      // Primary text theme (same as main for light theme)
      primaryTextTheme: TextTheme(
        bodyLarge: TextStyle(fontSize: 16, color: textDark),
        bodyMedium: TextStyle(fontSize: 14, color: textDark),
      ),
    );
  }
}
