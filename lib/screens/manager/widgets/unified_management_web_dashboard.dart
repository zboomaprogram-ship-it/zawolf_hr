import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../components/attendance_insights_card.dart';
import '../../../components/sales_kpi_summary_card.dart';
import '../../../components/team_leaderboard_card.dart';
import '../../../components/wolf_card.dart';
import '../../../design_system/components/priority_strip.dart';
import '../../../design_system/tokens.dart';
import '../../../models/attendance_model.dart';
import '../../../models/employee_role.dart';
import '../../../models/sales_kpi_summary.dart';
import '../../../models/task_model.dart';
import '../../../models/user_model.dart';
import '../../../services/attendance_service.dart';
import '../../../services/dashboard_attendance_summary_service.dart';
import '../../../services/pending_requests_service.dart';
import '../../../services/sales_kpi_integration_service.dart';
import '../../../theme/theme.dart';
import '../../../utils/payroll_cycle.dart';
import '../../employee/widgets/web_recent_chats_card.dart';

/// Unified enterprise command center for management roles (Manager, Team Leader, HR, Executive, SuperAdmin).
/// Merges personal daily operations (attendance punch, recent chats) with executive management
/// (approvals, team presence, sales KPIs, and leaderboard) into a single cohesive, high-efficiency dashboard.
class UnifiedManagementWebDashboard extends StatefulWidget {
  final UserModel user;
  final DashboardAttendanceSummary? summary;
  final Future<void> Function() onRefreshSummary;
  final Stream<List<EmployeeTaskModel>>? taskStream;
  final bool isHr;

  const UnifiedManagementWebDashboard({
    super.key,
    required this.user,
    required this.summary,
    required this.onRefreshSummary,
    this.taskStream,
    this.isHr = false,
  });

  @override
  State<UnifiedManagementWebDashboard> createState() =>
      _UnifiedManagementWebDashboardState();
}

class _UnifiedManagementWebDashboardState
    extends State<UnifiedManagementWebDashboard> {
  Stream<List<AttendanceModel>>? _personalAttendanceStream;
  String? _selectedSalesKpiPeriod;

  @override
  void initState() {
    super.initState();
    _initPersonalAttendanceStream();
  }

  @override
  void didUpdateWidget(covariant UnifiedManagementWebDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _initPersonalAttendanceStream();
    }
  }

  void _initPersonalAttendanceStream() {
    final currentMonthKey = PayrollCycle.keyFor(DateTime.now());
    _personalAttendanceStream = AttendanceService().watchMonthlyAttendance(
      widget.user.uid,
      currentMonthKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    String dateFormatted;
    try {
      dateFormatted = DateFormat('EEEE، d MMMM yyyy', 'ar').format(now);
    } catch (_) {
      dateFormatted = todayStr;
    }

    final isSuper = EmployeeRole.isSuperAdmin(widget.user.role);
    final isHrRole = widget.isHr || EmployeeRole.isHr(widget.user.role);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Executive Welcome Header with Integrated Personal Attendance Action
            StreamBuilder<List<AttendanceModel>>(
              stream: _personalAttendanceStream,
              builder: (context, attendanceSnapshot) {
                final logs = attendanceSnapshot.data ?? const [];
                final todayLog = logs.cast<AttendanceModel?>().firstWhere(
                  (log) => log?.date == todayStr,
                  orElse: () => null,
                );

                return _buildUnifiedHeader(
                  context,
                  theme,
                  dateFormatted,
                  todayLog,
                  isSuper,
                  isHrRole,
                );
              },
            ),
            const SizedBox(height: DsSpacing.xl),

            // 2. Executive Quick Metric Strip
            _buildMetricsStrip(context, theme, isHrRole),
            const SizedBox(height: DsSpacing.xl),

            // 3. Priority Approval Strip
            ValueListenableBuilder<int>(
              valueListenable: PendingRequestsService.instance.pendingCount,
              builder: (context, pendingCount, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PriorityStrip(
                      items: [
                        PriorityItem(
                          label: 'طلب معلق بانتظار موافقتك',
                          count: pendingCount,
                          icon: Icons.pending_actions,
                          accent: ZaWolfColors.warning,
                          onTap: () => _openPendingApprovals(context, isHrRole),
                        ),
                        PriorityItem(
                          label: 'كشوف وتأخيرات الفريق',
                          count: 0,
                          icon: Icons.co_present_outlined,
                          accent: ZaWolfColors.primaryBlue,
                          onTap: () => context.go(isHrRole ? '/hr/employees' : '/manager/team'),
                        ),
                        PriorityItem(
                          label: 'المحادثات والتواصل',
                          count: 0,
                          icon: Icons.chat_bubble_outline_rounded,
                          accent: ZaWolfColors.primaryCyan,
                          onTap: () => context.go('/conversations'),
                        ),
                      ],
                    ),
                    const SizedBox(height: DsSpacing.md),
                  ],
                );
              },
            ),

            // 4. Main Two-Column Layout (Operations & Presence + Messages & Tasks)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1080;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left / Operations Column (Approvals, Presence, Leaderboard)
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.summary != null)
                              AttendanceInsightsCard(
                                summary: widget.summary!,
                                onRefresh: widget.onRefreshSummary,
                                onTap: () => context.go(
                                  isHrRole
                                      ? '/hr/dashboard'
                                      : '/manager/attendance-summary',
                                ),
                                onCategoryTap: (status) => context.go(
                                  isHrRole
                                      ? '/hr/dashboard'
                                      : '/manager/attendance-summary?status=$status',
                                ),
                              )
                            else
                              const WolfCard(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: ZaWolfColors.primaryCyan,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: DsSpacing.xl),
                            _buildSalesKpiSection(theme),
                            const SizedBox(height: DsSpacing.xl),
                            const TeamLeaderboardCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: DsSpacing.xl),

                      // Right / Personal & Direct Communications Column
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Live Chats & Notifications Card
                            WebRecentChatsCard(user: widget.user),
                            const SizedBox(height: DsSpacing.xl),

                            // Quick Navigation Hub
                            _buildQuickActionsHub(context, theme, isHrRole),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                // Medium screens / stacked
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.summary != null)
                      AttendanceInsightsCard(
                        summary: widget.summary!,
                        onRefresh: widget.onRefreshSummary,
                        onTap: () => context.go(
                          isHrRole
                              ? '/hr/dashboard'
                              : '/manager/attendance-summary',
                        ),
                        onCategoryTap: (status) => context.go(
                          isHrRole
                              ? '/hr/dashboard'
                              : '/manager/attendance-summary?status=$status',
                        ),
                      ),
                    const SizedBox(height: DsSpacing.xl),
                    WebRecentChatsCard(user: widget.user),
                    const SizedBox(height: DsSpacing.xl),
                    _buildSalesKpiSection(theme),
                    const SizedBox(height: DsSpacing.xl),
                    const TeamLeaderboardCard(),
                    const SizedBox(height: DsSpacing.xl),
                    _buildQuickActionsHub(context, theme, isHrRole),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedHeader(
    BuildContext context,
    ThemeData theme,
    String dateFormatted,
    AttendanceModel? todayLog,
    bool isSuper,
    bool isHrRole,
  ) {
    final bool hasCheckedIn = todayLog?.checkInTime != null;
    final bool hasCheckedOut = hasCheckedIn && todayLog?.checkOutTime != null;

    return WolfCard(
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ZaWolfColors.primaryCyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ZaWolfColors.primaryCyan.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.dashboard_customize_rounded,
              color: ZaWolfColors.primaryCyan,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'مرحباً، ${widget.user.displayName}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ZaWolfColors.primaryCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: ZaWolfColors.primaryCyan.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        isSuper
                            ? 'الإدارة العامة'
                            : isHrRole
                                ? 'الموارد البشرية'
                                : 'إدارة قسم ${widget.user.department}',
                        style: const TextStyle(
                          color: ZaWolfColors.primaryCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$dateFormatted · ${widget.user.position.isNotEmpty ? widget.user.position : 'مسؤول النظام'}',
                  style: const TextStyle(
                    color: ZaWolfColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Integrated Personal Attendance Punch Badge
          _buildPersonalPunchBadge(context, theme, hasCheckedIn, hasCheckedOut, todayLog),
        ],
      ),
    );
  }

  Widget _buildPersonalPunchBadge(
    BuildContext context,
    ThemeData theme,
    bool hasCheckedIn,
    bool hasCheckedOut,
    AttendanceModel? todayLog,
  ) {
    Color statusColor;
    String statusTitle;
    String statusSubtitle;
    IconData actionIcon;
    String actionLabel;

    if (hasCheckedOut && todayLog?.checkOutTime != null) {
      statusColor = ZaWolfColors.textSecondary;
      statusTitle = 'تم تسجيل الانصراف';
      statusSubtitle = DateFormat('hh:mm a', 'ar').format(todayLog!.checkOutTime!);
      actionIcon = Icons.check_circle_outline;
      actionLabel = 'مكتمل اليوم';
    } else if (hasCheckedIn && todayLog?.checkInTime != null) {
      statusColor = ZaWolfColors.success;
      statusTitle = 'حاضر بالعمل';
      statusSubtitle = 'منذ ${DateFormat('hh:mm a', 'ar').format(todayLog!.checkInTime!)}';
      actionIcon = Icons.logout_rounded;
      actionLabel = 'تسجيل انصراف';
    } else {
      statusColor = ZaWolfColors.warning;
      statusTitle = 'لم تسجل حضورك';
      statusSubtitle = 'سجل بصمتك الآن';
      actionIcon = Icons.fingerprint_rounded;
      actionLabel = 'تسجيل حضور';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface02,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
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
                  const SizedBox(width: 6),
                  Text(
                    statusTitle,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                statusSubtitle,
                style: const TextStyle(
                  color: ZaWolfColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => context.push('/employee/dashboard'),
            icon: Icon(actionIcon, size: 15),
            label: Text(actionLabel, style: const TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              backgroundColor: statusColor.withValues(alpha: 0.15),
              foregroundColor: statusColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsStrip(BuildContext context, ThemeData theme, bool isHrRole) {
    final summary = widget.summary;
    final presentCount = summary?.present ?? 0;
    final totalTeamCount = summary?.totalEmployees ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'حضور الفريق اليوم',
            value: totalTeamCount > 0 ? '$presentCount / $totalTeamCount' : '$presentCount حاضر',
            subtitle: 'محدث لحظياً',
            icon: Icons.people_alt_outlined,
            color: ZaWolfColors.success,
            onTap: () => context.go(isHrRole ? '/hr/dashboard' : '/manager/team'),
          ),
        ),
        const SizedBox(width: DsSpacing.md),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: PendingRequestsService.instance.pendingCount,
            builder: (context, pendingCount, _) {
              return _buildMetricTile(
                title: 'طلبات تحتاج اعتمادك',
                value: '$pendingCount طلب',
                subtitle: pendingCount > 0 ? 'تحتاج إجراء سريع' : 'تم مراجعة الكل',
                icon: Icons.pending_actions_outlined,
                color: pendingCount > 0 ? ZaWolfColors.warning : ZaWolfColors.primaryCyan,
                onTap: () => _openPendingApprovals(context, isHrRole),
              );
            },
          ),
        ),
        const SizedBox(width: DsSpacing.md),
        Expanded(
          child: _buildMetricTile(
            title: 'المحادثات المباشرة',
            value: 'تواصل فوري',
            subtitle: 'القنوات والرسائل الخاصة',
            icon: Icons.chat_outlined,
            color: ZaWolfColors.primaryCyan,
            onTap: () => context.go('/conversations'),
          ),
        ),
        const SizedBox(width: DsSpacing.md),
        Expanded(
          child: _buildMetricTile(
            title: 'المهام والتكليفات',
            value: 'متابعة العمل',
            subtitle: 'مهام قيد الإنجاز',
            icon: Icons.task_alt_outlined,
            color: ZaWolfColors.dayoffPurple,
            onTap: () => context.go(isHrRole ? '/hr/tasks' : '/manager/tasks'),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: WolfCard(
        padding: const EdgeInsets.all(DsSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: ZaWolfColors.textMuted,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: ZaWolfColors.textSecondary,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesKpiSection(ThemeData theme) {
    return StreamBuilder<SalesKpiSummary?>(
      stream: SalesKpiIntegrationService().watchCurrentSummary(),
      builder: (context, currentSnapshot) {
        final current = currentSnapshot.data;
        if (current == null) return const SizedBox.shrink();
        return StreamBuilder<List<SalesKpiSummary>>(
          stream: SalesKpiIntegrationService().watchSummaryHistory(),
          builder: (context, historySnapshot) {
            final seenKeys = <String>{current.periodKey};
            final history = <SalesKpiSummary>[
              current,
              ...?historySnapshot.data?.where(
                (item) =>
                    item.periodKey.isNotEmpty && seenKeys.add(item.periodKey),
              ),
            ];
            final selected = history.firstWhere(
              (item) => item.periodKey == _selectedSalesKpiPeriod,
              orElse: () => current,
            );
            return SalesKpiSummaryCard(
              summary: selected,
              history: history,
              onPeriodChanged: (value) => setState(
                () => _selectedSalesKpiPeriod = value.periodKey,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickActionsHub(BuildContext context, ThemeData theme, bool isHrRole) {
    return WolfCard(
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'روابط وإجراءات سريعة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: DsSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildShortcutChip(
                label: 'إدارة الطلبات',
                icon: Icons.assignment_outlined,
                onTap: () => _openPendingApprovals(context, isHrRole),
              ),
              _buildShortcutChip(
                label: 'سجل الحضور والغياب',
                icon: Icons.calendar_month_outlined,
                onTap: () => context.go(
                  isHrRole ? '/hr/attendance-summary' : '/manager/attendance-summary',
                ),
              ),
              _buildShortcutChip(
                label: isHrRole ? 'إدارة الموظفين' : 'كشوف وحضور فريقي',
                icon: Icons.co_present_outlined,
                onTap: () => context.go(isHrRole ? '/hr/employees' : '/manager/team'),
              ),
              _buildShortcutChip(
                label: 'الرواتب والمسيرات',
                icon: Icons.payments_outlined,
                onTap: () => context.go(isHrRole ? '/hr/payroll' : '/employee/payroll'),
              ),
              _buildShortcutChip(
                label: 'التقارير الإدارية',
                icon: Icons.assessment_outlined,
                onTap: () => context.go(isHrRole ? '/hr/reports' : '/manager/performance'),
              ),
              _buildShortcutChip(
                label: 'المحادثات والتواصل',
                icon: Icons.chat_bubble_outline_rounded,
                onTap: () => context.go('/conversations'),
              ),
              _buildShortcutChip(
                label: 'إعلان للفريق',
                icon: Icons.campaign_outlined,
                onTap: () => context.go('/hr/announcements'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: ZaWolfColors.primaryCyan),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: ZaWolfColors.surface02,
      side: const BorderSide(color: ZaWolfColors.surface03),
      onPressed: onTap,
    );
  }

  void _openPendingApprovals(BuildContext context, bool isHrRole) {
    final firstPending = PendingRequestsService.instance.firstPendingCategory;
    final basePath = isHrRole ? '/hr/requests' : '/manager/requests';
    if (firstPending != null) {
      final requestId = PendingRequestsService.instance.firstPendingRequestId(firstPending);
      final target = requestId == null
          ? '$basePath?category=$firstPending'
          : '$basePath?category=$firstPending&requestId=${Uri.encodeComponent(requestId)}';
      context.go(target);
    } else {
      context.go('$basePath?smart=true');
    }
  }
}
