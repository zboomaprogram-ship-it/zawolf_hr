import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../manager/widgets/unified_management_web_dashboard.dart';

import '../../components/attendance_insights_card.dart';
import '../../components/wolf_card.dart';
import '../../design_system/components/avatar.dart';
import '../../design_system/components/priority_strip.dart';
import '../../design_system/components/section_header.dart';
import '../../design_system/components/stat_card.dart';
import '../../design_system/tokens.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_attendance_summary_service.dart';
import '../../services/pending_requests_service.dart';
import '../../services/task_service.dart';
import '../../theme/theme.dart';

class TeamLeaderDashboardScreen extends StatefulWidget {
  const TeamLeaderDashboardScreen({super.key});

  @override
  State<TeamLeaderDashboardScreen> createState() =>
      _TeamLeaderDashboardScreenState();
}

class _TeamLeaderDashboardScreenState extends State<TeamLeaderDashboardScreen> {
  final _summaryService = DashboardAttendanceSummaryService();
  final _taskService = TaskService();
  Future<DashboardAttendanceSummary>? _summaryFuture;

  Future<DashboardAttendanceSummary> _load(UserModel user) {
    return _summaryService
        .loadForReviewer(user)
        .timeout(const Duration(seconds: 20));
  }

  void _refresh(UserModel user) {
    setState(() => _summaryFuture = _load(user));
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
    _summaryFuture ??= _load(user);

    final isDesktopWeb = kIsWeb && MediaQuery.sizeOf(context).width >= 980;
    if (isDesktopWeb) {
      return Scaffold(
        backgroundColor: ZaWolfColors.background,
        body: FutureBuilder<DashboardAttendanceSummary>(
          future: _summaryFuture,
          builder: (context, summarySnapshot) {
            return UnifiedManagementWebDashboard(
              user: user,
              summary: summarySnapshot.data,
              onRefreshSummary: () async => _refresh(user),
              taskStream: _taskService.watchManagedTasks(user),
              isHr: false,
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة قائد الفريق')),
      body: RefreshIndicator(
        color: ZaWolfColors.primaryCyan,
        onRefresh: () async => _refresh(user),
        child: ListView(
          padding: const EdgeInsets.all(DsSpacing.lg),
          children: [
            // 1. Header
            _TeamLeaderHeader(user: user),
            const SizedBox(height: DsSpacing.lg),

            // 2. Priority strip — pending approvals first
            ValueListenableBuilder<int>(
              valueListenable: PendingRequestsService.instance.pendingCount,
              builder: (context, pendingCount, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PriorityStrip(
                    items: [
                      PriorityItem(
                        label: 'طلب بانتظار موافقتك',
                        count: pendingCount,
                        icon: Icons.rule_outlined,
                        accent: ZaWolfColors.warning,
                        onTap: () => context.go('/team-leader/requests'),
                      ),
                    ],
                  ),
                  const SizedBox(height: DsSpacing.md),
                ],
              ),
            ),

            // 3. Metrics row (max four)
            _TeamLeaderMetricsRow(
              summaryFuture: _summaryFuture!,
              onRetry: () => _refresh(user),
              taskStream: _taskService.watchManagedTasks(user),
            ),
            const SizedBox(height: DsSpacing.xl),

            // Section: team attendance today
            FutureBuilder<DashboardAttendanceSummary>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return WolfCard(
                    child: ListTile(
                      leading: IconButton(
                        tooltip: 'إعادة المحاولة',
                        onPressed: () => _refresh(user),
                        icon: const Icon(Icons.refresh),
                      ),
                      title: const Text('تعذر تحميل حالة حضور الفريق.'),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const WolfCard(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: ZaWolfColors.primaryCyan,
                        ),
                      ),
                    ),
                  );
                }
                return AttendanceInsightsCard(
                  summary: snapshot.data!,
                  onRefresh: () => _refresh(user),
                  onTap: () => context.go('/team-leader/attendance-summary'),
                  onCategoryTap: (status) => context.go(
                    '/team-leader/attendance-summary?status=$status',
                  ),
                );
              },
            ),
            const SizedBox(height: DsSpacing.xl),

            // Section: team actions
            SectionHeader(
              title: 'إجراءات الفريق',
              actionLabel: 'عرض الكل',
              onAction: () => context.go('/hub/performance'),
            ),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.analytics_outlined,
                    title: 'تفاصيل الحضور',
                    onTap: () => context.go('/team-leader/attendance-summary'),
                  ),
                ),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.people_outline,
                    title: 'أعضاء فريقي',
                    onTap: () => context.go('/team-leader/employees'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.task_alt_outlined,
                    title: 'مهام الفريق',
                    onTap: () => context.go('/team-leader/tasks'),
                  ),
                ),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.rule_rounded,
                    title: 'الموافقات',
                    onTap: () => context.go('/team-leader/requests'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.xl),
            SectionHeader(
              title: 'خدمات الشركة',
              actionLabel: 'فتح البوابة',
              onAction: () => context.go('/company-os'),
            ),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.business_center_outlined,
                    title: 'بوابة خدمات الشركة',
                    onTap: () => context.go('/company-os'),
                  ),
                ),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.add_task_outlined,
                    title: 'طلب تقني أو مالي',
                    onTap: () =>
                        context.go('/employee/requests/operational/new'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamLeaderHeader extends StatelessWidget {
  const _TeamLeaderHeader({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WolfCard(
      child: Row(
        children: [
          DsAvatar(name: user.displayName, size: 46),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'مرحباً، ${user.displayName}',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                ),
                Text(
                  '${user.position} · ${user.department}',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Metrics sourced only from providers this dashboard already loads.
class _TeamLeaderMetricsRow extends StatelessWidget {
  const _TeamLeaderMetricsRow({
    required this.summaryFuture,
    required this.onRetry,
    required this.taskStream,
  });

  final Future<DashboardAttendanceSummary> summaryFuture;
  final VoidCallback onRetry;
  final Stream<List<EmployeeTaskModel>> taskStream;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: PendingRequestsService.instance.pendingCount,
      builder: (context, pendingCount, _) => StreamBuilder<List<EmployeeTaskModel>>(
        stream: taskStream,
        builder: (context, taskSnapshot) {
          final loadingTasks = !taskSnapshot.hasData && !taskSnapshot.hasError;
          final openTasks = (taskSnapshot.data ?? const <EmployeeTaskModel>[])
              .where(
                (task) =>
                    task.status != TaskStatus.done &&
                    task.status != TaskStatus.cancelled,
              )
              .length;
          return FutureBuilder<DashboardAttendanceSummary>(
            future: summaryFuture,
            builder: (context, snapshot) {
              final loadingSummary = !snapshot.hasData && !snapshot.hasError;
              final summary = snapshot.data;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: Icons.how_to_reg_outlined,
                          value: loadingSummary || summary == null
                              ? '—'
                              : '${summary.attended}/${summary.totalEmployees}',
                          label: 'حضور اليوم',
                          onTap: () =>
                              context.go('/team-leader/attendance-summary'),
                        ),
                      ),
                      const SizedBox(width: DsSpacing.md),
                      Expanded(
                        child: StatCard(
                          icon: Icons.schedule_outlined,
                          value: loadingSummary || summary == null
                              ? '—'
                              : '${summary.late}',
                          label: 'متأخر اليوم',
                          onTap: () => context.go(
                            '/team-leader/attendance-summary?status=late',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DsSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: Icons.rule_outlined,
                          value: '$pendingCount',
                          label: 'طلبات معلقة',
                          onTap: () => context.go('/team-leader/requests'),
                        ),
                      ),
                      const SizedBox(width: DsSpacing.md),
                      Expanded(
                        child: StatCard(
                          icon: Icons.task_alt_outlined,
                          value: loadingTasks ? '—' : '$openTasks',
                          label: 'مهام مفتوحة',
                          onTap: () => context.go('/team-leader/tasks'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return WolfCard(
      onTap: onTap,
      child: SizedBox(
        height: 92,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: ZaWolfColors.primaryCyan, size: 28),
            const SizedBox(height: DsSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
