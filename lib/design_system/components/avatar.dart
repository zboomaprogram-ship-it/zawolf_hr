import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// Initials avatar with optional role-colored ring.
class DsAvatar extends StatelessWidget {
  const DsAvatar({
    required this.name,
    this.size = 40,
    this.ringColor,
    super.key,
  });

  final String name;
  final double size;
  final Color? ringColor;

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) return parts.first.characters.first;
    return '${parts.first.characters.first}${parts.last.characters.first}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ZaWolfColors.surface02,
        shape: BoxShape.circle,
        border: ringColor != null
            ? Border.all(color: ringColor!, width: 2)
            : null,
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: ringColor ?? ZaWolfColors.primaryCyan,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}
