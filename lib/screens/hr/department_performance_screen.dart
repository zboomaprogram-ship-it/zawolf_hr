import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../components/wolf_card.dart';
import '../../models/productivity_score_model.dart';
import '../../models/user_model.dart';
import '../../models/employee_role.dart';
import '../../models/organization_structure.dart';
import '../../services/auth_service.dart';
import '../../services/managed_employee_service.dart';
import '../../services/organization_structure_service.dart';
import '../../services/productivity_service.dart';
import '../../theme/theme.dart';
import '../../utils/payroll_cycle.dart';
import '../shared/productivity_score_details_sheet.dart';

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
  bool _autoRefreshAttempted = false;
  Future<List<UserModel>>? _organizationFuture;
  String? _organizationReviewerId;
  int _organizationStructureVersion = 0;

  Future<void> _refresh(
    UserModel reviewer, {
    bool showConfirmation = true,
  }) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final count = await _service.refreshRanking(reviewer, _monthKey);
      if (mounted && showConfirmation) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم تحديث بيانات $count موظف.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تحديث أداء الأقسام. تحقق من الاتصال والصلاحيات ثم أعد المحاولة.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _refreshStaleCacheOnce(
    UserModel reviewer,
    List<ProductivityScoreModel> scores,
  ) {
    if (_autoRefreshAttempted || _refreshing) return;
    final now = DateTime.now();
    final stale =
        scores.isEmpty ||
        scores.any((score) {
          final calculatedAt = score.calculatedAt;
          return calculatedAt == null ||
              now.difference(calculatedAt).inMinutes >= 30;
        });
    if (!stale) return;
    _autoRefreshAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh(reviewer, showConfirmation: false);
    });
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
        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton.icon(
              onPressed: () => _refresh(reviewer),
              icon: const Icon(Icons.refresh),
              label: const Text('تعذر تحميل أداء الأقسام، أعد المحاولة'),
            ),
          );
        }
        final scores = snapshot.data ?? [];
        _refreshStaleCacheOnce(reviewer, scores);
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
                    _refreshing
                        ? 'جارٍ تجهيز بيانات الأقسام لشهر $_monthKey لأول مرة…'
                        : 'لا توجد بيانات للأقسام في شهر $_monthKey',
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
                  onTap: () => showDepartmentProductivityDetails(
                    context,
                    department: dept.departmentName,
                    scores: scores
                        .where(
                          (score) =>
                              (score.department.trim().isEmpty
                                  ? 'غير محدد'
                                  : score.department) ==
                              dept.departmentName,
                        )
                        .toList(),
                    onUpdateBehavior: (score, value, reason) async {
                      await _service.updateBehaviorScore(
                        employeeUserId: score.userId,
                        reviewer: reviewer,
                        monthKey: score.monthKey,
                        behaviorScore: value,
                        reason: reason,
                      );
                    },
                  ),
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
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_left,
                        color: ZaWolfColors.textMuted,
                        size: 20,
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
        return RefreshIndicator(
          color: ZaWolfColors.primaryCyan,
          onRefresh: () async {
            final future = _loadOrganization(reviewer);
            setState(() => _organizationFuture = future);
            await future;
          },
          child: _OrganizationChart(
            key: ValueKey(_organizationStructureVersion),
            users: users,
            canEdit: EmployeeRole.isHr(reviewer.role),
            onStructureChanged: () {
              setState(() => _organizationStructureVersion++);
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

class _OrganizationChart extends StatelessWidget {
  const _OrganizationChart({
    super.key,
    required this.users,
    required this.canEdit,
    required this.onStructureChanged,
  });

  final List<UserModel> users;
  final bool canEdit;
  final VoidCallback onStructureChanged;

  @override
  Widget build(BuildContext context) {
    final service = OrganizationStructureService();
    return FutureBuilder<List<Object>>(
      future: Future.wait<Object>([
        service.loadDivisions(),
        service.loadDepartments(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
          );
        }
        final values = snapshot.data;
        final divisions = values == null
            ? OrganizationDefaults.divisions
            : values[0] as List<OrganizationDivision>;
        final departments = values == null
            ? const <OrganizationDepartment>[]
            : values[1] as List<OrganizationDepartment>;
        return _OrganizationChartBody(
          users: users,
          divisions: divisions,
          departments: departments,
          canEdit: canEdit,
          service: service,
          onStructureChanged: onStructureChanged,
        );
      },
    );
  }
}

class _OrganizationChartBody extends StatefulWidget {
  const _OrganizationChartBody({
    required this.users,
    required this.divisions,
    required this.departments,
    required this.canEdit,
    required this.service,
    required this.onStructureChanged,
  });

  final List<UserModel> users;
  final List<OrganizationDivision> divisions;
  final List<OrganizationDepartment> departments;
  final bool canEdit;
  final OrganizationStructureService service;
  final VoidCallback onStructureChanged;

  @override
  State<_OrganizationChartBody> createState() => _OrganizationChartBodyState();
}

class _OrganizationChartBodyState extends State<_OrganizationChartBody> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedDepartment;
  bool _showEmployees = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allUsers = [...widget.users]..sort(_compareUsers);
    final executives = allUsers
        .where((user) => user.employeeId.trim().toUpperCase() == 'CEO-100')
        .toList();
    final departmentNames =
        allUsers
            .where((user) => user.role != EmployeeRole.superAdmin)
            .map(_departmentOf)
            .toSet()
            .toList()
          ..sort();

    final visibleDepartments = departmentNames.where((department) {
      if (_selectedDepartment != null && department != _selectedDepartment) {
        return false;
      }
      if (_query.isEmpty) return true;
      return allUsers
          .where((user) => _departmentOf(user) == department)
          .any(_matchesQuery);
    }).toList();

    final groups = {
      for (final department in visibleDepartments)
        department: allUsers
            .where(
              (user) =>
                  user.role != EmployeeRole.superAdmin &&
                  _departmentOf(user) == department &&
                  (_query.isEmpty || _matchesQuery(user)),
            )
            .toList(),
    };
    final departmentRecords = <String, OrganizationDepartment>{
      for (final department in widget.departments) department.name: department,
    };
    final divisions = [...widget.divisions]
      ..sort((a, b) => a.order.compareTo(b.order));
    final departmentsByDivision = {
      for (final division in divisions)
        division.id: visibleDepartments.where((department) {
          final record = departmentRecords[department];
          return (record?.divisionId ??
                  OrganizationDefaults.inferDivisionId(department)) ==
              division.id;
        }).toList(),
    };

    final managerCount = allUsers
        .where(
          (user) =>
              user.organizationLevel == OrganizationLevel.divisionManager ||
              user.organizationLevel == OrganizationLevel.departmentManager ||
              _isManagerRole(user),
        )
        .length;
    final teamLeaderCount = allUsers
        .where(
          (user) =>
              user.organizationLevel == OrganizationLevel.teamLeader ||
              user.role == EmployeeRole.teamLeader,
        )
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 850;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 24 : 14,
            vertical: 16,
          ),
          children: [
            _OrganizationHeader(
              employeeCount: allUsers.length,
              departmentCount: departmentNames.length,
              managerCount: managerCount,
              teamLeaderCount: teamLeaderCount,
            ),
            const SizedBox(height: 14),
            _OrganizationControls(
              controller: _searchController,
              departments: departmentNames,
              selectedDepartment: _selectedDepartment,
              showEmployees: _showEmployees,
              onSearchChanged: (value) {
                setState(() => _query = value.trim().toLowerCase());
              },
              onDepartmentChanged: (value) {
                setState(() => _selectedDepartment = value);
              },
              onShowEmployeesChanged: (value) {
                setState(() => _showEmployees = value);
              },
            ),
            if (widget.canEdit) ...[
              const SizedBox(height: 14),
              _OrganizationConfigurationPanel(
                divisions: divisions,
                departments: widget.departments,
                users: allUsers,
                service: widget.service,
                onChanged: widget.onStructureChanged,
              ),
            ],
            const SizedBox(height: 18),
            const _OrganizationLegend(),
            const SizedBox(height: 18),
            if (visibleDepartments.isEmpty)
              const _OrganizationEmptyState()
            else if (isWide)
              _DesktopOrganizationMap(
                executives: executives,
                divisions: divisions,
                departmentsByDivision: departmentsByDivision,
                groups: groups,
                allUsers: allUsers,
                showEmployees: _showEmployees,
              )
            else
              _MobileOrganizationMap(
                executives: executives,
                divisions: divisions,
                departmentsByDivision: departmentsByDivision,
                groups: groups,
                allUsers: allUsers,
                showEmployees: _showEmployees,
              ),
          ],
        );
      },
    );
  }

  bool _matchesQuery(UserModel user) {
    final searchable = [
      user.displayName,
      user.employeeId,
      user.position,
      user.department,
      user.teamLeaderName ?? '',
      ...user.managerNames,
    ].join(' ').toLowerCase();
    return searchable.contains(_query);
  }
}

class _OrganizationHeader extends StatelessWidget {
  const _OrganizationHeader({
    required this.employeeCount,
    required this.departmentCount,
    required this.managerCount,
    required this.teamLeaderCount,
  });

  final int employeeCount;
  final int departmentCount;
  final int managerCount;
  final int teamLeaderCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ZaWolfColors.primaryCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_tree_outlined,
                  color: ZaWolfColors.primaryCyan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الخريطة التنظيمية',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'تسلسل الإدارة والفرق داخل الشركة',
                      style: TextStyle(color: ZaWolfColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _OrganizationMetric(
                icon: Icons.apartment_outlined,
                value: '$departmentCount',
                label: 'قسم',
              ),
              _OrganizationMetric(
                icon: Icons.manage_accounts_outlined,
                value: '$managerCount',
                label: 'مدير',
              ),
              _OrganizationMetric(
                icon: Icons.groups_outlined,
                value: '$teamLeaderCount',
                label: 'قائد فريق',
              ),
              _OrganizationMetric(
                icon: Icons.people_outline,
                value: '$employeeCount',
                label: 'عضو نشط',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrganizationMetric extends StatelessWidget {
  const _OrganizationMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface02,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: ZaWolfColors.primaryCyan),
          const SizedBox(width: 7),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: ZaWolfColors.textMuted)),
        ],
      ),
    );
  }
}

class _OrganizationControls extends StatelessWidget {
  const _OrganizationControls({
    required this.controller,
    required this.departments,
    required this.selectedDepartment,
    required this.showEmployees,
    required this.onSearchChanged,
    required this.onDepartmentChanged,
    required this.onShowEmployeesChanged,
  });

  final TextEditingController controller;
  final List<String> departments;
  final String? selectedDepartment;
  final bool showEmployees;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onDepartmentChanged;
  final ValueChanged<bool> onShowEmployeesChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final search = TextField(
          controller: controller,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            labelText: 'بحث بالاسم أو المسمى أو الكود',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'مسح البحث',
                    onPressed: () {
                      controller.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        );
        final department = DropdownButtonFormField<String?>(
          initialValue: selectedDepartment,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'القسم',
            prefixIcon: Icon(Icons.apartment_outlined),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('جميع الأقسام'),
            ),
            ...departments.map(
              (value) => DropdownMenuItem<String?>(
                value: value,
                child: Text(value, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onDepartmentChanged,
        );
        final employeeToggle = FilterChip(
          selected: showEmployees,
          showCheckmark: true,
          avatar: const Icon(Icons.people_outline, size: 18),
          label: const Text('إظهار الموظفين'),
          onSelected: onShowEmployeesChanged,
        );

        if (!isWide) {
          return Column(
            children: [
              search,
              const SizedBox(height: 10),
              department,
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: employeeToggle,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 3, child: search),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: department),
            const SizedBox(width: 10),
            employeeToggle,
          ],
        );
      },
    );
  }
}

class _OrganizationLegend extends StatelessWidget {
  const _OrganizationLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: const [
        _LegendItem(color: ZaWolfColors.warning, label: 'الإدارة التنفيذية'),
        _LegendItem(color: ZaWolfColors.primaryCyan, label: 'مدير'),
        _LegendItem(color: ZaWolfColors.success, label: 'قائد فريق'),
        _LegendItem(color: ZaWolfColors.textSecondary, label: 'موظف'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: ZaWolfColors.textMuted)),
      ],
    );
  }
}

class _DesktopOrganizationMap extends StatefulWidget {
  const _DesktopOrganizationMap({
    required this.executives,
    required this.divisions,
    required this.departmentsByDivision,
    required this.groups,
    required this.allUsers,
    required this.showEmployees,
  });

  final List<UserModel> executives;
  final List<OrganizationDivision> divisions;
  final Map<String, List<String>> departmentsByDivision;
  final Map<String, List<UserModel>> groups;
  final List<UserModel> allUsers;
  final bool showEmployees;

  @override
  State<_DesktopOrganizationMap> createState() =>
      _DesktopOrganizationMapState();
}

class _DesktopOrganizationMapState extends State<_DesktopOrganizationMap> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _moveHorizontally({required bool towardLeft}) async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final positiveOffsetMovesLeft =
        position.axisDirection == AxisDirection.left;
    final delta = towardLeft
        ? (positiveOffsetMovesLeft ? 460.0 : -460.0)
        : (positiveOffsetMovesLeft ? -460.0 : 460.0);
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const branchWidth = 330.0;
        const branchSpacing = 16.0;
        final chartWidth = math.max(
          constraints.maxWidth,
          widget.divisions.length * (branchWidth + branchSpacing),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => _moveHorizontally(towardLeft: false),
                  tooltip: 'تحريك لليمين',
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                ),
                IconButton(
                  onPressed: () => _moveHorizontally(towardLeft: true),
                  tooltip: 'تحريك لليسار',
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'اسحب الخريطة أفقياً أو استخدم الأسهم لعرض جميع الأقسام',
                    style: TextStyle(
                      color: ZaWolfColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              interactive: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: ScrollConfiguration(
                behavior: const _OrganizationChartScrollBehavior(),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 18),
                  child: SizedBox(
                    width: chartWidth,
                    child: Column(
                      children: [
                        _ExecutiveTier(executives: widget.executives),
                        const SizedBox(height: 4),
                        Container(
                          width: 2,
                          height: 24,
                          color: ZaWolfColors.primaryCyan.withValues(
                            alpha: 0.55,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 150),
                          height: 2,
                          color: ZaWolfColors.primaryCyan.withValues(
                            alpha: 0.38,
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: widget.divisions.map((division) {
                            return SizedBox(
                              width: branchWidth + branchSpacing,
                              child: Column(
                                children: [
                                  Container(
                                    width: 2,
                                    height: 20,
                                    color: ZaWolfColors.primaryCyan.withValues(
                                      alpha: 0.38,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: branchSpacing / 2,
                                    ),
                                    child: _DivisionBranch(
                                      division: division,
                                      departments:
                                          widget.departmentsByDivision[division
                                              .id] ??
                                          const [],
                                      groups: widget.groups,
                                      allUsers: widget.allUsers,
                                      showEmployees: widget.showEmployees,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrganizationChartScrollBehavior extends MaterialScrollBehavior {
  const _OrganizationChartScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

class _MobileOrganizationMap extends StatelessWidget {
  const _MobileOrganizationMap({
    required this.executives,
    required this.divisions,
    required this.departmentsByDivision,
    required this.groups,
    required this.allUsers,
    required this.showEmployees,
  });

  final List<UserModel> executives;
  final List<OrganizationDivision> divisions;
  final Map<String, List<String>> departmentsByDivision;
  final Map<String, List<UserModel>> groups;
  final List<UserModel> allUsers;
  final bool showEmployees;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ExecutiveTier(executives: executives),
        Container(
          width: 2,
          height: 22,
          color: ZaWolfColors.primaryCyan.withValues(alpha: 0.45),
        ),
        ...divisions.map(
          (division) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _DivisionBranch(
              division: division,
              departments: departmentsByDivision[division.id] ?? const [],
              groups: groups,
              allUsers: allUsers,
              showEmployees: showEmployees,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExecutiveTier extends StatelessWidget {
  const _ExecutiveTier({required this.executives});

  final List<UserModel> executives;

  @override
  Widget build(BuildContext context) {
    if (executives.isEmpty) {
      return const _EmptyExecutiveNode();
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: executives
          .map(
            (user) => SizedBox(
              width: 300,
              child: _OrganizationPerson(
                user: user,
                roleLabel: user.employeeId.toUpperCase() == 'CEO-100'
                    ? 'المدير التنفيذي'
                    : EmployeeRole.arabicLabel(user.role),
                accent: ZaWolfColors.warning,
                icon: Icons.admin_panel_settings_outlined,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _EmptyExecutiveNode extends StatelessWidget {
  const _EmptyExecutiveNode();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZaWolfColors.warning.withValues(alpha: 0.35)),
      ),
      child: const Row(
        children: [
          Icon(Icons.corporate_fare_outlined, color: ZaWolfColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'الإدارة التنفيذية',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizationConfigurationPanel extends StatefulWidget {
  const _OrganizationConfigurationPanel({
    required this.divisions,
    required this.departments,
    required this.users,
    required this.service,
    required this.onChanged,
  });

  final List<OrganizationDivision> divisions;
  final List<OrganizationDepartment> departments;
  final List<UserModel> users;
  final OrganizationStructureService service;
  final VoidCallback onChanged;

  @override
  State<_OrganizationConfigurationPanel> createState() =>
      _OrganizationConfigurationPanelState();
}

class _OrganizationConfigurationPanelState
    extends State<_OrganizationConfigurationPanel> {
  bool _expanded = false;
  bool _saving = false;

  Future<void> _save(Future<void> Function() operation) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await operation();
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث الهيكل الوظيفي.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تحديث الهيكل الوظيفي. تحقق من الاتصال والصلاحيات ثم أعد المحاولة.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final managerCandidates =
        widget.users
            .where(
              (user) =>
                  user.isActive &&
                  (user.organizationLevel ==
                          OrganizationLevel.divisionManager ||
                      user.organizationLevel ==
                          OrganizationLevel.departmentManager ||
                      user.role == EmployeeRole.manager ||
                      user.role == EmployeeRole.superAdmin ||
                      user.role == EmployeeRole.hrManager),
            )
            .toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));

    return Container(
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.tune_outlined,
              color: ZaWolfColors.primaryCyan,
            ),
            title: const Text('إدارة الهيكل التنظيمي'),
            subtitle: const Text(
              'نقل الأقسام بين القطاعات وتغيير مدير كل قطاع',
            ),
            trailing: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              color: ZaWolfColors.textSecondary,
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: ZaWolfColors.surface03),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  ...widget.divisions.map((division) {
                    String? selectedManagerId = division.managerId;
                    if (selectedManagerId == null &&
                        division.managerEmployeeId != null) {
                      for (final candidate in managerCandidates) {
                        if (candidate.employeeId.toUpperCase() ==
                            division.managerEmployeeId!.toUpperCase()) {
                          selectedManagerId = candidate.uid;
                          break;
                        }
                      }
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String?>(
                        initialValue: selectedManagerId,
                        decoration: InputDecoration(
                          labelText: 'مدير ${division.name}',
                        ),
                        dropdownColor: ZaWolfColors.surface02,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('بدون مدير محدد'),
                          ),
                          ...managerCandidates.map(
                            (user) => DropdownMenuItem<String?>(
                              value: user.uid,
                              child: Text(
                                '${user.displayName} (${user.employeeId})',
                              ),
                            ),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (managerId) {
                                UserModel? manager;
                                for (final candidate in managerCandidates) {
                                  if (candidate.uid == managerId) {
                                    manager = candidate;
                                    break;
                                  }
                                }
                                _save(
                                  () => widget.service.saveDivision(
                                    OrganizationDivision(
                                      id: division.id,
                                      name: division.name,
                                      order: division.order,
                                      managerId: managerId,
                                      managerEmployeeId: manager?.employeeId,
                                      isActive: division.isActive,
                                    ),
                                  ),
                                );
                              },
                      ),
                    );
                  }),
                  const Divider(color: ZaWolfColors.surface03),
                  ...widget.departments.map(
                    (department) => Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            widget.divisions.any(
                              (division) =>
                                  division.id == department.divisionId,
                            )
                            ? department.divisionId
                            : OrganizationDefaults.operations,
                        decoration: InputDecoration(
                          labelText: department.name,
                          prefixIcon: const Icon(Icons.apartment_outlined),
                        ),
                        dropdownColor: ZaWolfColors.surface02,
                        items: widget.divisions
                            .map(
                              (division) => DropdownMenuItem(
                                value: division.id,
                                child: Text(division.name),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (divisionId) {
                                if (divisionId == null) return;
                                _save(
                                  () => widget.service.moveDepartment(
                                    departmentId: department.id,
                                    divisionId: divisionId,
                                  ),
                                );
                              },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DivisionBranch extends StatelessWidget {
  const _DivisionBranch({
    required this.division,
    required this.departments,
    required this.groups,
    required this.allUsers,
    required this.showEmployees,
  });

  final OrganizationDivision division;
  final List<String> departments;
  final Map<String, List<UserModel>> groups;
  final List<UserModel> allUsers;
  final bool showEmployees;

  @override
  Widget build(BuildContext context) {
    UserModel? divisionManager;
    for (final user in allUsers) {
      final matchesConfiguredManager = division.managerId == user.uid;
      final matchesConfiguredCode =
          (division.managerEmployeeId ?? '').toUpperCase() ==
          user.employeeId.toUpperCase();
      final matchesProfile =
          user.organizationLevel == OrganizationLevel.divisionManager &&
          user.organizationDivisionId == division.id;
      if (matchesConfiguredManager || matchesConfiguredCode || matchesProfile) {
        divisionManager = user;
        break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: ZaWolfColors.primaryCyan.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            color: ZaWolfColors.primaryCyan.withValues(alpha: 0.12),
            child: Column(
              children: [
                Text(
                  division.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (divisionManager != null) ...[
                  const SizedBox(height: 8),
                  _OrganizationPerson(
                    user: divisionManager,
                    roleLabel: OrganizationLevel.arabicLabel(
                      OrganizationLevel.divisionManager,
                    ),
                    accent: ZaWolfColors.warning,
                    icon: Icons.business_center_outlined,
                  ),
                ],
              ],
            ),
          ),
          if (departments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'لا توجد أقسام في هذا القطاع.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ZaWolfColors.textMuted),
              ),
            )
          else
            ...departments.map(
              (department) => Padding(
                padding: const EdgeInsets.all(8),
                child: _DepartmentBranch(
                  department: department,
                  users: groups[department] ?? const [],
                  allUsers: allUsers,
                  showEmployees: showEmployees,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DepartmentBranch extends StatelessWidget {
  const _DepartmentBranch({
    required this.department,
    required this.users,
    required this.allUsers,
    required this.showEmployees,
  });

  final String department;
  final List<UserModel> users;
  final List<UserModel> allUsers;
  final bool showEmployees;

  @override
  Widget build(BuildContext context) {
    final allById = {for (final user in allUsers) user.uid: user};
    final supervisorIds = users
        .expand(
          (user) => <String>[
            ...user.managerIds,
            if ((user.managerId ?? '').isNotEmpty) user.managerId!,
          ],
        )
        .where((id) => id.isNotEmpty)
        .toSet();
    final managers = <String, UserModel>{};
    for (final user in users.where(_isManagerRole)) {
      managers[user.uid] = user;
    }
    for (final id in supervisorIds) {
      final supervisor = allById[id];
      if (supervisor != null) managers[id] = supervisor;
    }

    final leaders = <String, UserModel>{};
    for (final user in users.where(
      (user) => user.role == EmployeeRole.teamLeader,
    )) {
      leaders[user.uid] = user;
    }
    for (final user in users) {
      final leader = allById[user.teamLeaderId];
      if (leader != null) leaders[leader.uid] = leader;
    }

    final employees =
        users
            .where(
              (user) =>
                  !_isManagerRole(user) && user.role != EmployeeRole.teamLeader,
            )
            .toList()
          ..sort(_compareUsers);
    final managerList = managers.values.toList()..sort(_compareUsers);
    final leaderList = leaders.values.toList()..sort(_compareUsers);

    return Container(
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ZaWolfColors.primaryCyan.withValues(alpha: 0.34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            color: ZaWolfColors.primaryCyan.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(
                  Icons.apartment_outlined,
                  color: ZaWolfColors.primaryCyan,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    department,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  '${users.length}',
                  style: const TextStyle(
                    color: ZaWolfColors.primaryCyan,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (managerList.isNotEmpty) ...[
            const _OrganizationLevelLabel(
              icon: Icons.manage_accounts_outlined,
              label: 'الإدارة',
              color: ZaWolfColors.primaryCyan,
            ),
            ...managerList.map(
              (user) => _OrganizationPerson(
                user: user,
                roleLabel: _managerLabel(user, department),
                accent: ZaWolfColors.primaryCyan,
                icon: Icons.manage_accounts_outlined,
              ),
            ),
          ] else
            const _MissingRoleNotice(
              icon: Icons.manage_accounts_outlined,
              label: 'لم يتم تعيين مدير للقسم',
            ),
          if (leaderList.isNotEmpty) ...[
            const _VerticalOrganizationConnector(),
            const _OrganizationLevelLabel(
              icon: Icons.groups_outlined,
              label: 'قادة الفرق',
              color: ZaWolfColors.success,
            ),
            ...leaderList.map(
              (user) => _OrganizationPerson(
                user: user,
                roleLabel: _reportsToLabel(user, allById),
                accent: ZaWolfColors.success,
                icon: Icons.groups_outlined,
              ),
            ),
          ],
          if (showEmployees && employees.isNotEmpty) ...[
            const _VerticalOrganizationConnector(),
            _OrganizationLevelLabel(
              icon: Icons.people_outline,
              label: 'أعضاء الفريق (${employees.length})',
              color: ZaWolfColors.textSecondary,
            ),
            ...employees.map(
              (user) => _OrganizationPerson(
                user: user,
                roleLabel: _reportsToLabel(user, allById),
                accent: ZaWolfColors.textSecondary,
                icon: Icons.person_outline,
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _managerLabel(UserModel user, String branchDepartment) {
    final role = EmployeeRole.arabicLabel(user.role);
    if (_departmentOf(user) != branchDepartment) {
      return '$role · إشراف من ${_departmentOf(user)}';
    }
    return role;
  }

  String _reportsToLabel(UserModel user, Map<String, UserModel> allById) {
    final leader = allById[user.teamLeaderId];
    if (leader != null && leader.uid != user.uid) {
      return 'قائد الفريق: ${leader.displayName}';
    }
    final managerIds = <String>{
      ...user.managerIds,
      if ((user.managerId ?? '').isNotEmpty) user.managerId!,
    };
    final managerNames = managerIds
        .map((id) => allById[id]?.displayName)
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toList();
    if (managerNames.isNotEmpty) {
      return 'المدير: ${managerNames.join('، ')}';
    }
    if (user.managerNames.isNotEmpty) {
      return 'المدير: ${user.managerNames.join('، ')}';
    }
    return EmployeeRole.arabicLabel(user.role);
  }
}

class _OrganizationLevelLabel extends StatelessWidget {
  const _OrganizationLevelLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _OrganizationPerson extends StatelessWidget {
  const _OrganizationPerson({
    required this.user,
    required this.roleLabel,
    required this.accent,
    required this.icon,
  });

  final UserModel user;
  final String roleLabel;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ZaWolfColors.surface03)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: accent.withValues(alpha: 0.13),
            foregroundImage: (user.photoURL ?? '').isNotEmpty
                ? NetworkImage(user.photoURL!)
                : null,
            child: (user.photoURL ?? '').isEmpty
                ? Icon(icon, color: accent, size: 20)
                : null,
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
                if (user.position.trim().isNotEmpty)
                  Text(
                    user.position,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ZaWolfColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  roleLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: accent, fontSize: 11),
                ),
              ],
            ),
          ),
          if (user.employeeId.trim().isNotEmpty)
            Text(
              user.employeeId,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: ZaWolfColors.textMuted,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}

class _VerticalOrganizationConnector extends StatelessWidget {
  const _VerticalOrganizationConnector();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(width: 2, height: 12, color: ZaWolfColors.surface03),
    );
  }
}

class _MissingRoleNotice extends StatelessWidget {
  const _MissingRoleNotice({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: ZaWolfColors.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: ZaWolfColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizationEmptyState extends StatelessWidget {
  const _OrganizationEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 52,
            color: ZaWolfColors.textMuted,
          ),
          SizedBox(height: 12),
          Text(
            'لا توجد نتائج مطابقة في الهيكل الوظيفي.',
            style: TextStyle(color: ZaWolfColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

bool _isManagerRole(UserModel user) =>
    user.organizationLevel == OrganizationLevel.divisionManager ||
    user.organizationLevel == OrganizationLevel.departmentManager ||
    user.role == EmployeeRole.manager ||
    user.role == EmployeeRole.hrManager ||
    user.role == EmployeeRole.hrAdmin;

String _departmentOf(UserModel user) =>
    user.department.trim().isEmpty ? 'غير محدد' : user.department.trim();

int _roleOrder(UserModel user) => switch (user.role) {
  EmployeeRole.superAdmin => 0,
  EmployeeRole.hrManager => 1,
  EmployeeRole.hrAdmin => 2,
  EmployeeRole.manager => 3,
  EmployeeRole.teamLeader => 4,
  _ => 5,
};

int _compareUsers(UserModel a, UserModel b) {
  final roleComparison = _roleOrder(a).compareTo(_roleOrder(b));
  return roleComparison != 0
      ? roleComparison
      : a.displayName.compareTo(b.displayName);
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
