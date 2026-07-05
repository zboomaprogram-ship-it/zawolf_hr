import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZaWolfColors {
  static const Color background = Color(0xFF050607);
  static const Color surface01 = Color(0xFF101418);
  static const Color surface02 = Color(0xFF1A2027);
  static const Color surface03 = Color(0xFF222B34);

  static const Color primaryCyan = Color(0xFF45F0FF);
  static const Color primaryBlue = Color(0xFF166C8C);
  static const Color wolfGreen = Color(0xFF8FE388);
  static const Color steel = Color(0xFF9AA9B5);

  static const Color success = Color(0xFF7DDC8A);
  static const Color warning = Color(0xFFE4B55D);
  static const Color error = Color(0xFFFF6B6B);

  static const Color permissionTeal = Color(0xFF4FC3B2);
  static const Color dayoffPurple = Color(0xFF7D8CFF);
  static const Color perfGold = Color(0xFFE7C66A);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA8B3BD);
  static const Color textMuted = Color(0xFF64717D);

  static const Color borderGlow = Color(0x2445F0FF);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryCyan, Color(0xFF6AF2BC), primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient permissionGradient = LinearGradient(
    colors: [permissionTeal, Color(0xFF00796B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dayoffGradient = LinearGradient(
    colors: [dayoffPurple, Color(0xFF394166)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const BoxShadow wolfGlow = BoxShadow(
    color: Color(0x1F45F0FF),
    blurRadius: 24,
    offset: Offset(0, 10),
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
        secondary: ZaWolfColors.wolfGreen,
        surface: ZaWolfColors.surface01,
        error: ZaWolfColors.error,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        displaySmall: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textSecondary,
        ),
        bodySmall: GoogleFonts.ibmPlexSansArabic(color: ZaWolfColors.textMuted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ZaWolfColors.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: ZaWolfColors.textPrimary),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZaWolfColors.surface02,
        hintStyle: GoogleFonts.ibmPlexSansArabic(color: ZaWolfColors.textMuted),
        labelStyle: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ZaWolfColors.surface02),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ZaWolfColors.surface03),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: ZaWolfColors.primaryCyan,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ZaWolfColors.error),
        ),
      ),
      dividerTheme: const DividerThemeData(color: ZaWolfColors.surface03),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ZaWolfColors.surface02,
        contentTextStyle: GoogleFonts.ibmPlexSansArabic(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ZaWolfColors.surface01,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
