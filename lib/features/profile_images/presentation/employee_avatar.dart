import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../theme/theme.dart';

/// A resilient identity avatar shared by employee-facing surfaces.
///
/// It supports existing HTTPS URLs and the legacy bounded data-image value
/// while every caller keeps a deterministic initials fallback.
class EmployeeAvatar extends StatelessWidget {
  const EmployeeAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 40,
    this.ringColor,
  });

  final String name;
  final String? photoUrl;
  final double size;
  final Color? ringColor;

  String get _initials {
    final parts =
        name
            .trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList();
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) return parts.first.characters.first;
    return '${parts.first.characters.first}${parts.last.characters.first}';
  }

  Uint8List? get _legacyDataImage {
    final value = photoUrl?.trim() ?? '';
    final separator = value.indexOf(',');
    if (!value.startsWith('data:image/') || separator < 0) return null;
    try {
      return Uint8List.fromList(base64Decode(value.substring(separator + 1)));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _legacyDataImage;
    final url = photoUrl?.trim() ?? '';
    final fallback = Text(
      _initials,
      style: TextStyle(
        color: ringColor ?? ZaWolfColors.primaryCyan,
        fontSize: size * .36,
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ZaWolfColors.surface02,
        shape: BoxShape.circle,
        border:
            ringColor == null ? null : Border.all(color: ringColor!, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          image != null
              ? Image.memory(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
              : url.startsWith('https://')
              ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
              : fallback,
    );
  }
}
