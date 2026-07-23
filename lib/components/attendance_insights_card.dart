import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../services/dashboard_attendance_summary_service.dart';
import '../theme/theme.dart';
import 'wolf_card.dart';

class AttendanceInsightsCard extends StatelessWidget {
  final DashboardAttendanceSummary summary;
  final VoidCallback? onRefresh;
  final VoidCallback? onTap;
  final ValueChanged<String>? onCategoryTap;

  const AttendanceInsightsCard({
    super.key,
    required this.summary,
    this.onRefresh,
    this.onTap,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat('yyyy/MM/dd').format(summary.date);

    return WolfCard(
      hasBorderGlow: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'تحديث',
                onPressed: onRefresh,
                icon: const Icon(
                  Icons.refresh,
                  color: ZaWolfColors.primaryCyan,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    summary.teamScoped
                        ? 'حالة حضور الفريق اليوم'
                        : 'حالة حضور الشركة اليوم',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  Text(
                    '$dateLabel · ${summary.totalEmployees} موظف',
                    style: theme.textTheme.bodySmall,
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ZaWolfColors.primaryCyan.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ZaWolfColors.primaryCyan.withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: ZaWolfColors.primaryCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  _BarSegment(
                    flex: summary.present,
                    color: ZaWolfColors.success,
                  ),
                  _BarSegment(flex: summary.late, color: ZaWolfColors.warning),
                  _BarSegment(
                    flex: summary.permission,
                    color: ZaWolfColors.permissionTeal,
                  ),
                  _BarSegment(
                    flex: summary.dayOff,
                    color: ZaWolfColors.dayoffPurple,
                  ),
                  _BarSegment(
                    flex: summary.notAttended,
                    color: ZaWolfColors.error,
                  ),
                  if (summary.totalEmployees == 0)
                    const Expanded(
                      child: ColoredBox(color: ZaWolfColors.surface03),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 520;
              final cards = [
                _InsightTile(
                  label: 'حاضر',
                  value: summary.present,
                  percent: summary.percentOf(summary.present),
                  color: ZaWolfColors.success,
                  icon: Icons.check_circle_outline,
                  onTap: () => onCategoryTap?.call('present'),
                ),
                _InsightTile(
                  label: 'متأخر',
                  value: summary.late,
                  percent: summary.percentOf(summary.late),
                  color: ZaWolfColors.warning,
                  icon: Icons.schedule_outlined,
                  onTap: () => onCategoryTap?.call('late'),
                ),
                _InsightTile(
                  label: 'إذن',
                  value: summary.permission,
                  percent: summary.percentOf(summary.permission),
                  color: ZaWolfColors.permissionTeal,
                  icon: Icons.assignment_turned_in_outlined,
                  onTap: () => onCategoryTap?.call('permission'),
                ),
                _InsightTile(
                  label: 'إجازة',
                  value: summary.dayOff,
                  percent: summary.percentOf(summary.dayOff),
                  color: ZaWolfColors.dayoffPurple,
                  icon: Icons.beach_access_outlined,
                  onTap: () => onCategoryTap?.call('day_off'),
                ),
                _InsightTile(
                  label: 'لم يسجل',
                  value: summary.notAttended,
                  percent: summary.percentOf(summary.notAttended),
                  color: ZaWolfColors.error,
                  icon: Icons.person_off_outlined,
                  onTap: () => onCategoryTap?.call('not_attended'),
                ),
              ];

              if (narrow) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      cards[i],
                      if (i != cards.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cards
                    .map(
                      (card) => SizedBox(
                        width: (constraints.maxWidth - 16) / 3,
                        child: card,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BarSegment extends StatelessWidget {
  final int flex;
  final Color color;

  const _BarSegment({required this.flex, required this.color});

  @override
  Widget build(BuildContext context) {
    if (flex <= 0) return const SizedBox.shrink();
    return Expanded(
      flex: flex,
      child: ColoredBox(color: color),
    );
  }
}

class _InsightTile extends StatelessWidget {
  final String label;
  final int value;
  final double percent;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _InsightTile({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ZaWolfColors.surface02,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: ZaWolfColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(icon, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
