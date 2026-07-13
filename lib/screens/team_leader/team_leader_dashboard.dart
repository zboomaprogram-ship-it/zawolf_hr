import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../components/attendance_insights_card.dart';
import '../../components/wolf_card.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_attendance_summary_service.dart';
import '../../theme/theme.dart';

class TeamLeaderDashboardScreen extends StatefulWidget {
  const TeamLeaderDashboardScreen({super.key});

  @override
  State<TeamLeaderDashboardScreen> createState() =>
      _TeamLeaderDashboardScreenState();
}

class _TeamLeaderDashboardScreenState extends State<TeamLeaderDashboardScreen> {
  final _summaryService = DashboardAttendanceSummaryService();
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
    final theme = Theme.of(context);
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }
    _summaryFuture ??= _load(user);

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة قائد الفريق')),
      body: RefreshIndicator(
        color: ZaWolfColors.primaryCyan,
        onRefresh: () async => _refresh(user),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            WolfCard(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: ZaWolfColors.primaryCyan.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.groups_2_outlined,
                      color: ZaWolfColors.primaryCyan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'مرحباً، ${user.displayName}',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${user.position} · ${user.department}',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'إجراءات الفريق',
              textAlign: TextAlign.right,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.analytics_outlined,
                    title: 'تفاصيل الحضور',
                    onTap: () => context.go('/team-leader/attendance-summary'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.people_outline,
                    title: 'أعضاء فريقي',
                    onTap: () => context.go('/team-leader/employees'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.task_alt_outlined,
              title: 'متابعة مهام الفريق',
              onTap: () => context.go('/team-leader/tasks'),
            ),
          ],
        ),
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
            const SizedBox(height: 8),
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
