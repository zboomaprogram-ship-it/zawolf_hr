import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../models/attendance_policy.dart';
import '../../../models/attendance_model.dart';
import '../../../theme/theme.dart';
import '../../../design_system/components/status_pill.dart';
import '../../../design_system/tokens.dart';
import 'employee_quick_action.dart';

/// Recent monthly attendance activity (max five rows) with empty state.
/// Presentation only; the stream stays owned by the dashboard screen.
class MonthActivitySection extends StatelessWidget {
  final List<AttendanceModel> logs;

  const MonthActivitySection({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'النشاط الأخير (هذا الشهر)',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: DsSpacing.md),
        if (logs.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  color: ZaWolfColors.textMuted,
                  size: 40,
                ),
                const SizedBox(height: DsSpacing.md),
                Text(
                  'لا توجد سجلات حضور هذا الشهر.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length > 5 ? 5 : logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final dateParsed = DateTime.parse(log.date);
              final formatDay = DateFormat('EEEE dd MMM', 'ar').format(
                dateParsed,
              );
              final checkInTime = log.checkInTime;
              final checkOutTime = log.checkOutTime;
              final checkInText = checkInTime == null
                  ? 'لم يسجل حضور'
                  : 'حضور: ${DateFormat('hh:mm a').format(checkInTime)}';
              final checkOutText = checkOutTime == null
                  ? null
                  : 'انصراف: ${DateFormat('hh:mm a').format(checkOutTime)}';

              final dsStatus = attendanceStatusToDsStatus(log.status);

              return Container(
                margin: const EdgeInsets.only(bottom: DsSpacing.md),
                padding: const EdgeInsets.all(DsSpacing.md),
                decoration: BoxDecoration(
                  color: ZaWolfColors.surface01,
                  borderRadius: DsRadius.inputBorder,
                  border: Border.all(color: ZaWolfColors.surface03),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatDay,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(checkInText, style: theme.textTheme.bodySmall),
                          if (checkOutText != null)
                            Text(
                              checkOutText,
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    StatusPill(status: dsStatus, label: _statusLabel(log.status), compact: true),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'present':
        return 'حاضر';
      case 'late':
        return 'متأخر';
      case 'on-leave':
      case 'leave':
        return 'إجازة';
      case 'absent':
        return 'غائب';
      default:
        return AttendancePolicy.arabicDeductionLabel(status, fallback: status);
    }
  }
}
