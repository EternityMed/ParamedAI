import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ParaMed AI theme configuration with emergency medical color palette.
class ParamedTheme {
  ParamedTheme._();

  // Emergency colors
  static const Color emergencyRed = Color(0xFFE53935);
  static const Color triageRed = Color(0xFFD32F2F);
  static const Color triageYellow = Color(0xFFFFC107);
  static const Color triageGreen = Color(0xFF4CAF50);
  static const Color triageBlack = Color(0xFF212121);
  static const Color medicalBlue = Color(0xFF1E88E5);
  static const Color safeGreen = Color(0xFF43A047);
  static const Color warningOrange = Color(0xFFFF9800);

  // Light theme surfaces
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E6EA);
  static const Color textPrimary = Color(0xFF1A1D21);
  static const Color textSecondary = Color(0xFF656D76);

  /// Returns the appropriate color for a triage category.
  static Color triageColor(String category) {
    switch (category.toUpperCase()) {
      case 'RED':
      case 'IMMEDIATE':
        return triageRed;
      case 'YELLOW':
      case 'DELAYED':
        return triageYellow;
      case 'GREEN':
      case 'MINOR':
        return triageGreen;
      case 'BLACK':
      case 'DECEASED':
      case 'EXPECTANT':
        return triageBlack;
      default:
        return textSecondary;
    }
  }

  /// Light theme for the app.
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme(
      ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      colorScheme: const ColorScheme.light(
        primary: medicalBlue,
        secondary: safeGreen,
        error: emergencyRed,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: medicalBlue, width: 2),
        ),
        hintStyle: const TextStyle(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: medicalBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: medicalBlue.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12,
            color: textSecondary,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
    );
  }
}
