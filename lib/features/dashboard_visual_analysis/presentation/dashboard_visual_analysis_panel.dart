import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../components/attendance_insights_card.dart';
import '../../../components/wolf_card.dart';
import '../../../design_system/components/rtl_navigation.dart';
import '../../../design_system/tokens.dart';
import '../../../theme/theme.dart';
import '../domain/dashboard_visual_analysis.dart';
import 'dashboard_visual_analysis_cubit.dart';

class DashboardVisualAnalysisPanel extends StatelessWidget {
  const DashboardVisualAnalysisPanel({
    super.key,
    required this.requestTotals,
    required this.attendanceRoute,
    required this.requestsRoute,
    required this.tasksRoute,
    this.onRefresh,
  });

  final DashboardRequestTotals requestTotals;
  final String attendanceRoute;
  final String requestsRoute;
  final String tasksRoute;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) => BlocBuilder<DashboardVisualAnalysisCubit, DashboardVisualAnalysisState>(
    builder: (context, state) {
      final analysis = state.analysis;
      if (analysis == null && state.isLoading) {
        return const WolfCard(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan))));
      }
      if (analysis == null) {
        return WolfCard(
          child: Column(children: [
            const Icon(Icons.cloud_off_outlined, color: ZaWolfColors.warning),
            const SizedBox(height: 8),
            const Text('تعذر تحميل التحليل الآن.', textDirection: TextDirection.rtl),
            TextButton(onPressed: () => context.read<DashboardVisualAnalysisCubit>().refresh(), child: const Text('إعادة المحاولة')),
          ]),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.isRefreshing) const LinearProgressIndicator(minHeight: 2, color: ZaWolfColors.primaryCyan),
          AttendanceInsightsCard(
            summary: analysis.today,
            onRefresh: () async { await context.read<DashboardVisualAnalysisCubit>().refresh(); await onRefresh?.call(); },
            onTap: () => context.go(attendanceRoute),
            onCategoryTap: (status) => context.go(_attendanceUrl(status: status, date: analysis.today.date)),
          ),
          const SizedBox(height: DsSpacing.lg),
          _periodAndTrend(context, analysis),
          const SizedBox(height: DsSpacing.lg),
          _actionPanel(context, analysis),
          if (analysis.departments.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.lg),
            _departmentPanel(context, analysis),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 8),
            const Text('تم عرض آخر بيانات متاحة؛ تعذر تحديث التحليل.', textDirection: TextDirection.rtl, textAlign: TextAlign.right, style: TextStyle(color: ZaWolfColors.warning)),
          ],
        ],
      );
    },
  );

  Widget _periodAndTrend(BuildContext context, DashboardVisualAnalysis analysis) => WolfCard(
    padding: const EdgeInsets.all(DsSpacing.lg),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('اتجاه الحضور', textAlign: TextAlign.right, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
        Icon(Icons.show_chart_rounded, color: ZaWolfColors.primaryCyan),
      ]),
      const SizedBox(height: 4),
      Text('${DateFormat('yyyy/MM/dd').format(analysis.period.start)} — ${DateFormat('yyyy/MM/dd').format(analysis.period.end)}', textDirection: TextDirection.rtl, textAlign: TextAlign.right, style: const TextStyle(color: ZaWolfColors.textSecondary)),
      const SizedBox(height: 12),
      Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
        _periodChip(context, '7 أيام', DashboardPeriodKind.sevenDays),
        _periodChip(context, '30 يوم', DashboardPeriodKind.thirtyDays),
        ActionChip(label: const Text('تاريخ مخصص'), avatar: const Icon(Icons.date_range_outlined, size: 18), onPressed: () => _chooseCustomPeriod(context)),
      ]),
      const SizedBox(height: 18),
      SizedBox(height: 122, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final point in analysis.trend) Expanded(child: _trendPoint(context, point)),
      ])),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(DateFormat('d MMM', 'ar').format(analysis.period.start), style: const TextStyle(color: ZaWolfColors.textMuted, fontSize: 11)),
        Text(DateFormat('d MMM', 'ar').format(analysis.period.end), style: const TextStyle(color: ZaWolfColors.textMuted, fontSize: 11)),
      ]),
    ]),
  );

  Widget _trendPoint(BuildContext context, dynamic point) {
    final percent = point.totalEmployees == 0 ? 0.0 : point.attended / point.totalEmployees;
    return InkWell(
      onTap: () => context.go(_attendanceUrl(status: 'all', date: point.date)),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Align(alignment: Alignment.bottomCenter, child: Container(height: (18 + percent * 82).toDouble(), decoration: BoxDecoration(color: percent >= .8 ? ZaWolfColors.success : percent >= .55 ? ZaWolfColors.warning : ZaWolfColors.error, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))))),
      ),
    );
  }

  Widget _periodChip(BuildContext context, String label, DashboardPeriodKind kind) {
    final selected = context.select((DashboardVisualAnalysisCubit cubit) => cubit.state.period.kind == kind);
    return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => context.read<DashboardVisualAnalysisCubit>().selectPeriod(kind == DashboardPeriodKind.sevenDays ? DashboardPeriod.sevenDays() : DashboardPeriod.thirtyDays()));
  }

  Future<void> _chooseCustomPeriod(BuildContext context) async {
    final current = context.read<DashboardVisualAnalysisCubit>().state.period;
    final range = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now(), initialDateRange: DateTimeRange(start: current.start, end: current.end));
    if (range == null || !context.mounted) return;
    try {
      await context.read<DashboardVisualAnalysisCubit>().selectPeriod(DashboardPeriod.custom(range.start, range.end));
    } on ArgumentError {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الفترة المخصصة لا تتجاوز 31 يوماً.')));
    }
  }

  Widget _actionPanel(BuildContext context, DashboardVisualAnalysis analysis) => WolfCard(
    padding: const EdgeInsets.all(DsSpacing.lg),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('إجراءات تحتاج قرارك', textDirection: TextDirection.rtl, textAlign: TextAlign.right, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 14),
      Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: [
        for (final item in requestTotals.byCategory.entries.where((item) => item.value > 0)) _actionTile(context, _arabicRequest(item.key), item.value, Icons.pending_actions_outlined, ZaWolfColors.warning, () => context.go('$requestsRoute?category=${item.key}&smart=true')),
        _actionTile(context, 'مهام جديدة', analysis.tasks.newTasks, Icons.fiber_new_outlined, ZaWolfColors.primaryCyan, () => context.go(tasksRoute)),
        _actionTile(context, 'مهام متأخرة', analysis.tasks.late, Icons.warning_amber_rounded, ZaWolfColors.error, () => context.go(tasksRoute)),
        _actionTile(context, 'قيد التنفيذ', analysis.tasks.inProgress, Icons.timelapse_outlined, ZaWolfColors.permissionTeal, () => context.go(tasksRoute)),
      ]),
      if (requestTotals.total == 0 && analysis.tasks.requiringAttention == 0) const Padding(padding: EdgeInsets.only(top: 8), child: Text('لا توجد إجراءات معلقة تحتاج قرارك الآن.', textDirection: TextDirection.rtl, textAlign: TextAlign.right, style: TextStyle(color: ZaWolfColors.textSecondary))),
    ]),
  );

  Widget _actionTile(BuildContext context, String label, int count, IconData icon, Color color, VoidCallback onTap) => SizedBox(width: 164, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: .08), border: Border.all(color: color.withValues(alpha: .32)), borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(icon, color: color), const Spacer(), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22)), Text(label, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12))])]))));

  Widget _departmentPanel(BuildContext context, DashboardVisualAnalysis analysis) => WolfCard(
    padding: const EdgeInsets.all(DsSpacing.lg),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('مقارنة الأقسام اليوم', textDirection: TextDirection.rtl, textAlign: TextAlign.right, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      for (final department in analysis.departments.take(8)) ListTile(
        onTap: () => context.go('${_attendanceUrl(status: 'all', date: analysis.today.date)}&department=${Uri.encodeQueryComponent(department.department)}'),
        title: Text(department.department, textDirection: TextDirection.rtl, textAlign: TextAlign.right),
        subtitle: Text('حضور ${department.summary.attended} من ${department.summary.totalEmployees}', textDirection: TextDirection.rtl, textAlign: TextAlign.right),
        leading: Text('${(department.summary.percentOf(department.summary.attended)).round()}%', style: const TextStyle(color: ZaWolfColors.primaryCyan, fontWeight: FontWeight.bold)),
        trailing: Icon(RtlNavigation.chevronEnd(context), color: ZaWolfColors.primaryCyan),
      ),
    ]),
  );

  String _attendanceUrl({String? status, required DateTime date}) => '$attendanceRoute?date=${DateFormat('yyyy-MM-dd').format(date)}${status == null ? '' : '&status=$status'}';
  String _arabicRequest(String category) => switch (category) {'leaves' => 'إجازات معلقة', 'permissions' => 'أذونات معلقة', 'advances' => 'سلف معلقة', 'administrative' => 'طلبات إدارية', 'resignations' => 'استقالات', _ => 'طلبات معلقة'};
}
