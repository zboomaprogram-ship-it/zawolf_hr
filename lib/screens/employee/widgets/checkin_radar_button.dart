import 'package:flutter/material.dart';

import '../../../theme/theme.dart';
import '../../../design_system/tokens.dart';

/// The circular check-in/out radar button extracted from the employee
/// dashboard. Presentation only; gating decisions stay in the screen.
class CheckInRadarButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool disabled;
  final bool loading;
  final bool active;
  final VoidCallback onTap;

  /// True while checked-in (checkout phase) — drives the red accent ring.
  const CheckInRadarButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.disabled,
    required this.loading,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!disabled)
            Container(
              width: 176,
              height: 176,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (active ? ZaWolfColors.error : ZaWolfColors.success)
                      .withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
            ),
          GestureDetector(
            onTap: disabled || loading ? null : onTap,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ZaWolfColors.textPrimary.withValues(alpha: 0.12),
                ),
                gradient: disabled && !active
                    ? const LinearGradient(
                        colors: [
                          ZaWolfColors.surface03,
                          ZaWolfColors.surface01,
                        ],
                      )
                    : active
                    ? const LinearGradient(
                        colors: [
                          ZaWolfColors.error,
                          ZaWolfColors.dangerDeep,
                        ],
                      )
                    : ZaWolfColors.primaryGradient,
                boxShadow: disabled
                    ? []
                    : [
                        BoxShadow(
                          color: (active
                                  ? ZaWolfColors.error
                                  : ZaWolfColors.primaryCyan)
                              .withValues(alpha: 0.35),
                          blurRadius: 30,
                          spreadRadius: 1,
                          offset: const Offset(0, 14),
                        ),
                      ],
              ),
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: ZaWolfColors.textPrimary,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 44, color: ZaWolfColors.textPrimary),
                        const SizedBox(height: DsSpacing.sm),
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: ZaWolfColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            shadows: const [
                              Shadow(
                                color: Color(0x99000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ZaWolfColors.textPrimary.withValues(alpha: 0.85),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            shadows: const [
                              Shadow(
                                color: Color(0x99000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
