import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../models/productivity_score_model.dart';
import '../../theme/theme.dart';

Future<void> showProductivityScoreDetails(
  BuildContext context,
  ProductivityScoreModel score,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ZaWolfColors.surface01,
    useSafeArea: true,
    builder: (context) => _ScoreDetailsSheet(score: score),
  );
}

Future<void> showDepartmentProductivityDetails(
  BuildContext context, {
  required String department,
  required List<ProductivityScoreModel> scores,
}) {
  final sorted = [...scores]
    ..sort((a, b) => b.overallScore.compareTo(a.overallScore));
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ZaWolfColors.surface01,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            _SheetHeader(
              title: department,
              subtitle: '${scores.length} موظف · تفاصيل الأداء',
            ),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: sorted.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: ZaWolfColors.surface03),
                itemBuilder: (context, index) {
                  final score = sorted[index];
                  return ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    childrenPadding: const EdgeInsets.only(bottom: 14),
                    leading: _ScoreCircle(value: score.overallScore),
                    title: Text(
                      score.employeeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${score.employeeId} · ${score.statusLabel}',
                    ),
                    children: [_ScoreBreakdown(score: score)],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ScoreDetailsSheet extends StatelessWidget {
  const _ScoreDetailsSheet({required this.score});

  final ProductivityScoreModel score;

  @override
  Widget build(BuildContext context) {
    final calculatedAt = score.calculatedAt == null
        ? 'لم يُسجل وقت الحساب'
        : intl.DateFormat('yyyy/MM/dd - hh:mm a').format(score.calculatedAt!);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.74,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => Column(
          children: [
            _SheetHeader(
              title: score.employeeName,
              subtitle: '${score.department} · ${score.employeeId}',
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  Row(
                    children: [
                      _ScoreCircle(value: score.overallScore, size: 68),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              score.statusLabel,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: _scoreColor(score.overallScore),
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              'دورة ${score.monthKey}',
                              style: const TextStyle(
                                color: ZaWolfColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _ScoreBreakdown(score: score),
                  const SizedBox(height: 18),
                  const Divider(color: ZaWolfColors.surface03),
                  _MetricLine(
                    label: 'المهام المكتملة',
                    value: '${score.completedTasks} من ${score.totalTasks}',
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
                  const SizedBox(height: 12),
                  Text(
                    'آخر حساب: $calculatedAt',
                    style: const TextStyle(
                      color: ZaWolfColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: ZaWolfColors.textMuted,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: ZaWolfColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'إغلاق',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreBreakdown extends StatelessWidget {
  const _ScoreBreakdown({required this.score});

  final ProductivityScoreModel score;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ScoreBar(label: 'الحضور', value: score.attendanceScore),
        _ScoreBar(label: 'الالتزام بالمواعيد', value: score.punctualityScore),
        if (score.hasTaskData)
          _ScoreBar(label: 'إنجاز المهام', value: score.taskCompletionScore),
        if (score.hasTaskQualityData)
          _ScoreBar(label: 'جودة المهام', value: score.taskQualityScore),
        if (score.hasKpiData) _ScoreBar(label: 'KPI', value: score.kpiScore),
        if (!score.hasTaskData || !score.hasKpiData)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'المكونات غير المتاحة لا تدخل في المتوسط النهائي.',
              style: TextStyle(color: ZaWolfColors.textMuted, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                '${value.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: _scoreColor(value),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: (value / 100).clamp(0, 1),
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
            color: _scoreColor(value),
            backgroundColor: ZaWolfColors.surface03,
          ),
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCircle extends StatelessWidget {
  const _ScoreCircle({required this.value, this.size = 48});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _scoreColor(value).withValues(alpha: 0.12),
        border: Border.all(color: _scoreColor(value).withValues(alpha: 0.5)),
      ),
      child: Text(
        value.toStringAsFixed(0),
        style: TextStyle(
          color: _scoreColor(value),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

Color _scoreColor(double value) {
  if (value >= 85) return ZaWolfColors.success;
  if (value >= 70) return ZaWolfColors.warning;
  return ZaWolfColors.error;
}
