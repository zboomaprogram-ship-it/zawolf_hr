import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../components/wolf_card.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/components/rtl_navigation.dart';
import '../../../models/attendance_model.dart';
import '../../../models/employee_role.dart';
import '../../../models/task_model.dart';
import '../../../models/user_model.dart';
import '../../../theme/theme.dart';
import 'month_activity_section.dart';
import 'web_kpi_bento_grid.dart';
import 'web_recent_chats_card.dart';
import 'web_tasks_card.dart';

/// Full desktop web dashboard layout for employees (width >= 980).
/// Adopts modern Bento Grid architecture and UI/UX Pro Max enterprise standards.
class EmployeeWebDashboardView extends StatelessWidget {
  final UserModel user;
  final List<AttendanceModel> logs;
  final AttendanceModel? todayLog;
  final double disciplineScore;
  final int workedDays;
  final int pendingRequestsCount;
  final Future<void> Function() onRefresh;
  final Stream<List<EmployeeTaskModel>>? taskStream;
  final bool webAttendanceAccess;
  final VoidCallback? onCheckInTap;
  final bool actionLoading;
  final String? attendanceActionLabel;
  final bool attendanceActionEnabled;

  const EmployeeWebDashboardView({
    super.key,
    required this.user,
    required this.logs,
    required this.todayLog,
    required this.disciplineScore,
    required this.workedDays,
    required this.pendingRequestsCount,
    required this.onRefresh,
    this.taskStream,
    this.webAttendanceAccess = false,
    this.onCheckInTap,
    this.actionLoading = false,
    this.attendanceActionLabel,
    this.attendanceActionEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String dateFormatted;
    try {
      dateFormatted = DateFormat('EEEE، d MMMM yyyy', 'ar').format(now);
    } catch (_) {
      dateFormatted =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        color: ZaWolfColors.primaryCyan,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Executive Welcome Header
              _buildExecutiveHeader(context, dateFormatted),
              const SizedBox(height: DsSpacing.xl),

              // 2. Bento Grid KPI Metrics
              WebKpiBentoGrid(
                user: user,
                disciplineScore: disciplineScore,
                workedDays: workedDays,
                todayLog: todayLog,
                pendingRequestsCount: pendingRequestsCount,
                taskStream: taskStream,
              ),
              const SizedBox(height: DsSpacing.xl),

              EmployeePersonalAnalysisCard(
                logs: logs,
                disciplineScore: disciplineScore,
                onOpenAttendance: () => context.go('/employee/attendance-history'),
                onRefresh: onRefresh,
                webAttendanceAccess: webAttendanceAccess,
              ),
              const SizedBox(height: DsSpacing.xl),

              // 3. Two-Column Split: Left (Tasks & Services) + Right (Chats & History)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1040;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (Tasks & Services)
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              WebTasksCard(
                                userId: user.uid,
                                taskStream: taskStream,
                              ),
                              const SizedBox(height: DsSpacing.xl),
                              _buildQuickServicesHub(context),
                            ],
                          ),
                        ),
                        const SizedBox(width: DsSpacing.xl),
                        // Right Column (Recent Chats & Monthly Attendance History)
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              WebRecentChatsCard(user: user),
                              const SizedBox(height: DsSpacing.xl),
                              WolfCard(
                                padding: const EdgeInsets.all(DsSpacing.lg),
                                child: MonthActivitySection(logs: logs),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  // Stacked layout for medium screen sizes
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      WebTasksCard(userId: user.uid, taskStream: taskStream),
                      const SizedBox(height: DsSpacing.xl),
                      WebRecentChatsCard(user: user),
                      const SizedBox(height: DsSpacing.xl),
                      _buildQuickServicesHub(context),
                      const SizedBox(height: DsSpacing.xl),
                      WolfCard(
                        padding: const EdgeInsets.all(DsSpacing.lg),
                        child: MonthActivitySection(logs: logs),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveHeader(BuildContext context, String dateFormatted) {
    return WolfCard(
      padding: const EdgeInsets.all(22),
      borderColor: ZaWolfColors.primaryCyan.withValues(alpha: 0.35),
      shadowColor: ZaWolfColors.primaryCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // User Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: ZaWolfColors.primaryCyan.withValues(
                  alpha: 0.15,
                ),
                child: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName.characters.first
                      : 'Z',
                  style: const TextStyle(
                    color: ZaWolfColors.primaryCyan,
                    fontSize: 22,
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
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Text(
                          'مرحباً، ${user.displayName}',
                          style: const TextStyle(
                            color: ZaWolfColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: ZaWolfColors.primaryCyan.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: ZaWolfColors.primaryCyan.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Text(
                            EmployeeRole.arabicLabel(user.role),
                            style: const TextStyle(
                              color: ZaWolfColors.primaryCyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateFormatted • ${user.department.isNotEmpty ? user.department : "فريق العمل"}',
                      style: const TextStyle(
                        color: ZaWolfColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Mobile Attendance Check-In Notice Pill vs Web Attendance Check-In Button
              if (webAttendanceAccess)
                _buildWebAttendanceAction(context)
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: ZaWolfColors.surface02,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ZaWolfColors.surface03),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.phone_android_rounded,
                        color: ZaWolfColors.primaryCyan,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تسجيل الحضور عبر تطبيق الجوال',
                            style: TextStyle(
                              color: ZaWolfColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'متاح حصراً عبر تطبيق الهاتف لضمان التحقق البيومتري',
                            style: TextStyle(
                              color: ZaWolfColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: ZaWolfColors.surface03),
          const SizedBox(height: 14),
          // Quick header shortcuts
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildShortcutButton(
                context: context,
                label: 'تقديم طلب جديد',
                icon: Icons.add_circle_outline_rounded,
                route: '/employee/requests',
                isPrimary: true,
              ),
              _buildShortcutButton(
                context: context,
                label: 'قائمة مهامي',
                icon: Icons.task_alt_rounded,
                route: '/employee/tasks',
              ),
              _buildShortcutButton(
                context: context,
                label: 'غرفة المحادثات',
                icon: Icons.forum_outlined,
                route: '/conversations',
              ),
              _buildShortcutButton(
                context: context,
                label: 'كشف الراتب',
                icon: Icons.payments_outlined,
                route: '/employee/payroll',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebAttendanceAction(BuildContext context) {
    final bool hasCheckedIn = todayLog?.checkInTime != null;
    final bool hasCheckedOut = hasCheckedIn && todayLog?.checkOutTime != null;

    if (hasCheckedOut) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: ZaWolfColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ZaWolfColors.success.withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: ZaWolfColors.success,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'اكتمل الحضور والانصراف اليوم',
              style: TextStyle(
                color: ZaWolfColors.success,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final String label =
        attendanceActionLabel ??
        (!hasCheckedIn ? 'تسجيل حضور عبر الويب' : 'تسجيل انصراف عبر الويب');

    return ElevatedButton.icon(
      onPressed:
          (attendanceActionEnabled && !actionLoading) ? onCheckInTap : null,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            !hasCheckedIn ? ZaWolfColors.primaryCyan : ZaWolfColors.warning,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon:
          actionLoading
              ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
              : Icon(
                !hasCheckedIn ? Icons.login_rounded : Icons.logout_rounded,
                size: 18,
              ),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildShortcutButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required String route,
    bool isPrimary = false,
  }) {
    if (isPrimary) {
      return FilledButton.icon(
        onPressed: () => context.go(route),
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: ZaWolfColors.primaryCyan,
          foregroundColor: ZaWolfColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => context.go(route),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: ZaWolfColors.textPrimary,
        side: const BorderSide(color: ZaWolfColors.surface03),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildQuickServicesHub(BuildContext context) {
    final services = [
      (
        title: 'كشف الراتب',
        subtitle: 'تفاصيل الراتب والبدلات والخصومات',
        icon: Icons.payments_outlined,
        color: ZaWolfColors.primaryCyan,
        route: '/employee/payroll',
      ),
      (
        title: 'تقديم ومتابعة الطلبات',
        subtitle: 'إجازات، أذونات، سلف، وتصحيح حضور',
        icon: Icons.assignment_outlined,
        color: ZaWolfColors.warning,
        route: '/employee/requests',
      ),
      (
        title: 'حجز قاعة / طلب اجتماع',
        subtitle: 'جدولة الاجتماعات والقاعات المتاحة',
        icon: Icons.meeting_room_outlined,
        color: ZaWolfColors.primaryCyan,
        route: '/employee/meeting-request',
      ),
      (
        title: 'تقييم الأداء والـ KPI',
        subtitle: 'متابعة أهدافك وتقييمات الإدارة',
        icon: Icons.bar_chart_rounded,
        color: ZaWolfColors.warning,
        route: '/employee/performance',
      ),
      (
        title: 'الطلبات المخصصة',
        subtitle: 'تقديم طلبات النماذج المخصصة',
        icon: Icons.playlist_add_check_outlined,
        color: ZaWolfColors.permissionTeal,
        route: '/employee/custom-requests',
      ),
      (
        title: 'المحادثات والتواصل',
        subtitle: 'التواصل الداخلي وغرف العمل',
        icon: Icons.chat_bubble_outline_rounded,
        color: ZaWolfColors.success,
        route: '/conversations',
      ),
      (
        title: 'صندوق المقترحات',
        subtitle: 'شارك أفكارك ومقترحات التطوير',
        icon: Icons.lightbulb_outline_rounded,
        color: ZaWolfColors.warning,
        route: '/employee/suggestions',
      ),
      (
        title: 'الملف الشخصي',
        subtitle: 'بيانات الحساب وإعدادات النظام',
        icon: Icons.person_outline_rounded,
        color: ZaWolfColors.dayoffPurple,
        route: '/employee/profile',
      ),
    ];

    return WolfCard(
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ZaWolfColors.primaryCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: ZaWolfColors.primaryCyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: DsSpacing.md),
              const Text(
                'الخدمات السريعة وبوابة الموظف',
                style: TextStyle(
                  color: ZaWolfColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          const Divider(height: 1, color: ZaWolfColors.surface03),
          const SizedBox(height: DsSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.7,
            ),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final s = services[index];
              return InkWell(
                onTap: () => context.go(s.route),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ZaWolfColors.surface02,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ZaWolfColors.surface03),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: s.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(s.icon, color: s.color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              s.title,
                              style: const TextStyle(
                                color: ZaWolfColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.subtitle,
                              style: const TextStyle(
                                color: ZaWolfColors.textMuted,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        RtlNavigation.chevronEnd(context),
                        color: ZaWolfColors.textMuted,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


/// Personal read-only trend for web. Biometric check-in and check-out remain
/// mobile-only; this card makes the resulting status and period clear.
class EmployeePersonalAnalysisCard extends StatefulWidget {
  const EmployeePersonalAnalysisCard({
    super.key,
    required this.logs,
    required this.disciplineScore,
    required this.onOpenAttendance,
    required this.onRefresh,
    this.webAttendanceAccess = false,
  });
  final List<AttendanceModel> logs;
  final double disciplineScore;
  final VoidCallback onOpenAttendance;
  final Future<void> Function() onRefresh;
  final bool webAttendanceAccess;

  @override
  State<EmployeePersonalAnalysisCard> createState() => _EmployeePersonalAnalysisCardState();
}

class _EmployeePersonalAnalysisCardState extends State<EmployeePersonalAnalysisCard> with WidgetsBindingObserver {
  int _days = 7;
  DateTimeRange? _custom;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => widget.onRefresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.onRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = _custom?.start ?? end.subtract(Duration(days: _days - 1));
    final finish = _custom?.end ?? end;
    final visible = widget.logs.where((log) {
      final date = DateTime.tryParse(log.date);
      return date != null && !date.isBefore(start) && !date.isAfter(finish);
    }).toList();
    final late = visible.where((log) => log.isLate || log.status == 'late').length;
    final attended = visible.where((log) => log.checkInTime != null).length;
    return WolfCard(
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('تحليل حضوري الشخصي', textDirection: TextDirection.rtl, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 2),
            Text(
              widget.webAttendanceAccess
                  ? 'تسجيل الحضور والانصراف مفعّل عبر الويب وتطبيق الجوال.'
                  : 'تسجيل الحضور والانصراف البيومتري يتم عبر تطبيق الجوال.',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(color: ZaWolfColors.textSecondary, fontSize: 12),
            ),
          ])),
          const Icon(Icons.insights_outlined, color: ZaWolfColors.primaryCyan),
        ]),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
          ChoiceChip(label: const Text('7 أيام'), selected: _days == 7 && _custom == null, onSelected: (_) => setState(() {_days = 7; _custom = null;})),
          ChoiceChip(label: const Text('30 يوم'), selected: _days == 30 && _custom == null, onSelected: (_) => setState(() {_days = 30; _custom = null;})),
          ActionChip(label: const Text('تاريخ مخصص'), avatar: const Icon(Icons.date_range_outlined, size: 18), onPressed: _selectRange),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _stat('أيام حضور', '$attended', ZaWolfColors.success),
          const SizedBox(width: 10),
          _stat('تأخير', '$late', ZaWolfColors.warning),
          const SizedBox(width: 10),
          _stat('الانضباط', '${widget.disciplineScore.round()}%', ZaWolfColors.primaryCyan),
        ]),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: widget.onOpenAttendance, icon: Icon(RtlNavigation.chevronEnd(context)), label: const Text('عرض تفاصيل الحضور'))),
      ]),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(10)), child: Column(children: [Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)), Text(label, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 11, color: ZaWolfColors.textSecondary))])));

  Future<void> _selectRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: now, initialDateRange: _custom);
    if (range == null || !mounted) return;
    if (range.end.difference(range.start).inDays + 1 > 31) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الفترة المخصصة لا تتجاوز 31 يوماً.')));
      return;
    }
    setState(() => _custom = range);
  }
}
