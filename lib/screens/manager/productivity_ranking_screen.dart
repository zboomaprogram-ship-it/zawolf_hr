import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/productivity_score_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/productivity_service.dart';
import '../../theme/theme.dart';
import '../../utils/user_facing_error.dart';
import '../../utils/payroll_cycle.dart';
import '../shared/productivity_score_details_sheet.dart';
import '../../design_system/components/feedback_states.dart'
    show EmptyState;
import '../../design_system/components/skeletons.dart' show SkeletonList;
import '../../design_system/components/rtl_navigation.dart';

class ProductivityRankingScreen extends StatefulWidget {
  const ProductivityRankingScreen({super.key});

  @override
  State<ProductivityRankingScreen> createState() =>
      _ProductivityRankingScreenState();
}

class _ProductivityRankingScreenState extends State<ProductivityRankingScreen> {
  final ProductivityService _service = ProductivityService();
  final TextEditingController _searchController = TextEditingController();
  late String _monthKey = PayrollCycle.keyFor(DateTime.now());
  String _department = 'all';
  String _scoreBand = 'all';
  bool _refreshing = false;
  bool _autoRefreshAttempted = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _changeCycle(int offset) {
    final cycle = PayrollCycle.forKey(_monthKey);
    final target = DateTime(cycle.end.year, cycle.end.month + offset);
    setState(() {
      _monthKey = PayrollCycle.forDate(
        DateTime(target.year, target.month, PayrollCycle.closingDay),
      ).key;
      _department = 'all';
      _autoRefreshAttempted = false;
    });
  }

  List<ProductivityScoreModel> _filtered(List<ProductivityScoreModel> scores) {
    final query = _searchController.text.trim().toLowerCase();
    return scores.where((score) {
      final matchesSearch =
          query.isEmpty ||
          score.employeeName.toLowerCase().contains(query) ||
          score.employeeId.toLowerCase().contains(query);
      final matchesDepartment =
          _department == 'all' || score.department == _department;
      final matchesScore = switch (_scoreBand) {
        'excellent' => score.overallScore >= 85,
        'good' => score.overallScore >= 70 && score.overallScore < 85,
        'follow_up' => score.overallScore < 70,
        _ => true,
      };
      return matchesSearch && matchesDepartment && matchesScore;
    }).toList();
  }

  Future<void> _refresh(
    UserModel reviewer, {
    bool showConfirmation = true,
  }) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final count = await _service.refreshRanking(reviewer, _monthKey);
      if (mounted && showConfirmation) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث إنتاجية $count موظف.')),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Error refreshing productivity: $error');
      debugPrint(stackTrace.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                error,
                fallback: 'تعذر تحديث الإنتاجية الآن. حاول مرة أخرى.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _refreshEmptyCacheOnce(UserModel reviewer) {
    if (_autoRefreshAttempted || _refreshing) return;
    _autoRefreshAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh(reviewer, showConfirmation: false);
    });
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'رجوع',
            icon: Icon(RtlNavigation.backIcon(context)),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text('ترتيب الإنتاجية', style: theme.textTheme.headlineMedium),
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
          stream: _service.watchRanking(reviewer, _monthKey),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonList(itemCount: 6, itemHeight: 84),
              );
            }
            if (snapshot.hasError) {
              return _LoadError(onRetry: () => _refresh(reviewer));
            }
            final scores = snapshot.data ?? [];
            if (scores.isEmpty) {
              _refreshEmptyCacheOnce(reviewer);
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.leaderboard_outlined,
                        size: 56,
                        color: ZaWolfColors.textMuted,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _refreshing
                            ? 'جارٍ تجهيز ترتيب شهر $_monthKey لأول مرة…'
                            : 'لا توجد بيانات متاحة لشهر $_monthKey',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final departments =
                scores
                    .map((score) => score.department)
                    .where((value) => value.trim().isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
            final filtered = _filtered(scores);
            final avgScore = scores.isEmpty
                ? 0.0
                : scores.map((s) => s.overallScore).reduce((a, b) => a + b) /
                    scores.length;
            final excellentCount =
                scores.where((s) => s.overallScore >= 85).length;
            final followUpCount =
                scores.where((s) => s.overallScore < 70).length;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 1320 : double.infinity,
                    ),
                    child: ListView(
                      padding: EdgeInsets.all(isDesktop ? 24 : 16),
                      children: [
                        _buildTopControlBar(departments, isDesktop),
                        const SizedBox(height: 16),
                        _buildPodiumAndStats(
                          scores,
                          avgScore,
                          excellentCount,
                          followUpCount,
                          isDesktop,
                          reviewer,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionHeader(filtered.length, scores.length, theme),
                        const SizedBox(height: 10),
                        if (filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 36),
                            child: EmptyState(
                              title: 'لا توجد نتائج مطابقة للفلاتر المحددة.',
                            ),
                          )
                        else if (isDesktop)
                          _buildDesktopDataTable(filtered, reviewer)
                        else
                          ...filtered.asMap().entries.map((entry) {
                            final rank = entry.key + 1;
                            final score = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildMobileScoreCard(score, rank, reviewer),
                            );
                          }),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopControlBar(List<String> departments, bool isDesktop) {
    return WolfCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _PeriodSelector(
            monthKey: _monthKey,
            canGoNext: _monthKey != PayrollCycle.keyFor(DateTime.now()),
            onPrevious: () => _changeCycle(-1),
            onNext: () => _changeCycle(1),
          ),
          const SizedBox(height: 12),
          if (isDesktop)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'بحث بالاسم أو كود الموظف',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: departments.contains(_department)
                        ? _department
                        : 'all',
                    decoration: const InputDecoration(
                      labelText: 'القسم',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('جميع الأقسام')),
                      ...departments.map(
                        (val) => DropdownMenuItem(
                          value: val,
                          child: Text(val, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _department = val ?? 'all'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _scoreBand,
                    decoration: const InputDecoration(
                      labelText: 'مستوى الأداء',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('جميع المستويات')),
                      DropdownMenuItem(value: 'excellent', child: Text('ممتاز (≥85%)')),
                      DropdownMenuItem(value: 'good', child: Text('جيد (70% - 84%)')),
                      DropdownMenuItem(value: 'follow_up', child: Text('متابعة (<70%)')),
                    ],
                    onChanged: (val) => setState(() => _scoreBand = val ?? 'all'),
                  ),
                ),
              ],
            )
          else ...[
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'بحث بالاسم أو كود الموظف',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: departments.contains(_department)
                        ? _department
                        : 'all',
                    decoration: const InputDecoration(
                      labelText: 'القسم',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('جميع الأقسام')),
                      ...departments.map(
                        (val) => DropdownMenuItem(
                          value: val,
                          child: Text(val, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _department = val ?? 'all'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _scoreBand,
                    decoration: const InputDecoration(
                      labelText: 'مستوى الأداء',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('جميع المستويات')),
                      DropdownMenuItem(value: 'excellent', child: Text('ممتاز (≥85%)')),
                      DropdownMenuItem(value: 'good', child: Text('جيد (70-84%)')),
                      DropdownMenuItem(value: 'follow_up', child: Text('متابعة (<70%)')),
                    ],
                    onChanged: (val) => setState(() => _scoreBand = val ?? 'all'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPodiumAndStats(
    List<ProductivityScoreModel> scores,
    double avgScore,
    int excellentCount,
    int followUpCount,
    bool isDesktop,
    UserModel reviewer,
  ) {
    final top3 = scores.take(3).toList();

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: _buildPodiumCard(top3, reviewer),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                _buildMetricCard(
                  icon: Icons.trending_up_rounded,
                  title: 'متوسط إنتاجية الفريق',
                  value: '${avgScore.toStringAsFixed(1)}%',
                  color: _scoreColor(avgScore),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        icon: Icons.verified_rounded,
                        title: 'المتميزون (≥85%)',
                        value: '$excellentCount موظف',
                        color: ZaWolfColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricCard(
                        icon: Icons.report_problem_outlined,
                        title: 'يحتاجون متابعة (<70%)',
                        value: '$followUpCount موظف',
                        color: ZaWolfColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildPodiumCard(top3, reviewer),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.trending_up_rounded,
                title: 'متوسط الإنتاجية',
                value: '${avgScore.toStringAsFixed(1)}%',
                color: _scoreColor(avgScore),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.verified_rounded,
                title: 'المتميزون',
                value: '$excellentCount',
                color: ZaWolfColors.success,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.report_problem_outlined,
                title: 'يحتاجون متابعة',
                value: '$followUpCount',
                color: ZaWolfColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPodiumCard(List<ProductivityScoreModel> top3, UserModel reviewer) {
    if (top3.isEmpty) return const SizedBox.shrink();

    return WolfCard(
      hasBorderGlow: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: ZaWolfColors.perfGold, size: 22),
              const SizedBox(width: 8),
              const Text(
                'منصة شرف الإنتاجية والالتزام',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 2nd place (Right in RTL)
              if (top3.length > 1)
                Expanded(
                  child: _podiumStep(
                    score: top3[1],
                    rank: 2,
                    height: 110,
                    color: const Color(0xFFC0C0C0),
                    trophy: Icons.military_tech_rounded,
                    reviewer: reviewer,
                  ),
                ),
              // 1st place (Center, tallest)
              Expanded(
                child: _podiumStep(
                  score: top3[0],
                  rank: 1,
                  height: 135,
                  color: ZaWolfColors.perfGold,
                  trophy: Icons.emoji_events_rounded,
                  reviewer: reviewer,
                ),
              ),
              // 3rd place (Left in RTL)
              if (top3.length > 2)
                Expanded(
                  child: _podiumStep(
                    score: top3[2],
                    rank: 3,
                    height: 90,
                    color: const Color(0xFFCD7F32),
                    trophy: Icons.workspace_premium_rounded,
                    reviewer: reviewer,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _podiumStep({
    required ProductivityScoreModel score,
    required int rank,
    required double height,
    required Color color,
    required IconData trophy,
    required UserModel reviewer,
  }) {
    return InkWell(
      onTap: () => _openDetails(score, reviewer),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trophy, color: color, size: rank == 1 ? 30 : 24),
          const SizedBox(height: 4),
          Text(
            score.employeeName,
            style: TextStyle(
              color: Colors.white,
              fontWeight: rank == 1 ? FontWeight.bold : FontWeight.w600,
              fontSize: rank == 1 ? 13 : 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            score.department,
            style: const TextStyle(color: ZaWolfColors.textMuted, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.35),
                  color.withValues(alpha: 0.10),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '#$rank',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: rank == 1 ? 20 : 16,
                    ),
                  ),
                  Text(
                    '${score.overallScore.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: ZaWolfColors.textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(int filteredCount, int totalCount, ThemeData theme) {
    return Row(
      children: [
        const Icon(Icons.list_alt_rounded, color: ZaWolfColors.primaryCyan, size: 20),
        const SizedBox(width: 8),
        Text(
          'قائمة ترتيب الموظفين',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: ZaWolfColors.surface02,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$filteredCount من إجمالي $totalCount موظف',
            style: const TextStyle(color: ZaWolfColors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopDataTable(
    List<ProductivityScoreModel> scores,
    UserModel reviewer,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(ZaWolfColors.surface02),
          horizontalMargin: 16,
          columnSpacing: 18,
          columns: const [
            DataColumn(label: Text('الترتيب', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('الموظف', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('القسم', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('الحضور', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('دقة المواعيد', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('المهام', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('الأهداف / KPI', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('النتيجة الإجمالية', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('الإجراء', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: scores.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final score = entry.value;
            final color = _scoreColor(score.overallScore);

            return DataRow(
              cells: [
                DataCell(
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: rank <= 3
                          ? (rank == 1
                              ? ZaWolfColors.perfGold.withValues(alpha: 0.2)
                              : rank == 2
                                  ? const Color(0xFFC0C0C0).withValues(alpha: 0.2)
                                  : const Color(0xFFCD7F32).withValues(alpha: 0.2))
                          : ZaWolfColors.surface03,
                    ),
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: rank <= 3 ? Colors.white : ZaWolfColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        score.employeeName,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        score.employeeId,
                        style: const TextStyle(color: ZaWolfColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                DataCell(Text(score.department)),
                DataCell(Text('${score.attendanceScore.toStringAsFixed(0)}%')),
                DataCell(Text('${score.punctualityScore.toStringAsFixed(0)}%')),
                DataCell(Text('${score.taskCompletionScore.toStringAsFixed(0)}%')),
                DataCell(Text('${score.kpiScore.toStringAsFixed(0)}%')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 60,
                        child: LinearProgressIndicator(
                          value: (score.overallScore / 100).clamp(0, 1),
                          color: color,
                          backgroundColor: ZaWolfColors.surface03,
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${score.overallScore.toStringAsFixed(0)}%',
                        style: TextStyle(color: color, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: ZaWolfColors.surface03),
                    ),
                    onPressed: () => _openDetails(score, reviewer),
                    icon: Icon(RtlNavigation.chevronEnd(context), size: 14),
                    label: const Text('التفاصيل', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileScoreCard(
    ProductivityScoreModel score,
    int rank,
    UserModel reviewer,
  ) {
    final color = _scoreColor(score.overallScore);

    return WolfCard(
      onTap: () => _openDetails(score, reviewer),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _RankBadge(rank: rank),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score.employeeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${score.department} · ${score.employeeId}',
                  style: const TextStyle(color: ZaWolfColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: (score.overallScore / 100).clamp(0, 1),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(6),
                  color: color,
                  backgroundColor: ZaWolfColors.surface03,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${score.overallScore.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Icon(
                RtlNavigation.chevronEnd(context),
                color: ZaWolfColors.textMuted,
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openDetails(ProductivityScoreModel score, UserModel reviewer) {
    showProductivityScoreDetails(
      context,
      score,
      onUpdateBehavior: (score, value, reason) async {
        await _service.updateBehaviorScore(
          employeeUserId: score.userId,
          reviewer: reviewer,
          monthKey: score.monthKey,
          behaviorScore: value,
          reason: reason,
        );
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  Color _scoreColor(double value) {
    if (value >= 85) return ZaWolfColors.success;
    if (value >= 70) return ZaWolfColors.warning;
    return ZaWolfColors.error;
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('تعذر تحميل الإنتاجية، أعد المحاولة'),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.monthKey,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final String monthKey;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final cycle = PayrollCycle.forKey(monthKey);
    return Row(
      children: [
        IconButton(
          tooltip: 'الدورة السابقة',
          onPressed: onPrevious,
          icon: Icon(RtlNavigation.chevronStart(context)),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'دورة الرواتب $monthKey',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                cycle.arabicRangeLabel,
                style: const TextStyle(
                  color: ZaWolfColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'الدورة التالية',
          onPressed: canGoNext ? onNext : null,
          icon: Icon(RtlNavigation.chevronEnd(context)),
        ),
      ],
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final color = rank == 1
        ? ZaWolfColors.perfGold
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : ZaWolfColors.primaryCyan;

    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: isTop3 ? 0.2 : 0.1),
        border: Border.all(
          color: color.withValues(alpha: isTop3 ? 0.6 : 0.3),
          width: isTop3 ? 1.5 : 1,
        ),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
