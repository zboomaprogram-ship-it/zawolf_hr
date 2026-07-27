import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../components/wolf_card.dart';
import '../../models/productivity_score_model.dart';
import '../../models/user_model.dart';
import '../../models/employee_role.dart';
import '../../services/auth_service.dart';
import '../../services/managed_employee_service.dart';
import '../../services/productivity_service.dart';
import '../../theme/theme.dart';
import '../../utils/payroll_cycle.dart';

class DepartmentPerformanceData {
  final String departmentName;
  final double averageScore;
  final int employeeCount;

  DepartmentPerformanceData({
    required this.departmentName,
    required this.averageScore,
    required this.employeeCount,
  });
}

class DepartmentPerformanceScreen extends StatefulWidget {
  const DepartmentPerformanceScreen({super.key});

  @override
  State<DepartmentPerformanceScreen> createState() =>
      _DepartmentPerformanceScreenState();
}

class _DepartmentPerformanceScreenState
    extends State<DepartmentPerformanceScreen> {
  final ProductivityService _service = ProductivityService();
  late final String _monthKey = PayrollCycle.keyFor(DateTime.now());
  bool _refreshing = false;
  Future<List<UserModel>>? _organizationFuture;
  String? _organizationReviewerId;

  Future<void> _refresh(UserModel reviewer) async {
    setState(() => _refreshing = true);
    try {
      final count = await _service.refreshRanking(reviewer, _monthKey);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم تحديث بيانات $count موظف.')));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  List<DepartmentPerformanceData> _aggregateDepartments(
    List<ProductivityScoreModel> scores,
    UserModel reviewer,
  ) {
    // If manager, only consider their department
    final isManager = reviewer.role == EmployeeRole.manager;
    final relevantScores = isManager
        ? scores.where((s) => s.department == reviewer.department).toList()
        : scores;

    final Map<String, List<ProductivityScoreModel>> grouped = {};
    for (var s in relevantScores) {
      final dept = s.department.trim().isEmpty ? 'غير محدد' : s.department;
      grouped.putIfAbsent(dept, () => []).add(s);
    }

    final results = grouped.entries.map((e) {
      final totalScore = e.value.fold<double>(
        0,
        (total, item) => total + item.overallScore,
      );
      final avg = totalScore / e.value.length;
      return DepartmentPerformanceData(
        departmentName: e.key,
        averageScore: avg,
        employeeCount: e.value.length,
      );
    }).toList();

    // Sort by average score descending
    results.sort((a, b) => b.averageScore.compareTo(a.averageScore));
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final reviewer = context.watch<AuthService>().currentUser;
    final theme = Theme.of(context);
    if (reviewer == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }

    if (_organizationReviewerId != reviewer.uid) {
      _organizationReviewerId = reviewer.uid;
      _organizationFuture = _loadOrganization(reviewer);
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'الأقسام والهيكل الوظيفي',
            style: theme.textTheme.headlineMedium,
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث الحساب',
              onPressed: _refreshing ? null : () => _refresh(reviewer),
              icon: _refreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, color: ZaWolfColors.primaryCyan),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.analytics_outlined), text: 'أداء الأقسام'),
              Tab(
                icon: Icon(Icons.account_tree_outlined),
                text: 'الهيكل الوظيفي',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPerformanceTab(reviewer, theme),
            _buildOrganizationTab(reviewer),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceTab(UserModel reviewer, ThemeData theme) {
    return StreamBuilder<List<ProductivityScoreModel>>(
      // We use the same service method, it fetches all visible scores for the reviewer
      stream: _service.watchRanking(reviewer, _monthKey),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          );
        }
        final scores = snapshot.data ?? [];
        final departments = _aggregateDepartments(scores, reviewer);

        if (departments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.domain_disabled_outlined,
                    size: 56,
                    color: ZaWolfColors.textMuted,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'لا توجد بيانات للأقسام في شهر $_monthKey\nاضغط تحديث لتوليد التقارير',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final best = departments.first;
        final needsFollowUp = [...departments]
          ..sort((a, b) => a.averageScore.compareTo(b.averageScore));
        final worst = needsFollowUp.first;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (departments.length > 1) ...[
              Row(
                children: [
                  Expanded(
                    child: _HighlightCard(
                      title: 'أفضل قسم',
                      value: best.departmentName,
                      subtitle: '${best.averageScore.toStringAsFixed(1)}%',
                      color: ZaWolfColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HighlightCard(
                      title: 'يحتاج متابعة',
                      value: worst.departmentName,
                      subtitle: '${worst.averageScore.toStringAsFixed(1)}%',
                      color: ZaWolfColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            ...departments.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final dept = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: WolfCard(
                  child: Row(
                    children: [
                      _RankBadge(rank: rank),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              dept.departmentName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'عدد الموظفين: ${dept.employeeCount}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: (dept.averageScore / 100).clamp(0, 1),
                              minHeight: 7,
                              borderRadius: BorderRadius.circular(8),
                              color: _scoreColor(dept.averageScore),
                              backgroundColor: ZaWolfColors.surface03,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${dept.averageScore.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: _scoreColor(dept.averageScore),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<List<UserModel>> _loadOrganization(UserModel reviewer) async {
    if (EmployeeRole.isHr(reviewer.role)) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isActive', isEqualTo: true)
          .get();
      final users = snapshot.docs.map(UserModel.fromFirestore).toList();
      users.sort((a, b) => a.displayName.compareTo(b.displayName));
      return users;
    }

    final employees = await ManagedEmployeeService().loadForReviewer(reviewer);
    final byId = <String, UserModel>{reviewer.uid: reviewer};
    for (final employee in employees) {
      byId[employee.uid] = employee;
    }
    return byId.values.toList();
  }

  Widget _buildOrganizationTab(UserModel reviewer) {
    return FutureBuilder<List<UserModel>>(
      future: _organizationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _organizationFuture = _loadOrganization(reviewer);
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة تحميل الهيكل الوظيفي'),
            ),
          );
        }

        final users = snapshot.data ?? const <UserModel>[];
        if (users.isEmpty) {
          return const Center(child: Text('لا توجد بيانات وظيفية متاحة.'));
        }
        final grouped = <String, List<UserModel>>{};
        for (final user in users) {
          final department = user.department.trim().isEmpty
              ? 'غير محدد'
              : user.department.trim();
          grouped.putIfAbsent(department, () => []).add(user);
        }
        final departments = grouped.keys.toList()..sort();

        return RefreshIndicator(
          color: ZaWolfColors.primaryCyan,
          onRefresh: () async {
            final future = _loadOrganization(reviewer);
            setState(() => _organizationFuture = future);
            await future;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: departments.length,
            separatorBuilder: (_, _) =>
                const Divider(color: ZaWolfColors.surface03, height: 28),
            itemBuilder: (context, index) {
              final department = departments[index];
              return _DepartmentHierarchy(
                department: department,
                users: grouped[department]!,
              );
            },
          ),
        );
      },
    );
  }

  Color _scoreColor(double value) {
    if (value >= 85) return ZaWolfColors.success;
    if (value >= 70) return ZaWolfColors.warning;
    return ZaWolfColors.error;
  }
}

class _DepartmentHierarchy extends StatelessWidget {
  const _DepartmentHierarchy({required this.department, required this.users});

  final String department;
  final List<UserModel> users;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final user in users) user.uid: user};
    final children = <String, List<UserModel>>{};
    final roots = <UserModel>[];

    for (final user in users) {
      final managerIds = [
        if ((user.teamLeaderId ?? '').isNotEmpty) user.teamLeaderId!,
        ...user.managerIds,
        if ((user.managerId ?? '').isNotEmpty) user.managerId!,
      ];
      final parentId = managerIds.cast<String?>().firstWhere(
        (id) => id != null && id != user.uid && byId.containsKey(id),
        orElse: () => null,
      );
      if (parentId == null) {
        roots.add(user);
      } else {
        children.putIfAbsent(parentId, () => []).add(user);
      }
    }

    int roleOrder(UserModel user) => switch (user.role) {
      EmployeeRole.superAdmin => 0,
      EmployeeRole.hrManager => 1,
      EmployeeRole.hrAdmin => 2,
      EmployeeRole.manager => 3,
      EmployeeRole.teamLeader => 4,
      _ => 5,
    };

    void sortUsers(List<UserModel> values) {
      values.sort((a, b) {
        final roleComparison = roleOrder(a).compareTo(roleOrder(b));
        return roleComparison != 0
            ? roleComparison
            : a.displayName.compareTo(b.displayName);
      });
    }

    sortUsers(roots);
    for (final values in children.values) {
      sortUsers(values);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.apartment, color: ZaWolfColors.primaryCyan),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                department,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${users.length} موظف',
              style: const TextStyle(color: ZaWolfColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (roots.isEmpty)
          ...users.map(
            (user) => _OrganizationNode(
              user: user,
              childrenByManager: const {},
              depth: 0,
              visited: const {},
            ),
          )
        else
          ...roots.map(
            (user) => _OrganizationNode(
              user: user,
              childrenByManager: children,
              depth: 0,
              visited: const {},
            ),
          ),
      ],
    );
  }
}

class _OrganizationNode extends StatelessWidget {
  const _OrganizationNode({
    required this.user,
    required this.childrenByManager,
    required this.depth,
    required this.visited,
  });

  final UserModel user;
  final Map<String, List<UserModel>> childrenByManager;
  final int depth;
  final Set<String> visited;

  @override
  Widget build(BuildContext context) {
    if (visited.contains(user.uid)) return const SizedBox.shrink();
    final nextVisited = {...visited, user.uid};
    final reports = childrenByManager[user.uid] ?? const <UserModel>[];
    final accent = switch (user.role) {
      EmployeeRole.superAdmin => ZaWolfColors.warning,
      EmployeeRole.hrManager ||
      EmployeeRole.hrAdmin => ZaWolfColors.primaryCyan,
      EmployeeRole.manager => ZaWolfColors.primaryCyan,
      EmployeeRole.teamLeader => ZaWolfColors.success,
      _ => ZaWolfColors.textSecondary,
    };

    return Padding(
      padding: EdgeInsetsDirectional.only(start: depth * 18.0, bottom: 8),
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ZaWolfColors.surface01,
              borderRadius: BorderRadius.circular(8),
              border: BorderDirectional(
                start: BorderSide(color: accent, width: 3),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: accent.withValues(alpha: 0.14),
                  child: Icon(_roleIcon(user.role), color: accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        [
                          if (user.position.trim().isNotEmpty) user.position,
                          EmployeeRole.arabicLabel(user.role),
                          if (user.employeeId.trim().isNotEmpty)
                            user.employeeId,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ZaWolfColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (reports.isNotEmpty)
                  Text(
                    '${reports.length}',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          if (reports.isNotEmpty) ...[
            Container(width: 1, height: 8, color: ZaWolfColors.surface03),
            ...reports.map(
              (report) => _OrganizationNode(
                user: report,
                childrenByManager: childrenByManager,
                depth: depth + 1,
                visited: nextVisited,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _roleIcon(String role) => switch (role) {
    EmployeeRole.superAdmin => Icons.admin_panel_settings_outlined,
    EmployeeRole.hrManager || EmployeeRole.hrAdmin => Icons.badge_outlined,
    EmployeeRole.manager => Icons.manage_accounts_outlined,
    EmployeeRole.teamLeader => Icons.groups_outlined,
    _ => Icons.person_outline,
  };
}

class _HighlightCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _HighlightCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.ltr,
          ),
          Text(
            subtitle,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ZaWolfColors.primaryCyan.withValues(alpha: 0.12),
        border: Border.all(
          color: ZaWolfColors.primaryCyan.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        '$rank',
        style: const TextStyle(
          color: ZaWolfColors.primaryCyan,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
