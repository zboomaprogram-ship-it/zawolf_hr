import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../theme/theme.dart';
import '../../components/wolf_button.dart';

class CheckInConfirmModal extends StatelessWidget {
  final bool isCheckOut;
  final DateTime time;
  final String locationName;
  final String status; // 'present' | 'late' | 'checkout'
  final int lateMinutes;

  const CheckInConfirmModal({
    super.key,
    required this.isCheckOut,
    required this.time,
    required this.locationName,
    required this.status,
    this.lateMinutes = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('hh:mm a', 'ar').format(time);

    String titleText = isCheckOut ? 'تم تسجيل الانصراف ✓' : 'تم تسجيل الحضور ✓';
    String titleEnglish = isCheckOut ? 'CHECK-OUT LOGGED' : 'CHECK-IN LOGGED';
    Color accentColor = isCheckOut ? ZaWolfColors.error : ZaWolfColors.success;

    return Dialog(
      backgroundColor: ZaWolfColors.surface01,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accentColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated pulse icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.1),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                isCheckOut ? Icons.logout : Icons.check_circle_outline,
                color: accentColor,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              titleText,
              style: theme.textTheme.headlineMedium!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              titleEnglish,
              style: theme.textTheme.bodySmall!.copyWith(
                color: ZaWolfColors.textMuted,
                letterSpacing: 1.0,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Info Table
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ZaWolfColors.surface02,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow('الوقت / Time', timeStr, theme),
                  const Divider(color: ZaWolfColors.surface01, height: 20),
                  _buildInfoRow('الموقع / Location', locationName, theme),
                  if (!isCheckOut) ...[
                    const Divider(color: ZaWolfColors.surface01, height: 20),
                    _buildInfoRow(
                      'الحالة / Status',
                      status == 'late'
                          ? 'متأخر ($lateMinutes دقيقة)'
                          : 'في الميعاد (منضبط)',
                      theme,
                      valueColor: status == 'late'
                          ? ZaWolfColors.warning
                          : ZaWolfColors.success,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            WolfButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              text: 'موافق',
              secondaryText: 'DISMISS',
              variant: isCheckOut
                  ? WolfButtonVariant.outline
                  : WolfButtonVariant.primary,
              height: 50,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    ThemeData theme, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium!.copyWith(
            color: ZaWolfColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium!.copyWith(
            color: valueColor ?? Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
