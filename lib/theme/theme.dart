import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZaWolfColors {
  static const Color background = Color(0xFF07070F);
  static const Color surface01 = Color(0xFF0F1020);
  static const Color surface02 = Color(0xFF171830);

  static const Color primaryCyan = Color(0xFF00D4FF);
  static const Color primaryBlue = Color(0xFF0073FF);

  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFB300);
  static const Color error = Color(0xFFFF3D3D);

  static const Color permissionTeal = Color(0xFF00BFA5);
  static const Color dayoffPurple = Color(0xFF7C4DFF);
  static const Color perfGold = Color(0xFFFFC107);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8BA3C7);
  static const Color textMuted = Color(0xFF4A5A74);

  static const Color borderGlow = Color(0x2200D4FF); // 8% opacity

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryCyan, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient permissionGradient = LinearGradient(
    colors: [permissionTeal, Color(0xFF00796B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dayoffGradient = LinearGradient(
    colors: [dayoffPurple, Color(0xFF512DA8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const BoxShadow wolfGlow = BoxShadow(
    color: Color(0x2600D4FF), // 15% opacity primary cyan
    blurRadius: 20,
    offset: Offset(0, 0),
  );
}

class ZaWolfTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: ZaWolfColors.primaryCyan,
      scaffoldBackgroundColor: ZaWolfColors.background,
      cardColor: ZaWolfColors.surface01,
      colorScheme: const ColorScheme.dark(
        primary: ZaWolfColors.primaryCyan,
        secondary: ZaWolfColors.primaryBlue,
        surface: ZaWolfColors.surface01,
        error: ZaWolfColors.error,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.rajdhani(
          color: ZaWolfColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.rajdhani(
          color: ZaWolfColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: GoogleFonts.rajdhani(
          color: ZaWolfColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: GoogleFonts.rajdhani(
          color: ZaWolfColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.rajdhani(
          color: ZaWolfColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: GoogleFonts.rajdhani(
          color: ZaWolfColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.inter(
          color: ZaWolfColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.inter(
          color: ZaWolfColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.inter(color: ZaWolfColors.textPrimary),
        bodyMedium: GoogleFonts.inter(color: ZaWolfColors.textSecondary),
        bodySmall: GoogleFonts.inter(color: ZaWolfColors.textMuted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ZaWolfColors.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: ZaWolfColors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZaWolfColors.surface01,
        hintStyle: GoogleFonts.inter(color: ZaWolfColors.textMuted),
        labelStyle: GoogleFonts.inter(color: ZaWolfColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ZaWolfColors.surface02),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ZaWolfColors.surface02),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: ZaWolfColors.primaryCyan,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ZaWolfColors.error),
        ),
      ),
    );
  }
}
