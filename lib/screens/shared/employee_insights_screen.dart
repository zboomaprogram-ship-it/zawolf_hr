import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../components/wolf_card.dart';
import '../../models/performance_model.dart';
import '../../models/user_model.dart';
import '../../services/attendance_period_summary_service.dart';
import '../../theme/theme.dart';

class EmployeeInsightsScreen extends StatefulWidget {
  final String employeeUid;

  const EmployeeInsightsScreen({super.key, required this.employeeUid});

  @override
  State<EmployeeInsightsScreen> createState() => _EmployeeInsightsScreenState();
}

class _EmployeeInsightsScreenState extends State<EmployeeInsightsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Future<_EmployeeAttendanceOverview> _loadAttendanceOverview(
    UserModel employee,
  ) async {
    final today = DateTime.now();
    final summary = await AttendancePeriodSummaryService().loadForUser(
      user: employee,
      start: today.subtract(const Duration(days: 29)),
      end: today,
    );
    return _EmployeeAttendanceOverview(
      present: summary.presentDays,
      late: summary.lateDays,
      absent: summary.absentDays,
      recent: summary.days
          .where((day) => day.isExpectedWorkDay || day.attendance != null)
          .take(10)
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('ملف الموظف', style: theme.textTheme.headlineMedium),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _db.collection('users').doc(widget.employeeUid).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return _message('تعذر فتح ملف الموظف. تحقق من الصلاحيات.');
          }
          if (!userSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            );
          }
          if (!userSnapshot.data!.exists) {
            return _message('هذا الحساب لم يعد موجوداً.');
          }
          final employee = UserModel.fromFirestore(userSnapshot.data!);
          return Directionality(
            textDirection: TextDirection.rtl,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                WolfCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: ZaWolfColors.primaryCyan.withValues(
                          alpha: .15,
                        ),
                        child: Text(
                          employee.displayName.isEmpty
                              ? '?'
                              : employee.displayName.characters.first,
                          style: const TextStyle(
                            color: ZaWolfColors.primaryCyan,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employee.displayName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${employee.position} · ${employee.department}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${employee.employeeId} · ${employee.locationName}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'بيانات العمل',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                WolfCard(
                  child: Column(
                    children: [
                      _dataRow('البريد الإلكتروني', employee.email),
                      _dataRow(
                        'وقت الدوام',
                        '${employee.workSchedule.startTime ?? '09:00'} - ${employee.workSchedule.endTime ?? '17:00'}',
                      ),
                      _dataRow(
                        'المديرون',
                        employee.managerNames.isNotEmpty
                            ? employee.managerNames.join('، ')
                            : (employee.managerName ?? 'غير محدد'),
                      ),
                      _dataRow(
                        'حالة الحساب',
                        employee.isActive ? 'نشط' : 'موقوف',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'الحضور خلال آخر 30 يوماً',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<_EmployeeAttendanceOverview>(
                  future: _loadAttendanceOverview(employee),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _message('تعذر تحميل سجل الحضور.');
                    }
                    if (!snapshot.hasData) {
                      return const WolfCard(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: ZaWolfColors.primaryCyan,
                            ),
                          ),
                        ),
                      );
                    }
                    final overview = snapshot.data!;
                    return Column(
                      children: [
                        Row(
                          children: [
                            _stat(
                              'حضور',
                              overview.present,
                              ZaWolfColors.success,
                            ),
                            const SizedBox(width: 8),
                            _stat('تأخير', overview.late, ZaWolfColors.warning),
                            const SizedBox(width: 8),
                            _stat('غياب', overview.absent, ZaWolfColors.error),
                          ],
                        ),
                        const SizedBox(height: 10),
                        WolfCard(
                          child: Column(
                            children: overview.recent.isEmpty
                                ? [
                                    const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Text(
                                        'لا توجد سجلات حضور خلال آخر 30 يوماً.',
                                      ),
                                    ),
                                  ]
                                : overview.recent.map(_attendanceRow).toList(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'تقييم الأداء',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _db
                      .collection('performance')
                      .where('userId', isEqualTo: widget.employeeUid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _message('تعذر تحميل تقييم الأداء.');
                    }
                    if (!snapshot.hasData) {
                      return const WolfCard(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: ZaWolfColors.primaryCyan,
                            ),
                          ),
                        ),
                      );
                    }
                    final history =
                        snapshot.data!.docs
                            .map(PerformanceModel.fromFirestore)
                            .toList()
                          ..sort((a, b) => b.monthKey.compareTo(a.monthKey));
                    if (history.isEmpty) {
                      return _message(
                        'لا يوجد تقييم أداء منشور لهذا الموظف بعد.',
                      );
                    }
                    return WolfCard(
                      child: Column(
                        children: history
                            .take(6)
                            .map(
                              (item) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${item.monthKey} · التقدير ${item.grade}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'الأداء ${item.overallScore.toStringAsFixed(0)}% · الحضور ${item.attendanceScore.toStringAsFixed(0)}%',
                                ),
                                trailing: Text(
                                  '${item.overallScore.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: ZaWolfColors.primaryCyan,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );

  Widget _dataRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(value, textAlign: TextAlign.left)),
        Text(
          '$label: ',
          style: const TextStyle(color: ZaWolfColors.textSecondary),
        ),
      ],
    ),
  );

  Widget _stat(String label, int count, Color color) => Expanded(
    child: WolfCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: ZaWolfColors.textSecondary),
          ),
        ],
      ),
    ),
  );

  Widget _attendanceRow(AttendancePeriodDay item) {
    final label = item.isAbsent ? 'غائب' : (item.isLate ? 'متأخر' : 'حاضر');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.dateKey, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        item.attendance?.checkInTime == null
            ? 'لم يسجل حضوراً'
            : 'حضور ${DateFormat('hh:mm a').format(item.attendance!.checkInTime!)}',
      ),
      trailing: Text(
        label,
        style: TextStyle(
          color: label == 'غائب'
              ? ZaWolfColors.error
              : label == 'متأخر'
              ? ZaWolfColors.warning
              : ZaWolfColors.success,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmployeeAttendanceOverview {
  final int present;
  final int late;
  final int absent;
  final List<AttendancePeriodDay> recent;
  const _EmployeeAttendanceOverview({
    required this.present,
    required this.late,
    required this.absent,
    required this.recent,
  });
}
