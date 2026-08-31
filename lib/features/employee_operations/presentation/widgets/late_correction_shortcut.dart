import 'package:flutter/material.dart';

import '../../../../theme/theme.dart';
import '../../domain/entities/deduction_explanation.dart';

/// Employee-only shortcut for attendance deductions that still have a usable
/// original check-in timestamp. Authorization is enforced again by the server.
final class LateCorrectionShortcut extends StatelessWidget {
  const LateCorrectionShortcut({
    required this.explanation,
    required this.onPressed,
    super.key,
  });

  final DeductionExplanation explanation;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!explanation.canRequestCorrection ||
        explanation.originalCheckIn == null) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: OutlinedButton.icon(
        key: ValueKey('late-correction-${explanation.attendanceId}'),
        onPressed: onPressed,
        icon: const Icon(Icons.edit_calendar_outlined),
        label: const Text('طلب تصحيح وقت الحضور'),
        style: OutlinedButton.styleFrom(
          foregroundColor: ZaWolfColors.primaryCyan,
        ),
      ),
    );
  }
}
