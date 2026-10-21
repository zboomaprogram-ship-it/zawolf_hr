import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../components/wolf_card.dart';
import '../../models/attendance_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/attendance_service.dart';
import '../../services/attendance_period_summary_service.dart';
import '../../theme/theme.dart';
import '../../utils/payroll_cycle.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/feedback_states.dart'
    show EmptyState, ErrorState;
import '../../design_system/components/rtl_navigation.dart';
import '../../design_system/components/skeletons.dart' show SkeletonList;
import '../../design_system/components/status_pill.dart';
import 'widgets/employee_quick_action.dart' show attendanceStatusToDsStatus;

enum _AttendanceFilter {
  all,
  present,
  late,
  absent,
  leavesAndHolidays,
}

class EmployeeAttendanceHistoryScreen extends StatefulWidget {
  const EmployeeAttendanceHistoryScreen({super.key});

  @override
  State<EmployeeAttendanceHistoryScreen> createState() =>
      _EmployeeAttendanceHistoryScreenState();
}

class _EmployeeAttendanceHistoryScreenState
    extends State<EmployeeAttendanceHistoryScreen> {
  late DateTime _selectedDate;
  _AttendanceFilter _selectedFilter = _AttendanceFilter.all;
  AttendancePeriodSummary? _periodSummary;
  bool _isLoadingSummary = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSummary();
    });
  }

  PayrollCycle get _currentCycle => PayrollCycle.forDate(_selectedDate);

  Future<void> _loadSummary() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingSummary = true;
      _errorMessage = null;
    });

    try {
      final cycle = _currentCycle;
      final now = DateTime.now();
      final end = cycle.end.isAfter(now) ? now : cycle.end;
      final summary = await AttendancePeriodSummaryService().loadForUser(
        user: user,
        start: cycle.start,
        end: end,
        now: now,
      );
      if (mounted) {
        setState(() {
          _periodSummary = summary;
          _isLoadingSummary = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر تحميل ملخص الحضور للفترة المحددة.';
          _isLoadingSummary = false;
        });
      }
    }
  }

  void _previousCycle() {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month - 1,
        _selectedDate.day,
      );
    });
    _loadSummary();
  }

  void _nextCycle() {
    final next = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      _selectedDate.day,
    );
    if (next.isAfter(DateTime.now())) return;
    setState(() {
      _selectedDate = next;
    });
    _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }

    final cycle = _currentCycle;
    final isCurrentMonth = PayrollCycle.forDate(DateTime.now()).key == cycle.key;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(RtlNavigation.backIcon(context)),
            tooltip: 'رجوع',
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                context.go('/employee/dashboard');
              }
            },
          ),
          title: const Text('تفاصيل وسجل الحضور'),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh, color: ZaWolfColors.primaryCyan),
              onPressed: _loadSummary,
            ),
          ],
        ),
        body: StreamBuilder<List<AttendanceModel>>(
          stream: AttendanceService().watchMonthlyAttendance(user.uid, cycle.key),
          builder: (context, snapshot) {
            final logs = snapshot.data ?? [];
            return LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: ListView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? DsSpacing.xl : DsSpacing.md,
                        vertical: DsSpacing.lg,
                      ),
                      children: [
                        _buildCycleNavigator(cycle, isCurrentMonth),
                        const SizedBox(height: DsSpacing.lg),
                        _buildKpiCards(logs),
                        const SizedBox(height: DsSpacing.lg),
                        _buildFilterChips(),
                        const SizedBox(height: DsSpacing.lg),
                        if (_isLoadingSummary && _periodSummary == null)
                          const Padding(
                            padding: EdgeInsets.all(DsSpacing.xl),
                            child: SkeletonList(itemCount: 5, itemHeight: 80),
                          )
                        else if (_errorMessage != null && _periodSummary == null)
                          ErrorState(
                            message: _errorMessage!,
                            onRetry: _loadSummary,
                          )
                        else
                          _buildRecordsList(logs, user),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCycleNavigator(PayrollCycle cycle, bool isCurrentMonth) {
    final startFormat = DateFormat('dd MMM', 'ar').format(cycle.start);
    final endFormat = DateFormat('dd MMM yyyy', 'ar').format(cycle.end);
    final monthLabel = DateFormat('MMMM yyyy', 'ar').format(cycle.end);

    return WolfCard(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.md,
        vertical: DsSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'الدورة السابقة',
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onPressed: _previousCycle,
          ),
          Column(
            children: [
              Text(
                'دورة $monthLabel',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: ZaWolfColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$startFormat - $endFormat',
                style: const TextStyle(
                  fontSize: 12,
                  color: ZaWolfColors.textSecondary,
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'الدورة التالية',
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
            onPressed: isCurrentMonth ? null : _nextCycle,
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCards(List<AttendanceModel> logs) {
    final summary = _periodSummary;
    final attendedCount = summary?.presentDays ??
        logs.where((l) => l.checkInTime != null).length;
    final lateCount = summary?.lateDays ??
        logs.where((l) => l.isLate || l.status == 'late').length;
    final absentCount = summary?.absentDays ??
        logs.where((l) => l.status == 'absent').length;
    final discipline = summary?.disciplinePercentage ?? 100.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - (DsSpacing.md * 3)) / 4;
        final useGrid = constraints.maxWidth < 600;

        if (useGrid) {
          return Wrap(
            spacing: DsSpacing.sm,
            runSpacing: DsSpacing.sm,
            children: [
              _statCard('أيام الحضور', '$attendedCount', Icons.check_circle_outline, ZaWolfColors.success, (constraints.maxWidth - DsSpacing.sm) / 2),
              _statCard('مرات التأخير', '$lateCount', Icons.access_time_rounded, ZaWolfColors.warning, (constraints.maxWidth - DsSpacing.sm) / 2),
              _statCard('أيام الغياب', '$absentCount', Icons.cancel_outlined, ZaWolfColors.error, (constraints.maxWidth - DsSpacing.sm) / 2),
              _statCard('الانضباط', '${discipline.round()}%', Icons.verified_outlined, ZaWolfColors.primaryCyan, (constraints.maxWidth - DsSpacing.sm) / 2),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _statCard('أيام الحضور', '$attendedCount', Icons.check_circle_outline, ZaWolfColors.success, cardWidth)),
            const SizedBox(width: DsSpacing.md),
            Expanded(child: _statCard('مرات التأخير', '$lateCount', Icons.access_time_rounded, ZaWolfColors.warning, cardWidth)),
            const SizedBox(width: DsSpacing.md),
            Expanded(child: _statCard('أيام الغياب', '$absentCount', Icons.cancel_outlined, ZaWolfColors.error, cardWidth)),
            const SizedBox(width: DsSpacing.md),
            Expanded(child: _statCard('الانضباط', '${discipline.round()}%', Icons.verified_outlined, ZaWolfColors.primaryCyan, cardWidth)),
          ],
        );
      },
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: WolfCard(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.md,
          vertical: DsSpacing.lg,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: DsSpacing.xs),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: ZaWolfColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('الكل', _AttendanceFilter.all),
          const SizedBox(width: DsSpacing.sm),
          _filterChip('حضور', _AttendanceFilter.present),
          const SizedBox(width: DsSpacing.sm),
          _filterChip('تأخير', _AttendanceFilter.late),
          const SizedBox(width: DsSpacing.sm),
          _filterChip('غياب', _AttendanceFilter.absent),
          const SizedBox(width: DsSpacing.sm),
          _filterChip('إجازات وعطلات', _AttendanceFilter.leavesAndHolidays),
        ],
      ),
    );
  }

  Widget _filterChip(String title, _AttendanceFilter filter) {
    final selected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(title),
      selected: selected,
      selectedColor: ZaWolfColors.primaryCyan.withValues(alpha: 0.2),
      onSelected: (_) {
        setState(() => _selectedFilter = filter);
      },
    );
  }

  Widget _buildRecordsList(List<AttendanceModel> logs, UserModel user) {
    // If period summary is loaded, use its days list which includes expected work days, leaves, and absences
    final summaryDays = _periodSummary?.days ?? [];

    if (summaryDays.isNotEmpty) {
      final filteredDays = summaryDays.where((day) {
        switch (_selectedFilter) {
          case _AttendanceFilter.all:
            return true;
          case _AttendanceFilter.present:
            return day.isPresent && !day.isLate;
          case _AttendanceFilter.late:
            return day.isLate;
          case _AttendanceFilter.absent:
            return day.isAbsent;
          case _AttendanceFilter.leavesAndHolidays:
            return day.isApprovedLeave || !day.isExpectedWorkDay;
        }
      }).toList();

      if (filteredDays.isEmpty) {
        return const EmptyState(
          title: 'لا توجد سجلات',
          subtitle: 'لا توجد سجلات مطابقة للفلتر المحدد في هذه الدورة.',
        );
      }

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filteredDays.length,
        separatorBuilder: (_, __) => const SizedBox(height: DsSpacing.sm),
        itemBuilder: (context, index) {
          final day = filteredDays[index];
          return _buildDayCard(day);
        },
      );
    }

    // Fallback directly to monthly attendance logs
    if (logs.isEmpty) {
      return const EmptyState(
        title: 'لا توجد سجلات',
        subtitle: 'لا توجد أي سجلات حضور مسجلة في هذه الدورة حتى الآن.',
      );
    }

    final sortedLogs = List<AttendanceModel>.from(logs)
      ..sort((a, b) => b.date.compareTo(a.date));

    final filteredLogs = sortedLogs.where((log) {
      final isLate = log.isLate || log.status == 'late';
      final isAbsent = log.status == 'absent';
      final isPresent = log.checkInTime != null && !isAbsent;

      switch (_selectedFilter) {
        case _AttendanceFilter.all:
          return true;
        case _AttendanceFilter.present:
          return isPresent && !isLate;
        case _AttendanceFilter.late:
          return isLate;
        case _AttendanceFilter.absent:
          return isAbsent;
        case _AttendanceFilter.leavesAndHolidays:
          return log.status == 'on-leave';
      }
    }).toList();

    if (filteredLogs.isEmpty) {
      return const EmptyState(
        title: 'لا توجد سجلات',
        subtitle: 'لا توجد سجلات حضور تطابق الفلتر المحدد.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredLogs.length,
      separatorBuilder: (_, __) => const SizedBox(height: DsSpacing.sm),
      itemBuilder: (context, index) {
        final log = filteredLogs[index];
        return _buildLogCard(log);
      },
    );
  }

  Widget _buildDayCard(AttendancePeriodDay day) {
    final dateStr = DateFormat('EEEE، dd MMMM yyyy', 'ar').format(day.date);
    final log = day.attendance;

    String statusLabel = 'غائب';
    DsStatus dsStatus = DsStatus.absent;

    if (day.isApprovedLeave) {
      statusLabel = 'إجازة معتمدة';
      dsStatus = DsStatus.neutral;
    } else if (day.isApprovedPermission) {
      statusLabel = 'إذن معتمد';
      dsStatus = DsStatus.neutral;
    } else if (!day.isExpectedWorkDay) {
      statusLabel = 'عطلة رسمية / أسبوعية';
      dsStatus = DsStatus.neutral;
    } else if (day.isLate) {
      statusLabel = 'متأخر';
      dsStatus = DsStatus.late;
    } else if (day.isPresent) {
      statusLabel = 'حاضر';
      dsStatus = DsStatus.present;
    }

    final checkIn = log?.checkInTime != null
        ? DateFormat('hh:mm a', 'ar').format(log!.checkInTime!)
        : null;
    final checkOut = log?.checkOutTime != null
        ? DateFormat('hh:mm a', 'ar').format(log!.checkOutTime!)
        : null;
    final lateMinutes = log?.lateMinutes ?? 0;

    return WolfCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  dateStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: ZaWolfColors.textPrimary,
                  ),
                ),
              ),
              StatusPill(status: dsStatus, label: statusLabel),
            ],
          ),
          if (checkIn != null || checkOut != null || lateMinutes > 0) ...[
            const SizedBox(height: DsSpacing.sm),
            const Divider(color: ZaWolfColors.surface03, height: 1),
            const SizedBox(height: DsSpacing.sm),
            Row(
              children: [
                if (checkIn != null) ...[
                  const Icon(Icons.login_rounded, size: 16, color: ZaWolfColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'دخول: $checkIn',
                    style: const TextStyle(fontSize: 13, color: ZaWolfColors.textSecondary),
                  ),
                  const SizedBox(width: DsSpacing.lg),
                ],
                if (checkOut != null) ...[
                  const Icon(Icons.logout_rounded, size: 16, color: ZaWolfColors.primaryCyan),
                  const SizedBox(width: 4),
                  Text(
                    'خروج: $checkOut',
                    style: const TextStyle(fontSize: 13, color: ZaWolfColors.textSecondary),
                  ),
                  const SizedBox(width: DsSpacing.lg),
                ],
                if (lateMinutes > 0) ...[
                  const Icon(Icons.warning_amber_rounded, size: 16, color: ZaWolfColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    'تأخير: $lateMinutes دقيقة',
                    style: const TextStyle(fontSize: 13, color: ZaWolfColors.warning),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogCard(AttendanceModel log) {
    DateTime? parsedDate = DateTime.tryParse(log.date);
    final dateStr = parsedDate != null
        ? DateFormat('EEEE، dd MMMM yyyy', 'ar').format(parsedDate)
        : log.date;

    final dsStatus = attendanceStatusToDsStatus(log.status);
    final statusLabel = _statusLabel(log.status);

    final checkIn = log.checkInTime != null
        ? DateFormat('hh:mm a', 'ar').format(log.checkInTime!)
        : null;
    final checkOut = log.checkOutTime != null
        ? DateFormat('hh:mm a', 'ar').format(log.checkOutTime!)
        : null;
    final lateMinutes = log.lateMinutes;

    return WolfCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  dateStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: ZaWolfColors.textPrimary,
                  ),
                ),
              ),
              StatusPill(status: dsStatus, label: statusLabel),
            ],
          ),
          if (checkIn != null || checkOut != null || lateMinutes > 0) ...[
            const SizedBox(height: DsSpacing.sm),
            const Divider(color: ZaWolfColors.surface03, height: 1),
            const SizedBox(height: DsSpacing.sm),
            Row(
              children: [
                if (checkIn != null) ...[
                  const Icon(Icons.login_rounded, size: 16, color: ZaWolfColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'دخول: $checkIn',
                    style: const TextStyle(fontSize: 13, color: ZaWolfColors.textSecondary),
                  ),
                  const SizedBox(width: DsSpacing.lg),
                ],
                if (checkOut != null) ...[
                  const Icon(Icons.logout_rounded, size: 16, color: ZaWolfColors.primaryCyan),
                  const SizedBox(width: 4),
                  Text(
                    'خروج: $checkOut',
                    style: const TextStyle(fontSize: 13, color: ZaWolfColors.textSecondary),
                  ),
                  const SizedBox(width: DsSpacing.lg),
                ],
                if (lateMinutes > 0) ...[
                  const Icon(Icons.warning_amber_rounded, size: 16, color: ZaWolfColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    'تأخير: $lateMinutes دقيقة',
                    style: const TextStyle(fontSize: 13, color: ZaWolfColors.warning),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'present':
        return 'حاضر';
      case 'late':
        return 'متأخر';
      case 'absent':
        return 'غائب';
      case 'on-leave':
        return 'إجازة معتمدة';
      default:
        return status;
    }
  }
}
