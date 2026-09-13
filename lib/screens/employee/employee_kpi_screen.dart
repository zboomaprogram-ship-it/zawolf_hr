import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../components/sales_kpi_details_panel.dart';
import '../../models/kpi_model.dart';
import '../../services/auth_service.dart';
import '../../services/kpi_service.dart';
import '../../theme/theme.dart';
import '../../utils/payroll_cycle.dart';
import '../../design_system/components/rtl_navigation.dart';

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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          return Scaffold(
            appBar: AppBar(
              leading: Navigator.canPop(context)
                  ? IconButton(
                      icon: Icon(RtlNavigation.backIcon(context)),
                      tooltip: 'رجوع',
                      onPressed: () => Navigator.pop(context),
                    )
                  : null,
              title: Text('أهداف KPI الشهرية', style: theme.textTheme.headlineMedium),
            ),
            body: StreamBuilder<List<EmployeeKpiModel>>(
              stream: KpiService().watchMyKpis(user, monthKey),
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
                              color: ZaWolfColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final kpi = records.first;
                final isApiKpi = kpi.externalSource == 'sales_analytics_api';

                if (isDesktop) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left sidebar: Hero progress card and provider details
                        SizedBox(
                          width: 380,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeroProgressCard(context, kpi, monthKey, isApiKpi),
                              if (kpi.providerDetails.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                SalesKpiDetailsPanel(kpi: kpi),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),

                        // Right: Metrics cards grid
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.analytics, color: ZaWolfColors.primaryCyan, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'المؤشرات التفصيلية المستهدفة (${kpi.metrics.length})',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildMetricsGrid(context, kpi.metrics, constraints.maxWidth - 404),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Mobile layout
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeroProgressCard(context, kpi, monthKey, isApiKpi),
                    const SizedBox(height: 16),
                    if (kpi.providerDetails.isNotEmpty) ...[
                      SalesKpiDetailsPanel(kpi: kpi),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        const Icon(Icons.analytics, color: ZaWolfColors.primaryCyan, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'المؤشرات التفصيلية (${kpi.metrics.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...kpi.metrics.map(
                      (metric) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MetricItemCard(metric: metric),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroProgressCard(
    BuildContext context,
    EmployeeKpiModel kpi,
    String monthKey,
    bool isApiKpi,
  ) {
    final theme = Theme.of(context);
    final isFinalized = kpi.status == KpiStatus.finalized;

    return WolfCard(
      hasBorderGlow: true,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isFinalized
                      ? ZaWolfColors.success.withValues(alpha: 0.15)
                      : ZaWolfColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isFinalized ? ZaWolfColors.success : ZaWolfColors.warning,
                  ),
                ),
                child: Text(
                  isFinalized ? 'معتمد ومغلق' : 'قيد المتابعة',
                  style: TextStyle(
                    color: isFinalized ? ZaWolfColors.success : ZaWolfColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'دورة $monthKey',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ZaWolfColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${kpi.overallProgress.toStringAsFixed(1)}%',
            style: theme.textTheme.displaySmall?.copyWith(
              color: ZaWolfColors.perfGold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'الإنجاز الإجمالي العام',
            style: theme.textTheme.bodySmall?.copyWith(
              color: ZaWolfColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (kpi.overallProgress / 100).clamp(0, 1),
            minHeight: 10,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: ZaWolfColors.surface03,
            color: kpi.overallProgress >= 100
                ? ZaWolfColors.success
                : ZaWolfColors.primaryCyan,
          ),
          if (isApiKpi) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ZaWolfColors.primaryCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: ZaWolfColors.primaryCyan.withValues(alpha: 0.35),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sync, color: ZaWolfColors.primaryCyan, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'متصل بنظام المبيعات · تحديث تلقائي',
                    style: TextStyle(
                      color: ZaWolfColors.primaryCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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

  Widget _buildMetricsGrid(
    BuildContext context,
    List<EmployeeKpiMetric> metrics,
    double availableWidth,
  ) {
    final colCount = availableWidth >= 700 ? 2 : 1;
    final columns = List.generate(colCount, (_) => <EmployeeKpiMetric>[]);
    for (var i = 0; i < metrics.length; i++) {
      columns[i % colCount].add(metrics[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < colCount; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: columns[i].map(
                (metric) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _MetricItemCard(metric: metric),
                ),
              ).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricItemCard extends StatelessWidget {
  final EmployeeKpiMetric metric;

  const _MetricItemCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = metric.completion >= 100;

    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: ZaWolfColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              if (!metric.editable)
                const Tooltip(
                  message: 'يتم تحديثه تلقائياً من المنظومة',
                  child: Icon(
                    Icons.lock_clock_outlined,
                    color: ZaWolfColors.primaryCyan,
                    size: 16,
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ZaWolfColors.surface02,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ZaWolfColors.surface03),
                ),
                child: Text(
                  'وزن ${metric.weight.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: ZaWolfColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    metric.actual.toStringAsFixed(0),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: isDone ? ZaWolfColors.success : ZaWolfColors.primaryCyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    ' / ${metric.target.toStringAsFixed(0)} ${metric.unit}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: ZaWolfColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                '${metric.completion.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: isDone ? ZaWolfColors.success : ZaWolfColors.perfGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (metric.completion / 100).clamp(0, 1),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: ZaWolfColors.surface03,
            color: isDone ? ZaWolfColors.success : ZaWolfColors.primaryCyan,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                KpiMetricDirection.arabicLabel(metric.direction),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ZaWolfColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              if (metric.evidenceUrl.isNotEmpty)
                const Row(
                  children: [
                    Icon(Icons.attachment, color: ZaWolfColors.primaryCyan, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'مرفق إثبات',
                      style: TextStyle(color: ZaWolfColors.primaryCyan, fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
          if (metric.managerComment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ZaWolfColors.surface02,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'ملاحظة المدير: ${metric.managerComment}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ZaWolfColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
