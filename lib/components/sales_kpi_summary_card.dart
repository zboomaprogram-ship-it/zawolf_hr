import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/sales_kpi_summary.dart';
import '../theme/theme.dart';
import 'sales_kpi_details_panel.dart';
import 'wolf_card.dart';

class SalesKpiSummaryCard extends StatelessWidget {
  final SalesKpiSummary summary;
  final List<SalesKpiSummary> history;
  final ValueChanged<SalesKpiSummary>? onPeriodChanged;
  final VoidCallback? onEditPeriod;

  const SalesKpiSummaryCard({
    super.key,
    required this.summary,
    this.history = const [],
    this.onPeriodChanged,
    this.onEditPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = NumberFormat.compactCurrency(
      locale: 'en_US',
      symbol: '${summary.currency} ',
      decimalDigits: 0,
    );
    final synced = summary.syncedAt == null
        ? 'لم تتم المزامنة بعد'
        : DateFormat('yyyy/MM/dd - HH:mm').format(summary.syncedAt!.toLocal());

    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.sync, color: ZaWolfColors.textMuted, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'آخر تحديث: $synced',
                  style: theme.textTheme.bodySmall,
                  textDirection: ui.TextDirection.rtl,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.analytics_outlined,
                color: ZaWolfColors.primaryCyan,
              ),
              const SizedBox(width: 8),
              Text(
                'مؤشرات المبيعات',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (onEditPeriod != null)
                IconButton(
                  tooltip: 'تعديل فترة KPI',
                  onPressed: onEditPeriod,
                  icon: const Icon(
                    Icons.edit_calendar_outlined,
                    color: ZaWolfColors.primaryCyan,
                  ),
                ),
              const Spacer(),
              if (history.length > 1)
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: summary.periodKey,
                    dropdownColor: ZaWolfColors.surface02,
                    items: history
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.periodKey,
                            child: Text(item.periodKey),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      onPeriodChanged?.call(
                        history.firstWhere((item) => item.periodKey == value),
                      );
                    },
                  ),
                ),
              const SizedBox(width: 12),
              Text(
                '${summary.periodStart} إلى ${summary.periodEnd}',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final panels = [
                _TargetProgressPanel(
                  title: 'المبيعات',
                  icon: Icons.payments_outlined,
                  actual: summary.effectiveSalesActual,
                  target: summary.effectiveSalesTarget,
                  unit: summary.currency,
                  employees: summary.effectiveSalesMappedEmployees,
                  availableAgents: summary.availableSalesAgents,
                  averageKpi: summary.salesAverageKpi,
                  color: ZaWolfColors.perfGold,
                ),
                _TargetProgressPanel(
                  title: 'المبيعات الهاتفية',
                  icon: Icons.support_agent_outlined,
                  actual: summary.effectiveTeleSalesActual,
                  target: summary.effectiveTeleSalesTarget,
                  unit: 'اجتماع',
                  employees: summary.effectiveTeleSalesMappedEmployees,
                  availableAgents: summary.availableTeleSalesAgents,
                  averageKpi: summary.teleSalesAverageKpi,
                  color: ZaWolfColors.primaryCyan,
                ),
              ];
              if (constraints.maxWidth >= 700) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: panels[0]),
                    const SizedBox(width: 12),
                    Expanded(child: panels[1]),
                  ],
                );
              }
              return Column(
                children: [panels[0], const SizedBox(height: 12), panels[1]],
              );
            },
          ),
          if (history.length > 1) ...[
            const SizedBox(height: 16),
            _PeriodHistoryChart(history: history),
          ],
          if (summary.agents.where((a) => a.isMapped).isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'أداء الموظفين من نظام المبيعات',
              textAlign: TextAlign.right,
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 10),
            ...summary.agents.where((a) => a.isMapped).map(
              (agent) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AgentSummaryTile(
                  agent: agent,
                  currency: summary.currency,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 520
                  ? 3
                  : 2;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 10)) / columns;
              final entries = <({String label, String value, Color color})>[
                (
                  label: 'العملاء المحتملون',
                  value: NumberFormat.decimalPattern(
                    'en_US',
                  ).format(summary.totalLeads),
                  color: ZaWolfColors.primaryCyan,
                ),
                (
                  label: 'الاجتماعات المؤكدة',
                  value: NumberFormat.decimalPattern(
                    'en_US',
                  ).format(summary.confirmedMeetings),
                  color: ZaWolfColors.warning,
                ),
                (
                  label: 'الإغلاقات',
                  value: NumberFormat.decimalPattern(
                    'en_US',
                  ).format(summary.closings),
                  color: ZaWolfColors.success,
                ),
                (
                  label: 'العملاء الدافعون',
                  value: NumberFormat.decimalPattern(
                    'en_US',
                  ).format(summary.paidCustomers),
                  color: ZaWolfColors.success,
                ),
                (
                  label: 'قيمة المبيعات',
                  value: money.format(summary.totalPrice),
                  color: ZaWolfColors.perfGold,
                ),
                (
                  label: 'تحويل المبيعات',
                  value: _percent(summary.salesConversionRate),
                  color: ZaWolfColors.primaryCyan,
                ),
                (
                  label: 'تحويل الهاتف',
                  value: _percent(summary.teleConversionRate),
                  color: ZaWolfColors.primaryCyan,
                ),
                (
                  label: 'الموظفون المرتبطون',
                  value: NumberFormat.decimalPattern(
                    'en_US',
                  ).format(summary.effectiveMappedEmployees),
                  color: summary.unmatchedEmployees > 0
                      ? ZaWolfColors.warning
                      : ZaWolfColors.success,
                ),
              ];
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: entries
                    .map(
                      (entry) => SizedBox(
                        width: width,
                        child: _MetricTile(
                          label: entry.label,
                          value: entry.value,
                          color: entry.color,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          if (summary.unmatchedEmployees > 0) ...[
            const SizedBox(height: 12),
            Text(
              'يوجد ${summary.unmatchedEmployees} موظف مفعّل لم تتم مطابقته مع بيانات المبيعات.',
              textAlign: TextAlign.right,
              textDirection: ui.TextDirection.rtl,
              style: theme.textTheme.bodySmall?.copyWith(
                color: ZaWolfColors.warning,
              ),
            ),
          ],
          if (summary.apiAgentCount > 0 &&
              !summary.apiIdentityMappingReady) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ZaWolfColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ZaWolfColors.warning.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'بيانات الأقسام صحيحة، لكن ربط الموظفين متوقف لحمايتهم من المطابقة الخاطئة. '
                      'واجهة المبيعات أعادت ${summary.apiMissingAgentIdCount} من '
                      '${summary.apiAgentCount} صفوف بدون كود موظف ثابت. يجب أن يرسل المصدر idEmp لكل صف.',
                      textAlign: TextAlign.right,
                      textDirection: ui.TextDirection.rtl,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ZaWolfColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.link_off_outlined,
                    color: ZaWolfColors.warning,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _percent(double ratio) {
    final value = ratio.abs() <= 1 ? ratio * 100 : ratio;
    return '${value.toStringAsFixed(1)}%';
  }
}

class _PeriodHistoryChart extends StatelessWidget {
  final List<SalesKpiSummary> history;

  const _PeriodHistoryChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final periods = history.take(6).toList().reversed.toList();
    return Container(
      height: 230,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface02,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _LegendDot(color: ZaWolfColors.primaryCyan, label: 'تلي سيلز'),
              const SizedBox(width: 14),
              _LegendDot(color: ZaWolfColors.perfGold, label: 'المبيعات'),
              const Spacer(),
              Text(
                'اتجاه تحقيق الهدف',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: periods
                  .map(
                    (period) => Expanded(child: _PeriodBars(summary: period)),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodBars extends StatelessWidget {
  final SalesKpiSummary summary;

  const _PeriodBars({required this.summary});

  @override
  Widget build(BuildContext context) {
    double ratio(double actual, double target) =>
        target <= 0 ? 0 : (actual / target).clamp(0, 1.25);
    final salesTarget = summary.effectiveSalesTarget;
    final teleTarget = summary.effectiveTeleSalesTarget;
    final sales = ratio(summary.effectiveSalesActual, salesTarget);
    final tele = ratio(summary.effectiveTeleSalesActual, teleTarget);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _AchievementBar(ratio: sales, color: ZaWolfColors.perfGold),
              const SizedBox(width: 5),
              _AchievementBar(ratio: tele, color: ZaWolfColors.primaryCyan),
            ],
          ),
        ),
        const SizedBox(height: 7),
        Text(
          summary.periodKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _AchievementBar extends StatelessWidget {
  final double ratio;
  final Color color;

  const _AchievementBar({required this.ratio, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Tooltip(
        message: '${(ratio * 100).toStringAsFixed(0)}%',
        child: Container(
          width: 12,
          height: constraints.maxHeight * (ratio / 1.25),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _TargetProgressPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final double actual;
  final double target;
  final String unit;
  final int employees;
  final int availableAgents;
  final double averageKpi;
  final Color color;

  const _TargetProgressPanel({
    required this.title,
    required this.icon,
    required this.actual,
    required this.target,
    required this.unit,
    required this.employees,
    required this.availableAgents,
    required this.averageKpi,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = target <= 0 ? 0.0 : actual / target;
    final percent = ratio * 100;
    final formatter = NumberFormat.compact(locale: 'en_US');
    final state = percent >= 100
        ? 'متجاوز للهدف'
        : percent >= 85
        ? 'على المسار'
        : 'يحتاج متابعة';
    final stateColor = percent >= 100
        ? ZaWolfColors.success
        : percent >= 85
        ? color
        : ZaWolfColors.warning;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface02,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${percent.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: stateColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              Icon(icon, color: color),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: ratio.clamp(0, 1),
              backgroundColor: ZaWolfColors.surface03,
              color: stateColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${formatter.format(actual)} / ${formatter.format(target)} $unit',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '$state · متوسط KPI ${averageKpi.toStringAsFixed(1)}% · '
            '$employees مرتبط من $availableAgents',
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: stateColor),
          ),
        ],
      ),
    );
  }
}

class _AgentSummaryTile extends StatelessWidget {
  final SalesKpiAgentSummary agent;
  final String currency;

  const _AgentSummaryTile({required this.agent, required this.currency});

  @override
  Widget build(BuildContext context) {
    final color = agent.isMapped ? ZaWolfColors.success : ZaWolfColors.warning;
    final number = NumberFormat.compact(locale: 'en_US');
    final unit = agent.kind == 'sales' ? currency : 'اجتماع';
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: ZaWolfColors.background,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _AgentDetails(agent: agent),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ZaWolfColors.surface02,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZaWolfColors.surface03),
        ),
        child: Row(
          children: [
            Text(
              '${agent.finalKpi.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: ZaWolfColors.perfGold,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    agent.mappedEmployeeName.isNotEmpty
                        ? agent.mappedEmployeeName
                        : agent.name,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '${number.format(agent.actual)} / ${number.format(agent.target)} $unit '
                    '· ${agent.isMapped ? 'مرتبط' : 'غير مرتبط'} · ${agent.key}',
                    textAlign: TextAlign.right,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              agent.kind == 'sales'
                  ? Icons.payments_outlined
                  : Icons.support_agent,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentDetails extends StatelessWidget {
  final SalesKpiAgentSummary agent;

  const _AgentDetails({required this.agent});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SalesKpiAgentDetailsPanel(agent: agent),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface02,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
