import 'package:flutter/material.dart';
import '../theme/theme.dart';

final class ThemePalette {
  final String key;
  final String nameArabic;
  final String nameEnglish;
  final Color primary;
  final Color accentGlow;
  final Color cardBorder;
  final Color textAccent;

  const ThemePalette({
    required this.key,
    required this.nameArabic,
    required this.nameEnglish,
    required this.primary,
    required this.accentGlow,
    required this.cardBorder,
    required this.textAccent,
  });
}

final class ThemeCustomizerService {
  ThemeCustomizerService._();
  static final instance = ThemeCustomizerService._();

  static const List<ThemePalette> availableThemes = [
    ThemePalette(
      key: 'cyan',
      nameArabic: 'سيبان زاولف',
      nameEnglish: 'ZaWolf Cyan',
      primary: ZaWolfColors.primaryCyan,
      accentGlow: ZaWolfColors.primaryBlue,
      cardBorder: Color(0x6645F0FF),
      textAccent: ZaWolfColors.primaryCyan,
    ),
    ThemePalette(
      key: 'violet',
      nameArabic: 'بنفسجي الإجازات',
      nameEnglish: 'Dayoff Purple',
      primary: ZaWolfColors.dayoffPurple,
      accentGlow: Color(0xFF5B6BEE),
      cardBorder: Color(0x667D8CFF),
      textAccent: Color(0xFFA6B0FF),
    ),
    ThemePalette(
      key: 'amber',
      nameArabic: 'ذهبي التميز',
      nameEnglish: 'Performance Gold',
      primary: ZaWolfColors.perfGold,
      accentGlow: ZaWolfColors.warning,
      cardBorder: Color(0x66E7C66A),
      textAccent: Color(0xFFF3DE9C),
    ),
    ThemePalette(
      key: 'emerald',
      nameArabic: 'أخضر الذئب',
      nameEnglish: 'Wolf Green',
      primary: ZaWolfColors.wolfGreen,
      accentGlow: ZaWolfColors.success,
      cardBorder: Color(0x668FE388),
      textAccent: Color(0xFFB4F0B0),
    ),
    ThemePalette(
      key: 'teal',
      nameArabic: 'أزرق الأذونات',
      nameEnglish: 'Permission Teal',
      primary: ZaWolfColors.permissionTeal,
      accentGlow: Color(0xFF35A595),
      cardBorder: Color(0x664FC3B2),
      textAccent: Color(0xFF86DCD0),
    ),
    ThemePalette(
      key: 'rose',
      nameArabic: 'أحمر التنبيهات',
      nameEnglish: 'Alert Red',
      primary: ZaWolfColors.error,
      accentGlow: Color(0xFFE54D4D),
      cardBorder: Color(0x66FF6B6B),
      textAccent: Color(0xFFFF9E9E),
    ),
  ];

  ThemePalette getPalette(String? key) {
    final cleanKey = (key ?? 'cyan').trim().toLowerCase();
    return availableThemes.firstWhere(
      (theme) => theme.key == cleanKey,
      orElse: () => availableThemes.first,
    );
  }
}
