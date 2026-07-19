import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../services/auth_service.dart';
import '../../services/dashboard_attendance_summary_service.dart';
import '../../models/user_model.dart';
import '../../theme/theme.dart';
import '../../components/attendance_insights_card.dart';
import '../../components/wolf_card.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DashboardAttendanceSummaryService _summaryService =
      DashboardAttendanceSummaryService();
  int _pendingCount = 0;
  bool _loadingRequests = true;
  Future<DashboardAttendanceSummary>? _attendanceSummaryFuture;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _todayAttendanceStream;
  String? _todayAttendanceStreamKey;

  @override
  void initState() {
    super.initState();
    _fetchPendingCounts();
  }

  Future<void> _fetchPendingCounts() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final managerId = authService.currentUser?.uid;
    if (managerId == null) return;

    try {
      final results = await Future.wait([
        _db
            .collection('leaves')
            .where('managerId', isEqualTo: managerId)
            .where('status', isEqualTo: 'pending')
            .get(),
        _db
            .collection('permissions')
            .where('managerId', isEqualTo: managerId)
            .where('status', isEqualTo: 'pending_manager')
            .get(),
      ]);

      int total = 0;
      for (var snap in results) {
        total += snap.docs.length;
      }

      if (mounted) {
        setState(() {
          _pendingCount = total;
          _loadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingRequests = false;
        });
      }
    }
  }

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
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Pending Requests Banner
                if (!_loadingRequests && _pendingCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: InkWell(
                      onTap: () => context.go('/manager/requests'),
                      borderRadius: BorderRadius.circular(8),
                      child: Ink(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ZaWolfColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ZaWolfColors.warning.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(
                              Icons.arrow_back_ios,
                              size: 16,
                              color: ZaWolfColors.warning,
                            ),
                            Row(
                              children: [
                                Text(
                                  'لديك $_pendingCount طلبات معلقة بانتظار موافقتك',
                                  style: theme.textTheme.titleMedium!.copyWith(
                                    color: ZaWolfColors.warning,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.pending_actions,
                                  color: ZaWolfColors.warning,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Quick Navigation Grid
                Text(
                  'إجراءات سريعة',
                  style: theme.textTheme.titleLarge!.copyWith(
                    color: Colors.white,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
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
                    _buildQuickActionCard(
                      'ملفات الفريق',
                      'بيانات الموظفين والأداء والغياب',
                      Icons.people_alt_outlined,
                      () => context.go('/manager/employees'),
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
                  ],
                ),
                const SizedBox(height: 24),

                // Live attendance list
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => context.go('/manager/team'),
                      child: const Text(
                        'عرض الكل',
                        style: TextStyle(color: ZaWolfColors.primaryCyan),
                      ),
                    ),
                    Text(
                      'تتبع الحضور اليومي فريقي',
                      style: theme.textTheme.titleLarge!.copyWith(
                        color: Colors.white,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: ZaWolfColors.primaryCyan, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall!.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
