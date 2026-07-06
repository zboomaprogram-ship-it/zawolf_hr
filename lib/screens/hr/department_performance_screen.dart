import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/productivity_score_model.dart';
import '../../models/user_model.dart';
import '../../models/employee_role.dart';
import '../../services/auth_service.dart';
import '../../services/productivity_service.dart';
import '../../theme/theme.dart';

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
  late final String _monthKey = DateFormat('yyyy-MM').format(DateTime.now());
  bool _refreshing = false;

  Future<void> _refresh(UserModel reviewer) async {
    setState(() => _refreshing = true);
    try {
      final count = await _service.refreshRanking(reviewer, _monthKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث بيانات $count موظف.')),
        );
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
      final totalScore = e.value.fold<double>(0, (sum, item) => sum + item.overallScore);
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

    return Scaffold(
      appBar: AppBar(
        title: Text('أداء الأقسام', style: theme.textTheme.headlineMedium),
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
      ),
      body: StreamBuilder<List<ProductivityScoreModel>>(
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
          final needsFollowUp = [...departments]..sort((a, b) => a.averageScore.compareTo(b.averageScore));
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
      ),
    );
  }

  Color _scoreColor(double value) {
    if (value >= 85) return ZaWolfColors.success;
    if (value >= 70) return ZaWolfColors.warning;
    return ZaWolfColors.error;
  }
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
