import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors: Vibrant Sky Blue & Pure White
  static const Color primarySkyBlue = Color(0xFF0284C7); // Sky Blue
  static const Color lightSkyBlue = Color(0xFF38BDF8);   // Soft Sky Blue
  static const Color primaryBlue = Color(0xFF0284C7);    // Sky Blue
  static const Color primaryTeal = Color(0xFF0284C7);    // Sky Blue (for backwards compatibility across screens)
  static const Color accentGreen = Color(0xFF38BDF8);
  static const Color darkText = Color(0xFF0F172A);
  static const Color mutedText = Color(0xFF64748B);
  static const Color lightBg = Color(0xFFF0F9FF);        // Soft Sky Tint White
  static const Color cardBg = Colors.white;             // Pure White
  static const Color errorRed = Color(0xFFEF4444);

  static LinearGradient primaryGradient = const LinearGradient(
    colors: [primarySkyBlue, lightSkyBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      primaryColor: primarySkyBlue,
      scaffoldBackgroundColor: lightBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primarySkyBlue,
        primary: primarySkyBlue,
        secondary: lightSkyBlue,
        tertiary: lightSkyBlue,
        surface: cardBg,
        error: errorRed,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: darkText,
        iconTheme: IconThemeData(color: darkText),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 2,
        shadowColor: primarySkyBlue.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: TextStyle(color: mutedText.withValues(alpha: 0.7), fontSize: 14),
        labelStyle: const TextStyle(color: darkText, fontSize: 14, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBAE6FD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBAE6FD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primarySkyBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          backgroundColor: primarySkyBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: primarySkyBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: primarySkyBlue,
          ),
        ),
      ),
    );
  }
}
