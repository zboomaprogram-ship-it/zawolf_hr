import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/productivity_score_model.dart';
import '../../services/auth_service.dart';
import '../../services/productivity_service.dart';
import '../../theme/theme.dart';
import '../../utils/payroll_cycle.dart';
import '../../design_system/components/skeletons.dart' show SkeletonList;
import '../../design_system/components/rtl_navigation.dart';

class EmployeeProductivityScreen extends StatefulWidget {
  const EmployeeProductivityScreen({super.key});

  @override
  State<EmployeeProductivityScreen> createState() =>
      _EmployeeProductivityScreenState();
}

class _EmployeeProductivityScreenState
    extends State<EmployeeProductivityScreen> {
  late final String _monthKey = PayrollCycle.keyFor(DateTime.now());
  final ProductivityService _service = ProductivityService();
  Future<ProductivityScoreModel>? _scoreFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scoreFuture ??= _loadScore();
  }

  Future<ProductivityScoreModel> _loadScore() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) throw Exception('لم يتم العثور على المستخدم');
    return _service.calculateForUser(user, _monthKey);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          title: Text('إنتاجيتي', style: theme.textTheme.headlineMedium),
        ),
        body: FutureBuilder<ProductivityScoreModel>(
          future: _scoreFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonList(itemCount: 4, itemHeight: 88),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Text(
                  'تعذر حساب الإنتاجية الآن',
                  style: theme.textTheme.titleMedium,
                ),
              );
            }
            final score = snapshot.data!;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                return RefreshIndicator(
                  color: ZaWolfColors.primaryCyan,
                  onRefresh: () async {
                    setState(() => _scoreFuture = _loadScore());
                    await _scoreFuture;
                  },
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 1200 : double.infinity,
                      ),
                      child: ListView(
                        padding: EdgeInsets.all(isDesktop ? 24 : 16),
                        children: [
                          if (isDesktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    children: [
                                      _buildScoreHero(score, theme, isDesktop),
                                      const SizedBox(height: 16),
                                      _buildStatusNote(score),
                                      const SizedBox(height: 16),
                                      _buildMetricsCard(score),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 6,
                                  child: _buildBreakdownColumn(score),
                                ),
                              ],
                            )
                          else ...[
                            _buildScoreHero(score, theme, isDesktop),
                            const SizedBox(height: 12),
                            _buildStatusNote(score),
                            const SizedBox(height: 16),
                            _buildBreakdownColumn(score),
                            const SizedBox(height: 16),
                            _buildMetricsCard(score),
                          ],
                        ],
                      ),
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

  Widget _buildScoreHero(ProductivityScoreModel score, ThemeData theme, bool isDesktop) {
    final color = _scoreColor(score.overallScore);
    return WolfCard(
      hasBorderGlow: true,
      padding: EdgeInsets.all(isDesktop ? 28 : 20),
      child: Column(
        children: [
          Text(
            'دورة شهر $_monthKey',
            style: const TextStyle(
              color: ZaWolfColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: isDesktop ? 120 : 100,
            height: isDesktop ? 120 : 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.5), width: 3),
            ),
            child: Center(
              child: Text(
                '${score.overallScore.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: isDesktop ? 34 : 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              score.statusLabel,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusNote(ProductivityScoreModel score) {
    return WolfCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          score.inputState == ProductivityInputState.complete
              ? Icons.verified_outlined
              : Icons.info_outline,
          color: score.inputState == ProductivityInputState.complete
              ? ZaWolfColors.success
              : ZaWolfColors.warning,
        ),
        title: Text(
          'حالة احتساب المؤشرات: ${score.inputStateLabel}',
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          score.inputState == ProductivityInputState.complete
              ? 'تم احتساب درجات الحضور والمواعيد والمهام وKPI بدقة تامة لهذه الدورة.'
              : 'قد لا تتوفر بعض مصادر المهام أو KPI بعد لهذه الدورة، ويتم تقدير النتيجة بعدالة.',
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildBreakdownColumn(ProductivityScoreModel score) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تفاصيل معايير التقييم',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        _ScoreBar(
          label: 'الحضور والالتزام',
          value: score.attendanceScore,
          color: ZaWolfColors.success,
          icon: Icons.fingerprint_rounded,
        ),
        _ScoreBar(
          label: 'الالتزام بالمواعيد المحددة',
          value: score.punctualityScore,
          color: ZaWolfColors.warning,
          icon: Icons.access_time_rounded,
        ),
        if (score.hasTaskData)
          _ScoreBar(
            label: 'إنجاز المهام المسندة',
            value: score.taskCompletionScore,
            color: ZaWolfColors.primaryCyan,
            icon: Icons.task_alt_rounded,
          ),
        if (score.hasTaskQualityData)
          _ScoreBar(
            label: 'جودة مخرجات المهام',
            value: score.taskQualityScore,
            color: ZaWolfColors.perfGold,
            icon: Icons.star_outline_rounded,
          ),
        if (score.hasKpiData)
          _ScoreBar(
            label: 'مؤشرات الأداء الرئيسية (KPI)',
            value: score.kpiScore,
            color: ZaWolfColors.dayoffPurple,
            icon: Icons.flag_outlined,
          )
        else
          WolfCard(
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: ZaWolfColors.textMuted, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'لم يتم تعيين أهداف KPI خاصة لهذه الدورة؛ ولا تؤثر سلباً على نتيجتك.',
                    style: TextStyle(color: ZaWolfColors.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMetricsCard(ProductivityScoreModel score) {
    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ملخص الأنشطة التشغيلية',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          _MetricLine(
            label: 'المهام المكتملة',
            value: '${score.completedTasks} من ${score.totalTasks}',
            color: ZaWolfColors.success,
          ),
          const Divider(color: ZaWolfColors.surface03, height: 1),
          _MetricLine(
            label: 'المهام المتأخرة',
            value: '${score.overdueTasks}',
            color: score.overdueTasks > 0 ? ZaWolfColors.error : ZaWolfColors.textPrimary,
          ),
          const Divider(color: ZaWolfColors.surface03, height: 1),
          _MetricLine(
            label: 'أيام الغياب',
            value: '${score.absentDays} يوم',
            color: score.absentDays > 0 ? ZaWolfColors.error : ZaWolfColors.textPrimary,
          ),
          const Divider(color: ZaWolfColors.surface03, height: 1),
          _MetricLine(
            label: 'أيام التأخير',
            value: '${score.lateDays} يوم',
            color: score.lateDays > 0 ? ZaWolfColors.warning : ZaWolfColors.textPrimary,
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double value) {
    if (value >= 85) return ZaWolfColors.success;
    if (value >= 70) return ZaWolfColors.warning;
    return ZaWolfColors.error;
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  const _ScoreBar({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${value.toStringAsFixed(0)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (value / 100).clamp(0, 1),
            minHeight: 7,
            borderRadius: BorderRadius.circular(6),
            color: color,
            backgroundColor: ZaWolfColors.surface03,
          ),
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricLine({
    required this.label,
    required this.value,
    this.color = ZaWolfColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: ZaWolfColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
