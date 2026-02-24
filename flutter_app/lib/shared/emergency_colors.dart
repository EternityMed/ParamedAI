import 'package:flutter/material.dart';

/// Emergency color constants and utility helpers.
class EmergencyColors {
  EmergencyColors._();

  // Triage categories
  static const Color triageImmediate = Color(0xFFD32F2F);
  static const Color triageDelayed = Color(0xFFFFC107);
  static const Color triageMinor = Color(0xFF4CAF50);
  static const Color triageExpectant = Color(0xFF212121);

  // Severity levels
  static const Color critical = Color(0xFFE53935);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF1E88E5);
  static const Color success = Color(0xFF43A047);

  // Vital sign status
  static const Color vitalNormal = Color(0xFF43A047);
  static const Color vitalAbnormal = Color(0xFFFF9800);
  static const Color vitalCritical = Color(0xFFE53935);

  /// Returns a color based on severity string.
  static Color fromSeverity(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return critical;
      case 'WARNING':
        return warning;
      case 'INFO':
        return info;
      case 'SUCCESS':
        return success;
      default:
        return info;
    }
  }

  /// Returns triage color from category.
  static Color fromTriageCategory(String category) {
    switch (category.toUpperCase()) {
      case 'RED':
      case 'IMMEDIATE':
        return triageImmediate;
      case 'YELLOW':
      case 'DELAYED':
        return triageDelayed;
      case 'GREEN':
      case 'MINOR':
        return triageMinor;
      case 'BLACK':
      case 'EXPECTANT':
        return triageExpectant;
      default:
        return Colors.grey;
    }
  }

  /// Returns appropriate text color for a background color.
  static Color textColorOn(Color background) {
    return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}
