import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_attendance_summary_service.dart';
import '../../theme/theme.dart';

class AttendanceSummaryDetailsScreen extends StatefulWidget {
  const AttendanceSummaryDetailsScreen({super.key, this.initialStatus});

  final String? initialStatus;

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
          : widget.initialStatus != null
          ? _TodayCategoryDetails(
              service: _service,
              user: user,
              status: widget.initialStatus!,
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
                        (user.role == 'manager' || user.role == 'team_leader')
                            ? 'آخر 30 يوم لفريقك'
                            : 'آخر 30 يوم للشركة',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textDirection: TextDirection.rtl,
                      );
                    }
                    return _DaySummaryCard(
                      summary: summaries[index - 1],
                      onTap: () =>
                          _openDayDetails(user, summaries[index - 1].date),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _openDayDetails(UserModel user, DateTime date) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _DayDetailsSheet(service: _service, user: user, date: date),
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  final DashboardAttendanceSummary summary;
  final VoidCallback onTap;

  const _DaySummaryCard({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEEE، yyyy/MM/dd', 'ar').format(summary.date);
    return WolfCard(
      onTap: onTap,
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
          const Align(
            alignment: Alignment.centerLeft,
            child: Icon(Icons.chevron_left, color: ZaWolfColors.primaryCyan),
          ),
          const SizedBox(height: 4),
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

class _DayDetailsSheet extends StatelessWidget {
  final DashboardAttendanceSummaryService service;
  final UserModel user;
  final DateTime date;

  const _DayDetailsSheet({
    required this.service,
    required this.user,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEEE، yyyy/MM/dd', 'ar').format(date);
    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: ZaWolfColors.surface01,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: FutureBuilder<DashboardAttendanceDayDetails>(
          future: service.loadDayDetails(user, date),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'تعذر تحميل تفاصيل هذا اليوم. حاول مرة أخرى.',
                  style: TextStyle(color: ZaWolfColors.error),
                  textDirection: TextDirection.rtl,
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: ZaWolfColors.primaryCyan,
                ),
              );
            }

            final people = snapshot.data!.people;
            final groups = <_AttendanceGroup>[
              _AttendanceGroup(
                'حضر في الموعد',
                'present',
                ZaWolfColors.success,
              ),
              _AttendanceGroup('متأخر', 'late', ZaWolfColors.warning),
              _AttendanceGroup(
                'إذن معتمد',
                'permission',
                ZaWolfColors.permissionTeal,
              ),
              _AttendanceGroup(
                'إجازة / يوم إجازة',
                'day_off',
                ZaWolfColors.dayoffPurple,
              ),
              _AttendanceGroup(
                'لم يسجل حضوراً',
                'not_attended',
                ZaWolfColors.error,
              ),
            ];
            final missingCheckout = people
                .where((person) => person.needsCheckout)
                .toList();

            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ZaWolfColors.textMuted,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'تفاصيل الحضور',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                ),
                Text(
                  dateLabel,
                  style: const TextStyle(color: ZaWolfColors.textMuted),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 18),
                if (missingCheckout.isNotEmpty)
                  _AttendancePeopleSection(
                    title: 'لم يسجل انصرافاً',
                    color: ZaWolfColors.error,
                    people: missingCheckout,
                  ),
                for (final group in groups) ...[
                  _AttendancePeopleSection(
                    title: group.title,
                    color: group.color,
                    people: people
                        .where((person) => person.status == group.status)
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AttendanceGroup {
  final String title;
  final String status;
  final Color color;

  const _AttendanceGroup(this.title, this.status, this.color);
}

class _AttendancePeopleSection extends StatelessWidget {
  final String title;
  final Color color;
  final List<DashboardAttendancePerson> people;

  const _AttendancePeopleSection({
    required this.title,
    required this.color,
    required this.people,
  });

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();
    final timeFormat = DateFormat('hh:mm a', 'en');
    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$title (${people.length})',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          for (final person in people)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    person.employee.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  Text(
                    _detailText(person, timeFormat),
                    style: const TextStyle(color: ZaWolfColors.textMuted),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _detailText(DashboardAttendancePerson person, DateFormat timeFormat) {
    final parts = <String>[];
    if (person.employee.department.isNotEmpty) {
      parts.add(person.employee.department);
    }
    if (person.employee.position.isNotEmpty) {
      parts.add(person.employee.position);
    }
    if (person.employee.employeeId.isNotEmpty) {
      parts.add(person.employee.employeeId);
    }
    if (person.checkInTime != null) {
      parts.add('حضور ${timeFormat.format(person.checkInTime!)}');
    }
    if (person.checkOutTime != null) {
      parts.add('انصراف ${timeFormat.format(person.checkOutTime!)}');
    }
    if (person.lateMinutes > 0) parts.add('تأخير ${person.lateMinutes} د');
    if (person.needsCheckout) parts.add('لم يسجل الانصراف');
    return parts.isEmpty ? 'لا يوجد سجل حضور لهذا اليوم' : parts.join(' · ');
  }
}

class _TodayCategoryDetails extends StatelessWidget {
  const _TodayCategoryDetails({
    required this.service,
    required this.user,
    required this.status,
  });

  final DashboardAttendanceSummaryService service;
  final UserModel user;
  final String status;

  @override
  Widget build(BuildContext context) {
    final metadata = switch (status) {
      'present' => ('حضر في الموعد', ZaWolfColors.success),
      'late' => ('المتأخرون', ZaWolfColors.warning),
      'permission' => ('لديهم إذن', ZaWolfColors.permissionTeal),
      'day_off' => ('في إجازة', ZaWolfColors.dayoffPurple),
      _ => ('لم يسجلوا الحضور', ZaWolfColors.error),
    };
    return FutureBuilder<DashboardAttendanceDayDetails>(
      future: service.loadDayDetails(user, DateTime.now()),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل تفاصيل الحضور.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final people = snapshot.data!.people
            .where((person) => person.status == status)
            .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${metadata.$1} · ${DateFormat('yyyy/MM/dd').format(DateTime.now())}',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (people.isEmpty)
              const WolfCard(child: Center(child: Text('لا يوجد موظفون.')))
            else
              _AttendancePeopleSection(
                title: metadata.$1,
                color: metadata.$2,
                people: people,
              ),
          ],
        );
      },
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
