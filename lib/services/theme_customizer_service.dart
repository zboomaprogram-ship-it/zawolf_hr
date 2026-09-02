import 'package:flutter/material.dart';

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
      nameArabic: 'سيبان سيبراني',
      nameEnglish: 'Cyber Cyan',
      primary: Color(0xFF38BDF8),
      accentGlow: Color(0xFF0EA5E9),
      cardBorder: Color(0x6638BDF8),
      textAccent: Color(0xFF7DD3FC),
    ),
    ThemePalette(
      key: 'violet',
      nameArabic: 'بنفسجي ملكي',
      nameEnglish: 'Royal Violet',
      primary: Color(0xFFA78BFA),
      accentGlow: Color(0xFF8B5CF6),
      cardBorder: Color(0x66A78BFA),
      textAccent: Color(0xFFC4B5FD),
    ),
    ThemePalette(
      key: 'amber',
      nameArabic: 'ذهبي عنبري',
      nameEnglish: 'Amber Gold',
      primary: Color(0xFFFBBF24),
      accentGlow: Color(0xFFF59E0B),
      cardBorder: Color(0x66FBBF24),
      textAccent: Color(0xFFFDE68A),
    ),
    ThemePalette(
      key: 'emerald',
      nameArabic: 'أخضر زمردي',
      nameEnglish: 'Emerald Green',
      primary: Color(0xFF10B981),
      accentGlow: Color(0xFF059669),
      cardBorder: Color(0x6610B981),
      textAccent: Color(0xFF6EE7B7),
    ),
    ThemePalette(
      key: 'orange',
      nameArabic: 'برتقالي الغروب',
      nameEnglish: 'Sunset Orange',
      primary: Color(0xFFF97316),
      accentGlow: Color(0xFFEA580C),
      cardBorder: Color(0x66F97316),
      textAccent: Color(0xFFFDBA74),
    ),
    ThemePalette(
      key: 'rose',
      nameArabic: 'وردي ياقوتي',
      nameEnglish: 'Ruby Red',
      primary: Color(0xFFFB7185),
      accentGlow: Color(0xFFE11D48),
      cardBorder: Color(0x66FB7185),
      textAccent: Color(0xFFFDA4AF),
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
