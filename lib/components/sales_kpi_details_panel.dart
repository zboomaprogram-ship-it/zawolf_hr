import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/kpi_model.dart';
import '../theme/theme.dart';

class SalesKpiDetailsPanel extends StatelessWidget {
  final EmployeeKpiModel kpi;
  final bool compact;

  const SalesKpiDetailsPanel({
    super.key,
    required this.kpi,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final details = kpi.providerDetails;
    if (details.isEmpty) return const SizedBox.shrink();
    final isTeleSales =
        kpi.providerDepartment == 'tele_sales' ||
        details['kind'] == 'tele_sales';
    final metrics = isTeleSales
        ? _teleSalesMetrics(details)
        : _salesMetrics(details);
    final progress = _percentValue(details['finalKpi']);
    final accent = isTeleSales
        ? ZaWolfColors.primaryCyan
        : ZaWolfColors.perfGold;

    return Container(
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _KpiScore(value: progress, color: accent),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isTeleSales ? 'المبيعات الهاتفية' : 'المبيعات',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  Text(
                    kpi.employeeName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Icon(
                isTeleSales
                    ? Icons.support_agent_outlined
                    : Icons.payments_outlined,
                color: accent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 560
                  ? 3
                  : 2;
              final spacing = compact ? 8.0 : 10.0;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: metrics
                    .map(
                      (metric) => SizedBox(
                        width: width,
                        child: _ProviderMetricTile(metric: metric),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 14),
          _AchievementBar(
            label: isTeleSales ? 'تحقيق هدف الاجتماعات' : 'تحقيق هدف الفواتير',
            value: isTeleSales
                ? _percentValue(details['achieved'])
                : _percentValue(details['invoiceAchievement']),
            color: accent,
          ),
          const SizedBox(height: 10),
          _AchievementBar(
            label: isTeleSales ? 'نسبة الإغلاق' : 'تحويل المبيعات',
            value: isTeleSales
                ? _percentValue(details['vsMeetings'])
                : _percentValue(details['conversion']),
            color: ZaWolfColors.primaryCyan,
          ),
        ],
      ),
    );
  }

  List<_ProviderMetric> _salesMetrics(Map<String, dynamic> details) => [
    _ProviderMetric('المبيعات المؤكدة', _integer(details['confirmedSales'])),
    _ProviderMetric('الاجتماعات', _integer(details['meetings'])),
    _ProviderMetric('قيمة المبيعات', _money(details['totalPrice'])),
    _ProviderMetric('الدفعة المقدمة', _money(details['downPayment'])),
    _ProviderMetric('الدخل الشهري', _money(details['monthlyIncome'])),
    _ProviderMetric('الهدف', _money(details['target'])),
    _ProviderMetric('التحويل', _percent(details['conversion'])),
    _ProviderMetric('نتيجة KPI', _percent(details['finalKpi'])),
  ];

  List<_ProviderMetric> _teleSalesMetrics(Map<String, dynamic> details) => [
    _ProviderMetric('العملاء المحتملون', _integer(details['totalLeads'])),
    _ProviderMetric(
      'الاجتماعات المؤكدة',
      _integer(details['confirmedMeetings']),
    ),
    _ProviderMetric('المبيعات المؤكدة', _integer(details['confirmedSales'])),
    _ProviderMetric('هدف الاجتماعات', _integer(details['target'])),
    _ProviderMetric('التحويل', _percent(details['conversion'])),
    _ProviderMetric('تحقيق الهدف', _percent(details['achieved'])),
    _ProviderMetric('الإغلاق', _percent(details['vsMeetings'])),
    _ProviderMetric('نتيجة KPI', _percent(details['finalKpi'])),
  ];
}

class _ProviderMetric {
  final String label;
  final String value;

  const _ProviderMetric(this.label, this.value);
}

class _ProviderMetricTile extends StatelessWidget {
  final _ProviderMetric metric;

  const _ProviderMetricTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface02,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            metric.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 5),
          Directionality(
            textDirection: ui.TextDirection.ltr,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                metric.value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiScore extends StatelessWidget {
  final double value;
  final Color color;

  const _KpiScore({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Directionality(
        textDirection: ui.TextDirection.ltr,
        child: Text(
          '${value.toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AchievementBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _AchievementBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Directionality(
              textDirection: ui.TextDirection.ltr,
              child: Text(
                '${value.toStringAsFixed(1)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
            const Spacer(),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: (value / 100).clamp(0, 1),
          minHeight: 7,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: ZaWolfColors.surface03,
          color: color,
        ),
      ],
    );
  }
}

double _number(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;

double _percentValue(dynamic raw) {
  // Provider details are normalized to percentage points by the backend.
  return _number(raw);
}

String _integer(dynamic value) =>
    NumberFormat.decimalPattern('en_US').format(_number(value).round());

String _money(dynamic value) => NumberFormat.currency(
  locale: 'en_US',
  symbol: 'SAR ',
  decimalDigits: 0,
).format(_number(value));

String _percent(dynamic value) => '${_percentValue(value).toStringAsFixed(1)}%';
