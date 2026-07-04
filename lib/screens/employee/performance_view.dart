import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/performance_service.dart';
import '../../models/performance_model.dart';
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';

class EmployeePerformanceViewScreen extends StatefulWidget {
  const EmployeePerformanceViewScreen({super.key});

  @override
  State<EmployeePerformanceViewScreen> createState() =>
      _EmployeePerformanceViewScreenState();
}

class _EmployeePerformanceViewScreenState
    extends State<EmployeePerformanceViewScreen> {
  final PerformanceService _performanceService = PerformanceService();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'لوحة تقييم الأداء والـ KPIs',
          style: theme.textTheme.headlineMedium,
        ),
      ),
      body: StreamBuilder<List<PerformanceModel>>(
        stream: _performanceService.watchUserPerformanceHistory(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            );
          }

          final history = snapshot.data ?? [];
          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    color: ZaWolfColors.textMuted,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لم يتم نشر أي تقييم أداء لك بعد',
                    style: theme.textTheme.titleLarge!.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سيتم إرسال إشعار لك بمجرد أن يقوم مديرك المباشر بنشر التقييم الشهري.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ZaWolfColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          // Fetch the latest published month evaluation
          final latest = history.first;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Glowing radial grade card
                _buildGradeGlowCard(latest, theme),
                const SizedBox(height: 24),

                // KPI progress bars breakdown
                Text(
                  'تفاصيل مؤشرات الأداء (KPIs)',
                  style: theme.textTheme.titleLarge!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),

                WolfCard(
                  child: Column(
                    children: [
                      _buildIndicatorBar(
                        'حضور وانصراف (Attendance)',
                        latest.attendanceScore,
                        ZaWolfColors.success,
                        theme,
                      ),
                      const SizedBox(height: 16),
                      _buildIndicatorBar(
                        'الالتزام بالمواعيد (Punctuality)',
                        latest.punctualityScore,
                        ZaWolfColors.warning,
                        theme,
                      ),
                      const SizedBox(height: 16),
                      _buildIndicatorBar(
                        'جودة المهام (Quality of Work)',
                        latest.qualityScore,
                        ZaWolfColors.primaryCyan,
                        theme,
                      ),
                      const SizedBox(height: 16),
                      _buildIndicatorBar(
                        'التعاون العمل الجماعي (Teamwork)',
                        latest.teamworkScore,
                        ZaWolfColors.primaryBlue,
                        theme,
                      ),
                      const SizedBox(height: 16),
                      _buildIndicatorBar(
                        'الالتزام والمبادرة (Commitment)',
                        latest.commitmentScore,
                        ZaWolfColors.dayoffPurple,
                        theme,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Manager commentary card
                if (latest.comments != null && latest.comments!.isNotEmpty) ...[
                  Text(
                    'تعليق وتوصيات المدير المباشر',
                    style: theme.textTheme.titleLarge!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 12),
                  WolfCard(
                    hasBorderGlow: true,
                    child: Text(
                      latest.comments!,
                      style: const TextStyle(color: Colors.white, height: 1.5),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Grade History logs
                if (history.length > 1) ...[
                  Text(
                    'سجل التقييمات السابقة',
                    style: theme.textTheme.titleLarge!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: history.length - 1,
                    itemBuilder: (context, index) {
                      final item = history[index + 1];
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
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: ZaWolfColors.primaryCyan.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Grade: ${item.grade}',
                                  style: const TextStyle(
                                    color: ZaWolfColors.primaryCyan,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'التقييم العام: ${item.overallScore.toStringAsFixed(1)}%',
                                    style: theme.textTheme.bodyMedium!.copyWith(
                                      color: ZaWolfColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    item.monthKey,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
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
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGradeGlowCard(PerformanceModel evaluation, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ZaWolfColors.primaryCyan.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: ZaWolfColors.primaryCyan.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'تقييم أداء شهر ${evaluation.monthKey}',
            style: theme.textTheme.titleMedium!.copyWith(
              color: ZaWolfColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Radial letter grade
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ZaWolfColors.surface02,
              border: Border.all(color: ZaWolfColors.primaryCyan, width: 3),
              boxShadow: [
                BoxShadow(
                  color: ZaWolfColors.primaryCyan.withValues(alpha: 0.2),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: Text(
                evaluation.grade,
                style: const TextStyle(
                  color: ZaWolfColors.primaryCyan,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Rajdhani',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'معدل التقدم العام: ${evaluation.overallScore.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'JetBrains Mono',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorBar(
    String title,
    double score,
    Color color,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${score.toInt()}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontFamily: 'JetBrains Mono',
              ),
            ),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100.0,
            color: color,
            backgroundColor: ZaWolfColors.surface02,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
