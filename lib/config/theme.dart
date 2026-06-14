import 'package:flutter/material.dart';

/// Calm, high-contrast clinical theme. Soft teal primary with warm accents,
/// large touch targets suited to gloved hands and older staff devices.
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF1F7A8C);
  static const Color primaryDark = Color(0xFF14505C);
  static const Color accent = Color(0xFFE07A5F);
  static const Color bg = Color(0xFFF4F7F8);
  static const Color surface = Colors.white;

  // Semantic status colours used by vitals, alerts, rounds.
  static const Color ok = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color critical = Color(0xFFC62828);
  static const Color info = Color(0xFF1565C0);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      visualDensity: VisualDensity.comfortable,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD7E0E2)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF1F7A8C).withValues(alpha: 0.15),
        side: const BorderSide(color: Color(0xFFB0BEC5)),
        checkmarkColor: const Color(0xFF1F7A8C),
      ),
    );
  }

  /// Map a severity string to a colour.
  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'high':
        return critical;
      case 'warning':
      case 'medium':
        return warning;
      case 'info':
      case 'low':
        return info;
      default:
        return ok;
    }
  }
}
