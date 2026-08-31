import 'package:flutter/material.dart';

import '../../../components/wolf_card.dart';
import '../../../theme/theme.dart';
import '../../../design_system/tokens.dart';

/// Accent-colored quick-action tile used on the employee dashboard.
/// Uses the shared `WolfCard` recipe per specs/ui_redesign/06 R1.
class EmployeeQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const EmployeeQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: WolfCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: DsSpacing.lg),
        child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: DsSpacing.sm),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle.toUpperCase(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ZaWolfColors.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
      ),
    );
  }
}

/// Maps an attendance record status to the shared semantic status.
DsStatus attendanceStatusToDsStatus(String status) {
  switch (status) {
    case 'present':
      return DsStatus.present;
    case 'late':
      return DsStatus.late;
    case 'on-leave':
      return DsStatus.neutral; // on-leave keeps its blue accent downstream
    case 'absent':
      return DsStatus.absent;
    default:
      return DsStatus.neutral;
  }
}
