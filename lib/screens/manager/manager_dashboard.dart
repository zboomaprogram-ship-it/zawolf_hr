import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../services/auth_service.dart';
import '../../services/dashboard_attendance_summary_service.dart';
import '../../services/pending_requests_service.dart';
import '../../services/task_service.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../theme/theme.dart';
import '../../components/attendance_insights_card.dart';
import '../../components/wolf_card.dart';
import '../../design_system/tokens.dart';
import '../../design_system/components/priority_strip.dart';
import '../../design_system/components/section_header.dart';
import '../../design_system/components/stat_card.dart';
import '../widgets/end_of_day_briefing_card.dart';
import '../../components/team_leaderboard_card.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DashboardAttendanceSummaryService _summaryService =
      DashboardAttendanceSummaryService();
  final TaskService _taskService = TaskService();
  Future<DashboardAttendanceSummary>? _attendanceSummaryFuture;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _todayAttendanceStream;
  String? _todayAttendanceStreamKey;

  void _loadAttendanceSummary() {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;
    setState(() {
      _attendanceSummaryFuture = _buildAttendanceSummaryFuture(user);
    });
  }

  Future<DashboardAttendanceSummary> _buildAttendanceSummaryFuture(
    UserModel user,
  ) {
    return _summaryService
        .loadForReviewer(user)
        .timeout(const Duration(seconds: 20));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _attendanceForToday(
    String managerId,
    String date,
  ) {
    final key = '$managerId|$date';
    if (_todayAttendanceStream == null || _todayAttendanceStreamKey != key) {
      _todayAttendanceStreamKey = key;
      _todayAttendanceStream = _db
          .collection('attendance')
          .where('managerId', isEqualTo: managerId)
          .where('date', isEqualTo: date)
          .snapshots();
    }
    return _todayAttendanceStream!;
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final manager = authService.currentUser;
    final theme = Theme.of(context);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (manager == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }

    _attendanceSummaryFuture ??= _buildAttendanceSummaryFuture(manager);

    return Scaffold(
      appBar: AppBar(
        title: Text('لوحة المدير', style: theme.textTheme.headlineMedium),
        actions: [
          IconButton(
            tooltip: 'بصمتي الشخصية (تسجيل الحضور)',
            icon: const Icon(
              Icons.fingerprint,
              color: ZaWolfColors.primaryCyan,
              size: 28,
            ),
            onPressed: () => context.push('/employee/dashboard'),
          ),
          IconButton(
            tooltip: 'كشوف حضور الفريق',
            icon: const Icon(
              Icons.co_present_outlined,
              color: ZaWolfColors.primaryCyan,
            ),
            onPressed: () => context.push('/manager/team'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: ZaWolfColors.error),
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _attendanceForToday(manager.uid, todayStr),
        builder: (context, snapshot) {
          List<Map<String, dynamic>> teamList = [];

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              teamList.add(data);
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ZaWolfColors.surface01,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ZaWolfColors.surface03),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: ZaWolfColors.primaryCyan.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ZaWolfColors.primaryCyan.withValues(
                              alpha: 0.24,
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.manage_accounts,
                          color: ZaWolfColors.primaryCyan,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'مرحباً، ${manager.displayName}',
                              style: theme.textTheme.headlineSmall!.copyWith(
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.rtl,
                            ),
                            Text(
                              'إدارة قسم ${manager.department} · ${manager.locationName}',
                              style: theme.textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Priority strip + key metrics (from existing sources)
                ValueListenableBuilder<int>(
                  valueListenable: PendingRequestsService.instance.pendingCount,
                  builder: (context, pendingCount, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PriorityStrip(
                        items: [
                          PriorityItem(
                            label: 'بصمتي الشخصية (تسجيل الحضور)',
                            count: 0,
                            icon: Icons.fingerprint,
                            accent: ZaWolfColors.primaryCyan,
                            onTap: () => context.go('/employee/dashboard'),
                          ),
                          PriorityItem(
                            label: 'كشوف وتأخير فريقي',
                            count: 0,
                            icon: Icons.co_present_outlined,
                            accent: ZaWolfColors.primaryBlue,
                            onTap: () => context.go('/manager/team'),
                          ),
                          PriorityItem(
                            label: 'طلب معلق بانتظار موافقتك',
                            count: pendingCount,
                            icon: Icons.pending_actions,
                            accent: ZaWolfColors.warning,
                            onTap: () => context.go('/manager/requests'),
                          ),
                        ],
                      ),
                      EndOfDayBriefingCard(isHr: false, managerUid: manager.uid),
                      const TeamLeaderboardCard(),
                      const SizedBox(height: DsSpacing.md),
                    ],
                  ),
                ),
                _ManagerMetricsRow(
                  summaryFuture: _attendanceSummaryFuture!,
                  taskStream: _taskService.watchManagedTasks(manager),
                ),
                const SizedBox(height: DsSpacing.xl),

                FutureBuilder<DashboardAttendanceSummary>(
                  future: _attendanceSummaryFuture,
                  builder: (context, summarySnapshot) {
                    if (summarySnapshot.hasError) {
                      return WolfCard(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: ZaWolfColors.warning,
                                size: 32,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'تعذر تحميل ملخص حضور الفريق',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'تحقق من الصلاحيات أو الاتصال ثم أعد المحاولة.',
                                style: theme.textTheme.bodySmall,
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _loadAttendanceSummary,
                                icon: const Icon(Icons.refresh),
                                label: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (!summarySnapshot.hasData) {
                      return const WolfCard(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: CircularProgressIndicator(
                              color: ZaWolfColors.primaryCyan,
                            ),
                          ),
                        ),
                      );
                    }
                    return AttendanceInsightsCard(
                      summary: summarySnapshot.data!,
                      onRefresh: _loadAttendanceSummary,
                      onTap: () => context.go('/manager/attendance-summary'),
                      onCategoryTap: (status) => context.go(
                        '/manager/attendance-summary?status=$status',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Quick Navigation Grid
                SectionHeader(
                  title: 'إجراءات سريعة',
                  actionLabel: 'عرض الكل',
                  onAction: () => context.go('/hub/performance'),
                ),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: MediaQuery.sizeOf(context).width >= 1200
                      ? 4
                      : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: MediaQuery.sizeOf(context).width >= 1200
                      ? 1.65
                      : 1.5,
                  children: [
                    _buildQuickActionCard(
                      'بصمتي الشخصية',
                      'تسجيل حضورك اليومي الشخصي',
                      Icons.fingerprint,
                      () => context.go('/employee/dashboard'),
                      theme,
                    ),
                    _buildQuickActionCard(
                      'طلبات فريقي',
                      'الطلبات المعلقة والمراجعة',
                      Icons.checklist_rtl,
                      () => context.go('/manager/requests'),
                      theme,
                    ),
                    _buildQuickActionCard(
                      'سجل حضور الفريق',
                      'كشوف الحضور والغياب والتأخير',
                      Icons.assessment_outlined,
                      () => context.go('/manager/team'),
                      theme,
                    ),
                    if (kIsWeb)
                      _buildQuickActionCard(
                        'ملفات الفريق',
                        'منح الوصول إلى ملفات ومصادر القسم',
                        Icons.folder_shared_outlined,
                        () => context.go('/workspace'),
                        theme,
                      ),
                    _buildQuickActionCard(
                      'مهام الفريق',
                      'توزيع ومتابعة التنفيذ',
                      Icons.task_alt_outlined,
                      () => context.go('/manager/tasks'),
                      theme,
                    ),
                    _buildQuickActionCard(
                      'أهداف KPI',
                      'أهداف الشهر وتقدم الفريق',
                      Icons.flag_outlined,
                      () => context.go('/manager/kpi'),
                      theme,
                    ),
                    _buildQuickActionCard(
                      'ترتيب الإنتاجية',
                      'أفضل وأضعف أداء هذا الشهر',
                      Icons.leaderboard_outlined,
                      () => context.go('/manager/productivity'),
                      theme,
                    ),
                    _buildQuickActionCard(
                      'إنذارات ومكافآت',
                      'اقتراحات وإجراءات إدارية',
                      Icons.workspace_premium_outlined,
                      () => context.go('/manager/warnings-rewards'),
                      theme,
                    ),
                    _buildQuickActionCard(
                      'خدمات الشركة',
                      'الخدمات والطلبات التشغيلية',
                      Icons.business_center_outlined,
                      () => context.go('/company-os'),
                      theme,
                    ),
                    _buildQuickActionCard(
                      'عمليات الشركة',
                      'متابعة العمليات والتدقيق',
                      Icons.hub_outlined,
                      () => context.go('/company-os/operations'),
                      theme,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Live attendance list
                SectionHeader(
                  title: 'تتبع الحضور اليومي فريقي',
                  actionLabel: 'عرض الكل',
                  onAction: () => context.go('/manager/team'),
                ),

                if (teamList.isEmpty)
                  WolfCard(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.people_outline,
                              color: ZaWolfColors.textMuted,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'لا توجد عمليات حضور مسجلة اليوم بعد',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: teamList.length,
                    itemBuilder: (context, index) {
                      final log = teamList[index];
                      final name = log['employeeName'] as String? ?? '';
                      final empId = log['employeeId'] as String? ?? '';
                      final status = log['status'] as String? ?? '';
                      final checkIn = log['checkInTime'] as Timestamp?;

                      Color statusColor = ZaWolfColors.success;
                      String statusText = 'حاضر';
                      if (status == 'late') {
                        statusColor = ZaWolfColors.warning;
                        statusText = 'متأخر';
                      } else if (status == 'absent') {
                        statusColor = ZaWolfColors.error;
                        statusText = 'غائب';
                      } else if (status == 'on-leave') {
                        statusColor = ZaWolfColors.primaryBlue;
                        statusText = 'إجازة';
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: WolfCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        name,
                                        style: theme.textTheme.titleMedium!
                                            .copyWith(color: Colors.white),
                                      ),
                                      Text(
                                        'كود: $empId${checkIn != null ? ' · حضور: ${DateFormat('hh:mm a').format(checkIn.toDate())}' : ''}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  CircleAvatar(
                                    backgroundColor: ZaWolfColors.surface03,
                                    child: Text(
                                      name.substring(0, 1),
                                      style: const TextStyle(
                                        color: ZaWolfColors.primaryCyan,
                                      ),
                                    ),
                                  ),
                                ],
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
        },
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    ThemeData theme,
  ) {
    return WolfCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: DsSpacing.xs,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: ZaWolfColors.primaryCyan, size: 26),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.titleMedium!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall!.copyWith(fontSize: 9.5),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Metrics row: team present now, pending approvals, tasks due this week.
/// All values come from sources this dashboard or its children already load.
class _ManagerMetricsRow extends StatelessWidget {
  const _ManagerMetricsRow({
    required this.summaryFuture,
    required this.taskStream,
  });

  final Future<DashboardAttendanceSummary> summaryFuture;
  final Stream<List<EmployeeTaskModel>> taskStream;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: PendingRequestsService.instance.pendingCount,
      builder: (context, pendingCount, _) =>
          StreamBuilder<List<EmployeeTaskModel>>(
            stream: taskStream,
            builder: (context, taskSnapshot) {
              final loadingTasks =
                  !taskSnapshot.hasData && !taskSnapshot.hasError;
              final now = DateTime.now();
              final weekEnd = now.add(const Duration(days: 7));
              final tasksDueThisWeek =
                  (taskSnapshot.data ?? const <EmployeeTaskModel>[])
                      .where(
                        (task) =>
                            task.status != TaskStatus.done &&
                            task.status != TaskStatus.cancelled &&
                            !task.dueDate.isBefore(now) &&
                            !task.dueDate.isAfter(weekEnd),
                      )
                      .length;
              return FutureBuilder<DashboardAttendanceSummary>(
                future: summaryFuture,
                builder: (context, snapshot) {
                  final loading = !snapshot.hasData && !snapshot.hasError;
                  final summary = snapshot.data;
                  return Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: Icons.how_to_reg_outlined,
                          value: loading || summary == null
                              ? '—'
                              : '${summary.attended}/${summary.totalEmployees}',
                          label: 'الفريق الآن',
                          onTap: () => context.go('/manager/team'),
                        ),
                      ),
                      const SizedBox(width: DsSpacing.md),
                      Expanded(
                        child: StatCard(
                          icon: Icons.rule_outlined,
                          value: '$pendingCount',
                          label: 'طلبات معلقة',
                          onTap: () => context.go('/manager/requests'),
                        ),
                      ),
                      const SizedBox(width: DsSpacing.md),
                      Expanded(
                        child: StatCard(
                          icon: Icons.task_alt_outlined,
                          value: loadingTasks ? '—' : '$tasksDueThisWeek',
                          label: 'مهام هذا الأسبوع',
                          onTap: () => context.go('/manager/tasks'),
                        ),
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
