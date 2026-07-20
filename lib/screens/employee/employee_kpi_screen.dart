import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/kpi_model.dart';
import '../../services/auth_service.dart';
import '../../services/kpi_service.dart';
import '../../theme/theme.dart';
import '../../utils/payroll_cycle.dart';

class EmployeeKpiScreen extends StatelessWidget {
  const EmployeeKpiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final theme = Theme.of(context);
    final monthKey = PayrollCycle.keyFor(DateTime.now());

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('أهداف KPI', style: theme.textTheme.headlineMedium),
      ),
      body: StreamBuilder<List<EmployeeKpiModel>>(
        stream: KpiService().watchMyKpis(user.uid, monthKey),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            );
          }
          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.flag_outlined,
                      color: ZaWolfColors.textMuted,
                      size: 56,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'لم يتم تعيين أهداف KPI لهذا الشهر بعد',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          final kpi = records.first;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              WolfCard(
                hasBorderGlow: true,
                child: Column(
                  children: [
                    Text(
                      'تقدم شهر $monthKey',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      kpi.status == KpiStatus.finalized
                          ? 'نتيجة معتمدة'
                          : 'قيد المتابعة',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: kpi.status == KpiStatus.finalized
                            ? ZaWolfColors.success
                            : ZaWolfColors.warning,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${kpi.overallProgress.toStringAsFixed(1)}%',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: ZaWolfColors.primaryCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: (kpi.overallProgress / 100).clamp(0, 1),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                      backgroundColor: ZaWolfColors.surface03,
                      color: ZaWolfColors.primaryCyan,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...kpi.metrics.map(
                (metric) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: WolfCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          metric.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${metric.actual.toStringAsFixed(0)} / ${metric.target.toStringAsFixed(0)} ${metric.unit}',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.right,
                        ),
                        Text(
                          '${KpiMetricDirection.arabicLabel(metric.direction)} · الوزن ${metric.weight.toStringAsFixed(0)}%',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.right,
                        ),
                        if (metric.managerComment.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'ملاحظة المدير: ${metric.managerComment}',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.right,
                          ),
                        ],
                        if (metric.evidenceUrl.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'تم إرفاق رابط إثبات',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: ZaWolfColors.primaryCyan,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ],
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: (metric.completion / 100).clamp(0, 1),
                          minHeight: 7,
                          borderRadius: BorderRadius.circular(8),
                          backgroundColor: ZaWolfColors.surface03,
                          color: metric.completion >= 100
                              ? ZaWolfColors.success
                              : ZaWolfColors.warning,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
