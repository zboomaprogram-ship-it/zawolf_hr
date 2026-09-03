import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/kpi_model.dart';
import '../models/sales_kpi_summary.dart';
import '../theme/theme.dart';

class DynamicKpiMetric {
  final String label;
  final String value;
  final bool isHighlight;

  const DynamicKpiMetric({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });
}

class DynamicKpiProgressBar {
  final String label;
  final double value;
  final Color color;

  const DynamicKpiProgressBar({
    required this.label,
    required this.value,
    this.color = ZaWolfColors.perfGold,
  });
}

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
    return _SalesKpiMetricsContent(
      details: kpi.providerDetails,
      departmentName: kpi.department.isNotEmpty ? kpi.department : (kpi.providerDepartment == 'tele_sales' ? 'المبيعات الهاتفية' : 'المبيعات'),
      isTeleSales:
          kpi.providerDepartment == 'tele_sales' ||
          kpi.providerDetails['kind'] == 'tele_sales',
      employeeName: kpi.employeeName,
      employeeCode: kpi.employeeId,
      compact: compact,
    );
  }
}

class SalesKpiAgentDetailsPanel extends StatelessWidget {
  final SalesKpiAgentSummary agent;
  final bool compact;

  const SalesKpiAgentDetailsPanel({
    super.key,
    required this.agent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return _SalesKpiMetricsContent(
      details: agent.providerDetails,
      departmentName: agent.kind == 'tele_sales' ? 'المبيعات الهاتفية' : 'المبيعات',
      isTeleSales: agent.kind == 'tele_sales',
      employeeName: agent.mappedEmployeeName.isNotEmpty
          ? agent.mappedEmployeeName
          : agent.name,
      employeeCode: agent.mappedEmployeeId,
      compact: compact,
    );
  }
}

class _SalesKpiMetricsContent extends StatelessWidget {
  final Map<String, dynamic> details;
  final String departmentName;
  final bool isTeleSales;
  final String employeeName;
  final String employeeCode;
  final bool compact;

  const _SalesKpiMetricsContent({
    required this.details,
    required this.departmentName,
    required this.isTeleSales,
    required this.employeeName,
    this.employeeCode = '',
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = _extractMetrics(details, isTeleSales);
    final progressBars = _extractProgressBars(details, isTeleSales);
    final progress = _percentValue(details['finalKpi'] ?? details['kpiScore'] ?? details['overallScore']);
    final accent = isTeleSales
        ? ZaWolfColors.primaryCyan
        : ZaWolfColors.perfGold;

    return Container(
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(10),
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
                    departmentName,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    employeeCode.isEmpty
                        ? employeeName
                        : '$employeeName · $employeeCode',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ZaWolfColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Icon(
                isTeleSales
                    ? Icons.support_agent_outlined
                    : Icons.payments_outlined,
                color: accent,
                size: 26,
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
          if (progressBars.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...progressBars.map(
              (bar) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AchievementBar(
                  label: bar.label,
                  value: bar.value,
                  color: bar.color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<DynamicKpiMetric> _extractMetrics(Map<String, dynamic> details, bool isTele) {
    // 1. If explicit custom dynamic metrics exist from another department system, use them directly!
    if (details['customMetrics'] is List) {
      final list = details['customMetrics'] as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map((m) => DynamicKpiMetric(
                label: '${m['label'] ?? m['title'] ?? ''}',
                value: '${m['value'] ?? ''}',
              ))
          .where((m) => m.label.isNotEmpty)
          .toList();
    }

    // 2. Standard TeleSales or Sales metrics
    if (isTele) {
      return [
        DynamicKpiMetric(label: 'العملاء المحتملون', value: _integer(details['totalLeads'])),
        DynamicKpiMetric(label: 'الاجتماعات المؤكدة', value: _integer(details['confirmedMeetings'])),
        DynamicKpiMetric(label: 'المبيعات المؤكدة', value: _integer(details['confirmedSales'])),
        DynamicKpiMetric(label: 'هدف الاجتماعات', value: _integer(details['target'])),
        DynamicKpiMetric(label: 'التحويل', value: _percent(details['conversion'])),
        DynamicKpiMetric(label: 'تحقيق الهدف', value: _percent(details['achieved'])),
        DynamicKpiMetric(label: 'الإغلاق', value: _percent(details['vsMeetings'])),
        DynamicKpiMetric(label: 'نتيجة KPI', value: _percent(details['finalKpi'])),
      ];
    }

    return [
      DynamicKpiMetric(label: 'قيمة المبيعات', value: _money(details['totalPrice'])),
      DynamicKpiMetric(label: 'الاجتماعات', value: _integer(details['meetings'])),
      DynamicKpiMetric(label: 'المبيعات المؤكدة', value: _integer(details['confirmedSales'])),
      DynamicKpiMetric(label: 'الهدف', value: _money(details['target'])),
      DynamicKpiMetric(label: 'الدخل الشهري', value: _money(details['monthlyIncome'])),
      DynamicKpiMetric(label: 'الدفعة المقدمة', value: _money(details['downPayment'])),
      DynamicKpiMetric(label: 'نتيجة KPI', value: _percent(details['finalKpi'])),
      DynamicKpiMetric(label: 'التحويل', value: _percent(details['conversion'])),
    ];
  }

  List<DynamicKpiProgressBar> _extractProgressBars(Map<String, dynamic> details, bool isTele) {
    if (details['customProgressBars'] is List) {
      final list = details['customProgressBars'] as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map((b) => DynamicKpiProgressBar(
                label: '${b['label'] ?? ''}',
                value: _percentValue(b['value']),
                color: b['color'] == 'cyan' ? ZaWolfColors.primaryCyan : ZaWolfColors.perfGold,
              ))
          .toList();
    }

    if (isTele) {
      return [
        DynamicKpiProgressBar(
          label: 'تحقيق هدف الاجتماعات',
          value: _percentValue(details['achieved']),
          color: ZaWolfColors.perfGold,
        ),
        DynamicKpiProgressBar(
          label: 'نسبة الإغلاق',
          value: _percentValue(details['vsMeetings']),
          color: ZaWolfColors.primaryCyan,
        ),
      ];
    }

    return [
      DynamicKpiProgressBar(
        label: 'تحقيق هدف الفواتير',
        value: _percentValue(details['invoiceAchievement']),
        color: ZaWolfColors.perfGold,
      ),
      DynamicKpiProgressBar(
        label: 'تحويل المبيعات',
        value: _percentValue(details['conversion']),
        color: ZaWolfColors.primaryCyan,
      ),
    ];
  }
}

class _ProviderMetricTile extends StatelessWidget {
  final DynamicKpiMetric metric;

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
