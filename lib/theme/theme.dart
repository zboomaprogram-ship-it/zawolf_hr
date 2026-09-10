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

  // --- Semantic aliases (specs/ui_redesign/01_design_system_spec.md) ---
  // Soft backgrounds for status surfaces; pair with the base status colors.
  static const Color successSoft = Color(0x1F7DDC8A);
  static const Color warningSoft = Color(0x1FE4B55D);
  static const Color errorSoft = Color(0x1FFF6B6B);
  static const Color info = Color(0xFF45F0FF);
  static const Color infoSoft = Color(0x1F45F0FF);
  static const Color surfaceElevated = surface03;
  static const Color disabled = Color(0xFF3A444E);
  static const Color onDisabled = Color(0xFF8A96A0);

  // Sheet-editor (workspace) semantic tokens — specs/ui_redesign/01.
  static const Color editorAccent = Color(0xFF41DDEB);
  static const Color editorActivated = Color(0xFF123B46);
  static const Color editorGridBorder = Color(0xFF34424A);
  static const Color editorCellEdit = Color(0xFF16252C);
  static const Color editorSurface = Color(0xFF11191E);
  static const Color editorSurfaceDeep = Color(0xFF0D1418);
  static const Color dangerDeep = Color(0xFFC62828);

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
        onPrimary: ZaWolfColors.background,
        primaryContainer: Color(0xFF164450),
        onPrimaryContainer: ZaWolfColors.textPrimary,
        secondary: ZaWolfColors.wolfGreen,
        onSecondary: ZaWolfColors.background,
        tertiary: ZaWolfColors.perfGold,
        surface: ZaWolfColors.surface01,
        onSurface: ZaWolfColors.textPrimary,
        surfaceContainerHighest: ZaWolfColors.surface03,
        onSurfaceVariant: ZaWolfColors.textSecondary,
        outline: ZaWolfColors.surface03,
        outlineVariant: ZaWolfColors.surface02,
        error: ZaWolfColors.error,
        onError: ZaWolfColors.background,
        errorContainer: ZaWolfColors.errorSoft,
      ),
      // Focus-visible ring: keyboard/web tab focus shows the brand accent
      // ring on every interactive component (specs/ui_redesign/04).
      focusColor: ZaWolfColors.primaryCyan.withValues(alpha: 0.45),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => Icon(
          Directionality.of(context) == TextDirection.rtl
              ? Icons.arrow_forward_rounded
              : Icons.arrow_back_rounded,
          textDirection: TextDirection.ltr,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        displaySmall: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
          fontSize: 15,
        ),
        bodyMedium: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textSecondary,
          fontSize: 14,
        ),
        bodySmall: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textMuted,
          fontSize: 12,
        ),
        labelLarge: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: GoogleFonts.ibmPlexSansArabic(
          color: ZaWolfColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
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
      datePickerTheme: DatePickerThemeData(
        backgroundColor: ZaWolfColors.surface01,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: ZaWolfColors.surface02,
        headerForegroundColor: Colors.white,
        dayForegroundColor: WidgetStateProperty.all(Colors.white),
        yearForegroundColor: WidgetStateProperty.all(Colors.white),
        todayForegroundColor: WidgetStateProperty.all(ZaWolfColors.primaryCyan),
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: ZaWolfColors.surface01,
        hourMinuteTextColor: Colors.white,
        hourMinuteColor: ZaWolfColors.surface02,
        dayPeriodTextColor: Colors.white,
        dayPeriodColor: ZaWolfColors.surface02,
        dialHandColor: ZaWolfColors.primaryCyan,
        dialBackgroundColor: ZaWolfColors.surface02,
        dialTextColor: Colors.white,
      ),
    );
  }
}
