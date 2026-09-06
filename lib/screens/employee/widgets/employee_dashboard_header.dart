import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../components/wolf_card.dart';
import '../../../design_system/components/avatar.dart';
import '../../../models/attendance_model.dart';
import '../../../models/attendance_policy.dart';
import '../../../models/user_model.dart';
import '../../../services/geofence_service.dart';
import '../../../design_system/bidi.dart';
import '../../../theme/theme.dart';

/// Dashboard greeting card: tappable geofence status chip + identity.
class EmployeeDashboardHeader extends StatelessWidget {
  const EmployeeDashboardHeader({
    required this.user,
    required this.geofenceResult,
    required this.checkingLocation,
    required this.onRetryGeofence,
    super.key,
  });

  final UserModel user;
  final GeofenceResult? geofenceResult;
  final bool checkingLocation;
  final VoidCallback onRetryGeofence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locationChip = InkWell(
      onTap: checkingLocation ? null : onRetryGeofence,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: (geofenceResult?.isWithinZone == true
                  ? ZaWolfColors.success
                  : ZaWolfColors.error)
              .withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (geofenceResult?.isWithinZone == true
                    ? ZaWolfColors.success
                    : ZaWolfColors.error)
                .withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (checkingLocation)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ZaWolfColors.primaryCyan,
                ),
              )
            else
              Icon(
                geofenceResult?.isWithinZone == true
                    ? Icons.location_on
                    : Icons.location_off,
                size: 16,
                color:
                    geofenceResult?.isWithinZone == true
                        ? ZaWolfColors.success
                        : ZaWolfColors.error,
              ),
            const SizedBox(width: 6),
            Text(
              checkingLocation
                  ? 'جاري التحديد'
                  : geofenceResult?.isWithinZone == true
                  ? 'داخل النطاق'
                  : 'خارج النطاق',
              style:
                  theme.textTheme.bodySmall?.copyWith(
                    color:
                        geofenceResult?.isWithinZone == true
                            ? ZaWolfColors.success
                            : ZaWolfColors.error,
                    fontWeight: FontWeight.w700,
                  ) ??
                  TextStyle(
                    color:
                        geofenceResult?.isWithinZone == true
                            ? ZaWolfColors.success
                            : ZaWolfColors.error,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'مرحباً، ${user.displayName}',
          style:
              theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontSize: 22,
              ) ??
              const TextStyle(color: Colors.white, fontSize: 22),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.rtl,
        ),
        Text(
          '${user.position} · ${user.department}',
          style: theme.textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.rtl,
        ),
        Text(
          DateFormat('yyyy/MM/dd · EEEE').format(DateTime.now()),
          style: theme.textTheme.bodySmall?.copyWith(
            color: ZaWolfColors.textMuted,
          ),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 390) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    DsAvatar(name: user.displayName, size: 40),
                    const SizedBox(width: 12),
                    Expanded(child: identity),
                  ],
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: locationChip),
              ],
            );
          }
          return Row(
            children: [
              locationChip,
              const SizedBox(width: 12),
              Expanded(child: identity),
              DsAvatar(name: user.displayName, size: 40),
            ],
          );
        },
      ),
    );
  }
}

/// Today's check-in/out summary with the lateness/deduction chip.
class MyStatusCard extends StatelessWidget {
  const MyStatusCard({required this.todayLog, super.key});

  final AttendanceModel todayLog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WolfCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (todayLog.checkInTime case final checkInTime?)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حضور اليوم: ${DateFormat('hh:mm a').format(checkInTime)}',
                  style:
                      theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ) ??
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (todayLog.checkOutTime case final checkOutTime?)
                  Text(
                    'انصراف اليوم: ${DateFormat('hh:mm a').format(checkOutTime)}',
                    style:
                        theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ) ??
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  )
                else
                  Text(
                    'قيد العمل في فرع (${todayLog.locationName})',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            )
          else
            Text(
              'لم يتم تسجيل وقت حضور صالح لهذا اليوم.',
              style:
                  theme.textTheme.bodyMedium?.copyWith(
                    color: ZaWolfColors.warning,
                    fontWeight: FontWeight.bold,
                  ) ??
                  const TextStyle(
                    color: ZaWolfColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          if (todayLog.checkInTime != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:
                    todayLog.isLate
                        ? ZaWolfColors.warning.withValues(alpha: 0.2)
                        : ZaWolfColors.success.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                todayLog.isLate
                    ? '${AttendancePolicy.arabicDeductionLabel(todayLog.salaryDeductionCode, fallback: todayLog.salaryDeductionLabel)} · ${dsBidi(todayLog.salaryDeductionAmount.toStringAsFixed(2))} ${todayLog.salaryCurrency}'
                    : 'في الموعد',
                style: TextStyle(
                  color:
                      todayLog.isLate
                          ? ZaWolfColors.warning
                          : ZaWolfColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ZaWolfColors.surface02,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'بانتظار الحضور',
                style: TextStyle(
                  color: ZaWolfColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
