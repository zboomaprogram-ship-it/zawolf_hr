import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/productivity_score_model.dart';
import '../../services/auth_service.dart';
import '../../services/productivity_service.dart';
import '../../theme/theme.dart';

class EmployeeProductivityScreen extends StatefulWidget {
  const EmployeeProductivityScreen({super.key});

  @override
  State<EmployeeProductivityScreen> createState() =>
      _EmployeeProductivityScreenState();
}

class _EmployeeProductivityScreenState
    extends State<EmployeeProductivityScreen> {
  late final String _monthKey = DateFormat('yyyy-MM').format(DateTime.now());
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
    return Scaffold(
      appBar: AppBar(
        title: Text('إنتاجيتي', style: theme.textTheme.headlineMedium),
      ),
      body: FutureBuilder<ProductivityScoreModel>(
        future: _scoreFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
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
          return RefreshIndicator(
            color: ZaWolfColors.primaryCyan,
            onRefresh: () async {
              setState(() => _scoreFuture = _loadScore());
              await _scoreFuture;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                WolfCard(
                  hasBorderGlow: true,
                  child: Column(
                    children: [
                      Text(
                        'شهر $_monthKey',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${score.overallScore.toStringAsFixed(1)}%',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: _scoreColor(score.overallScore),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        score.statusLabel,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ScoreBar(
                  label: 'الحضور',
                  value: score.attendanceScore,
                  color: ZaWolfColors.success,
                ),
                _ScoreBar(
                  label: 'الالتزام بالمواعيد',
                  value: score.punctualityScore,
                  color: ZaWolfColors.warning,
                ),
                _ScoreBar(
                  label: 'إنجاز المهام',
                  value: score.taskCompletionScore,
                  color: ZaWolfColors.primaryCyan,
                ),
                _ScoreBar(
                  label: 'جودة المهام',
                  value: score.taskQualityScore,
                  color: ZaWolfColors.perfGold,
                ),
                _ScoreBar(
                  label: 'KPI',
                  value: score.kpiScore,
                  color: ZaWolfColors.dayoffPurple,
                ),
                const SizedBox(height: 12),
                WolfCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MetricLine(
                        label: 'المهام المكتملة',
                        value: '${score.completedTasks}/${score.totalTasks}',
                      ),
                      _MetricLine(
                        label: 'المهام المتأخرة',
                        value: '${score.overdueTasks}',
                      ),
                      _MetricLine(
                        label: 'أيام الغياب',
                        value: '${score.absentDays}',
                      ),
                      _MetricLine(
                        label: 'أيام التأخير',
                        value: '${score.lateDays}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

class _ScoreBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ScoreBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WolfCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '${value.toStringAsFixed(0)}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(label, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (value / 100).clamp(0, 1),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              color: color,
              backgroundColor: ZaWolfColors.surface03,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  final String label;
  final String value;

  const _MetricLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(value, style: const TextStyle(color: Colors.white)),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(color: ZaWolfColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
