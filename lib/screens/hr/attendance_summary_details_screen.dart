import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_attendance_summary_service.dart';
import '../../theme/theme.dart';

class AttendanceSummaryDetailsScreen extends StatefulWidget {
  const AttendanceSummaryDetailsScreen({super.key});

  @override
  State<AttendanceSummaryDetailsScreen> createState() =>
      _AttendanceSummaryDetailsScreenState();
}

class _AttendanceSummaryDetailsScreenState
    extends State<AttendanceSummaryDetailsScreen> {
  final DashboardAttendanceSummaryService _service =
      DashboardAttendanceSummaryService();
  Future<List<DashboardAttendanceSummary>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthService>().currentUser;
    if (user != null && _future == null) {
      _future = _service.loadLast30DaysForReviewer(user);
    }
  }

  void _reload(UserModel user) {
    setState(() {
      _future = _service.loadLast30DaysForReviewer(user);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الحضور'),
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'تحديث',
              onPressed: () => _reload(user),
              icon: const Icon(Icons.refresh, color: ZaWolfColors.primaryCyan),
            ),
        ],
      ),
      body: user == null
          ? const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            )
          : FutureBuilder<List<DashboardAttendanceSummary>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: ZaWolfColors.primaryCyan,
                    ),
                  );
                }

                final summaries = snapshot.data!;
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: summaries.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Text(
                        user.role == 'manager'
                            ? 'آخر 30 يوم لفريقك'
                            : 'آخر 30 يوم للشركة',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textDirection: TextDirection.rtl,
                      );
                    }
                    return _DaySummaryCard(summary: summaries[index - 1]);
                  },
                );
              },
            ),
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  final DashboardAttendanceSummary summary;

  const _DaySummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEEE، yyyy/MM/dd', 'ar').format(summary.date);
    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${summary.totalEmployees} موظف',
                style: const TextStyle(color: ZaWolfColors.textMuted),
              ),
              const Spacer(),
              Text(
                dateLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MiniBar(summary: summary),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              _ChipStat(
                label: 'حاضر',
                value: summary.present,
                color: ZaWolfColors.success,
              ),
              _ChipStat(
                label: 'متأخر',
                value: summary.late,
                color: ZaWolfColors.warning,
              ),
              _ChipStat(
                label: 'إذن',
                value: summary.permission,
                color: ZaWolfColors.permissionTeal,
              ),
              _ChipStat(
                label: 'إجازة',
                value: summary.dayOff,
                color: ZaWolfColors.dayoffPurple,
              ),
              _ChipStat(
                label: 'لم يسجل',
                value: summary.notAttended,
                color: ZaWolfColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final DashboardAttendanceSummary summary;

  const _MiniBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            _Segment(flex: summary.present, color: ZaWolfColors.success),
            _Segment(flex: summary.late, color: ZaWolfColors.warning),
            _Segment(
              flex: summary.permission,
              color: ZaWolfColors.permissionTeal,
            ),
            _Segment(flex: summary.dayOff, color: ZaWolfColors.dayoffPurple),
            _Segment(flex: summary.notAttended, color: ZaWolfColors.error),
            if (summary.totalEmployees == 0)
              const Expanded(child: ColoredBox(color: ZaWolfColors.surface03)),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final int flex;
  final Color color;

  const _Segment({required this.flex, required this.color});

  @override
  Widget build(BuildContext context) {
    if (flex <= 0) return const SizedBox.shrink();
    return Expanded(
      flex: flex,
      child: ColoredBox(color: color),
    );
  }
}

class _ChipStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _ChipStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
        textDirection: TextDirection.rtl,
      ),
    );
  }
}
