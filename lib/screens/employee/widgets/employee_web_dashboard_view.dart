import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../components/wolf_card.dart';
import '../../../design_system/tokens.dart';
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
                            color: Colors.white,
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
              // Mobile Attendance Check-In Notice Pill
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
                            color: Colors.white,
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
          foregroundColor: Colors.black,
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
        foregroundColor: Colors.white,
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
        title: 'تقييم الأداء والـ KPI',
        subtitle: 'متابعة أهدافك وتقييمات الإدارة',
        icon: Icons.bar_chart_rounded,
        color: ZaWolfColors.warning,
        route: '/employee/performance',
      ),
      (
        title: 'صندوق المقترحات',
        subtitle: 'شارك أفكارك ومقترحات التطوير',
        icon: Icons.lightbulb_outline_rounded,
        color: Colors.tealAccent,
        route: '/employee/suggestions',
      ),
      (
        title: 'الملف الشخصي',
        subtitle: 'بيانات الحساب وإعدادات النظام',
        icon: Icons.person_outline_rounded,
        color: Colors.purpleAccent,
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
                  color: Colors.white,
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
                                color: Colors.white,
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
                      const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: ZaWolfColors.textMuted,
                        size: 13,
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
