import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../components/wolf_card.dart';
import '../../models/performance_model.dart';
import '../../models/user_model.dart';
import '../../models/employee_role.dart';
import '../../services/attendance_period_summary_service.dart';
import '../../navigation/operational_visibility_entry.dart';
import '../../theme/theme.dart';
import '../../design_system/components/rtl_navigation.dart';
import '../../design_system/components/feedback_states.dart' show EmptyState;
import '../../design_system/components/skeletons.dart' show SkeletonList;

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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'رجوع',
            icon: Icon(RtlNavigation.backIcon(context)),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text('ملف الموظف', style: theme.textTheme.headlineMedium),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _db.collection('users').doc(widget.employeeUid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.hasError) {
              return _message('تعذر فتح ملف الموظف. تحقق من الصلاحيات.');
            }
            if (!userSnapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonList(itemCount: 4, itemHeight: 96),
              );
            }
            if (!userSnapshot.data!.exists) {
              return _message('هذا الحساب لم يعد موجوداً.');
            }

            final employee = UserModel.fromFirestore(userSnapshot.data!);

            return LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 1280 : double.infinity,
                    ),
                    child: ListView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 16,
                        vertical: 16,
                      ),
                      children: [
                        _buildHeroBanner(employee, theme, isDesktop),
                        const SizedBox(height: 16),
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: _buildWorkDetailsColumn(employee, theme),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 6,
                                child: _buildInsightsColumn(employee, theme),
                              ),
                            ],
                          )
                        else ...[
                          _buildWorkDetailsColumn(employee, theme),
                          const SizedBox(height: 20),
                          _buildInsightsColumn(employee, theme),
                        ],
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

  Widget _buildHeroBanner(UserModel employee, ThemeData theme, bool isDesktop) {
    final statusColor = employee.isActive ? ZaWolfColors.success : ZaWolfColors.error;
    final statusText = employee.isActive ? 'حساب نشط' : 'حساب موقوف';

    return WolfCard(
      hasBorderGlow: true,
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: isDesktop ? 80 : 64,
                height: isDesktop ? 80 : 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      ZaWolfColors.primaryCyan.withValues(alpha: 0.25),
                      ZaWolfColors.primaryBlue.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  border: Border.all(
                    color: ZaWolfColors.primaryCyan.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  employee.displayName.isEmpty
                      ? '?'
                      : employee.displayName.characters.first,
                  style: TextStyle(
                    color: ZaWolfColors.primaryCyan,
                    fontSize: isDesktop ? 32 : 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          employee.displayName,
                          style: (isDesktop
                                  ? theme.textTheme.headlineSmall
                                  : theme.textTheme.titleLarge)
                              ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${employee.position} · ${employee.department}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: ZaWolfColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          size: 14,
                          color: ZaWolfColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          employee.employeeId,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ZaWolfColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: ZaWolfColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          employee.locationName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ZaWolfColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isDesktop)
                FilledButton.icon(
                  key: const Key('employee-full-operations-history'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ZaWolfColors.primaryCyan.withValues(alpha: 0.15),
                    foregroundColor: ZaWolfColors.primaryCyan,
                    side: const BorderSide(color: ZaWolfColors.primaryCyan, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onPressed: () => _openOperationsHistory(context),
                  icon: const Icon(Icons.manage_history_outlined),
                  label: const Text(
                    'السجل التشغيلي الكامل',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (!isDesktop) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('employee-full-operations-history'),
                style: FilledButton.styleFrom(
                  backgroundColor: ZaWolfColors.primaryCyan.withValues(alpha: 0.15),
                  foregroundColor: ZaWolfColors.primaryCyan,
                  side: const BorderSide(color: ZaWolfColors.primaryCyan, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _openOperationsHistory(context),
                icon: const Icon(Icons.manage_history_outlined),
                label: const Text(
                  'عرض السجل الكامل للحضور والطلبات والخصومات',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openOperationsHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OperationalVisibilityEntry(
          employeeUserId: widget.employeeUid,
          canManageVisibility: false,
        ),
      ),
    );
  }

  Widget _buildWorkDetailsColumn(UserModel employee, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.work_outline_rounded, color: ZaWolfColors.primaryCyan, size: 20),
            const SizedBox(width: 8),
            Text(
              'بيانات العمل والاتصال',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        WolfCard(
          child: Column(
            children: [
              _infoTile(
                icon: Icons.email_outlined,
                label: 'البريد الإلكتروني',
                value: employee.email,
                trailing: IconButton(
                  tooltip: 'نسخ البريد',
                  icon: const Icon(Icons.copy_rounded, size: 16, color: ZaWolfColors.textMuted),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: employee.email));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ البريد الإلكتروني بنجاح')),
                    );
                  },
                ),
              ),
              const Divider(color: ZaWolfColors.surface03, height: 1),
              _infoTile(
                icon: Icons.schedule_rounded,
                label: 'وقت الدوام الرسمي',
                value: '${employee.workSchedule.startTime ?? '09:00'} - ${employee.workSchedule.endTime ?? '17:00'}',
              ),
              const Divider(color: ZaWolfColors.surface03, height: 1),
              _infoTile(
                icon: Icons.supervisor_account_outlined,
                label: 'المديرون المباشرون',
                value: employee.managerNames.isNotEmpty
                    ? employee.managerNames.join('، ')
                    : (employee.managerName ?? 'غير محدد'),
              ),
              const Divider(color: ZaWolfColors.surface03, height: 1),
              _infoTile(
                icon: Icons.admin_panel_settings_outlined,
                label: 'الدور الوظيفي بالمنظومة',
                value: EmployeeRole.arabicLabel(employee.role),
              ),
              const Divider(color: ZaWolfColors.surface03, height: 1),
              _infoTile(
                icon: Icons.business_outlined,
                label: 'الفرع والموقع الجغرافي',
                value: employee.locationName.isNotEmpty ? employee.locationName : 'غير محدد',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightsColumn(UserModel employee, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month_outlined, color: ZaWolfColors.primaryCyan, size: 20),
            const SizedBox(width: 8),
            Text(
              'الحضور خلال آخر 30 يوماً',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<_EmployeeAttendanceOverview>(
          future: _loadAttendanceOverview(employee),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _message('تعذر تحميل سجل الحضور.');
            }
            if (!snapshot.hasData) {
              return const WolfCard(
                child: SkeletonList(itemCount: 3, itemHeight: 56),
              );
            }
            final overview = snapshot.data!;
            final totalWorkDays = overview.present + overview.late + overview.absent;
            final commitmentRate = totalWorkDays > 0
                ? ((overview.present + overview.late * 0.5) / totalWorkDays * 100).clamp(0, 100).toInt()
                : 100;

            return Column(
              children: [
                Row(
                  children: [
                    _metricStatCard(
                      label: 'حضور منضبط',
                      count: overview.present,
                      color: ZaWolfColors.success,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    const SizedBox(width: 10),
                    _metricStatCard(
                      label: 'تأخير',
                      count: overview.late,
                      color: ZaWolfColors.warning,
                      icon: Icons.access_time_rounded,
                    ),
                    const SizedBox(width: 10),
                    _metricStatCard(
                      label: 'غياب',
                      count: overview.absent,
                      color: ZaWolfColors.error,
                      icon: Icons.cancel_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                WolfCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.insights_rounded, color: ZaWolfColors.primaryCyan, size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'معدل الالتزام التقريبي: ',
                        style: TextStyle(color: ZaWolfColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$commitmentRate%',
                        style: TextStyle(
                          color: commitmentRate >= 85
                              ? ZaWolfColors.success
                              : commitmentRate >= 70
                                  ? ZaWolfColors.warning
                                  : ZaWolfColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                WolfCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'آخر تسجيلات الحضور',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: ZaWolfColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (overview.recent.isEmpty)
                        const EmptyState(title: 'لا توجد سجلات حضور خلال آخر 30 يوماً.')
                      else
                        ...overview.recent.map(_attendanceRow),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.emoji_events_outlined, color: ZaWolfColors.perfGold, size: 20),
            const SizedBox(width: 8),
            Text(
              'سجل تقييم الأداء الشهري',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
                child: SkeletonList(itemCount: 2, itemHeight: 64),
              );
            }
            final history = snapshot.data!.docs
                .map(PerformanceModel.fromFirestore)
                .toList()
              ..sort((a, b) => b.monthKey.compareTo(a.monthKey));

            if (history.isEmpty) {
              return const WolfCard(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'لا يوجد تقييم أداء منشور لهذا الموظف بعد.',
                      style: TextStyle(color: ZaWolfColors.textMuted),
                    ),
                  ),
                ),
              );
            }

            return WolfCard(
              child: Column(
                children: history.take(6).map((item) {
                  final score = item.overallScore;
                  final scoreColor = score >= 85
                      ? ZaWolfColors.success
                      : score >= 70
                          ? ZaWolfColors.warning
                          : ZaWolfColors.error;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ZaWolfColors.surface02,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ZaWolfColors.surface03,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: scoreColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${score.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: scoreColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.monthKey} · التقدير: ${item.grade}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'الإنتاجية: ${item.overallScore.toStringAsFixed(0)}% · التزام الحضور: ${item.attendanceScore.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: ZaWolfColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: ZaWolfColors.surface03,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.grade,
                            style: TextStyle(
                              color: scoreColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: ZaWolfColors.primaryCyan, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: ZaWolfColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _metricStatCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: ZaWolfColors.surface01,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: ZaWolfColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attendanceRow(AttendancePeriodDay item) {
    final label = item.isAbsent ? 'غائب' : (item.isLate ? 'متأخر' : 'حاضر');
    final color = label == 'غائب'
        ? ZaWolfColors.error
        : label == 'متأخر'
            ? ZaWolfColors.warning
            : ZaWolfColors.success;

    final checkIn = item.attendance?.checkInTime;
    final timeStr = checkIn == null
        ? 'لم يسجل حضوراً'
        : 'تسجيل: ${DateFormat('hh:mm a').format(checkIn)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface02,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            item.dateKey,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              timeStr,
              style: const TextStyle(color: ZaWolfColors.textSecondary, fontSize: 12),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
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
