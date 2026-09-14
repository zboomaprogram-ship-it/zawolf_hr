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
  Widget build(
    BuildContext context,
  ) => BlocBuilder<DashboardVisualAnalysisCubit, DashboardVisualAnalysisState>(
    builder: (context, state) {
      final analysis = state.analysis;
      if (analysis == null && state.isLoading) {
        return const WolfCard(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            ),
          ),
        );
      }
      if (analysis == null) {
        return WolfCard(
          child: Column(
            children: [
              const Icon(Icons.cloud_off_outlined, color: ZaWolfColors.warning),
              const SizedBox(height: 8),
              const Text(
                'تعذر تحميل التحليل الآن.',
                textDirection: TextDirection.rtl,
              ),
              TextButton(
                onPressed:
                    () =>
                        context.read<DashboardVisualAnalysisCubit>().refresh(),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.isRefreshing)
            const LinearProgressIndicator(
              minHeight: 2,
              color: ZaWolfColors.primaryCyan,
            ),
          AttendanceInsightsCard(
            summary: analysis.today,
            onRefresh: () async {
              await context.read<DashboardVisualAnalysisCubit>().refresh();
              await onRefresh?.call();
            },
            onTap: () => context.go(attendanceRoute),
            onCategoryTap:
                (status) => context.go(
                  _attendanceUrl(status: status, date: analysis.today.date),
                ),
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
            const Text(
              'تم عرض آخر بيانات متاحة؛ تعذر تحديث التحليل.',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(color: ZaWolfColors.warning),
            ),
          ],
        ],
      );
    },
  );

  Widget _periodAndTrend(
    BuildContext context,
    DashboardVisualAnalysis analysis,
  ) => WolfCard(
    padding: const EdgeInsets.all(DsSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'اتجاه الحضور',
                textAlign: TextAlign.right,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Icon(Icons.show_chart_rounded, color: ZaWolfColors.primaryCyan),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${DateFormat('yyyy/MM/dd').format(analysis.period.start)} — ${DateFormat('yyyy/MM/dd').format(analysis.period.end)}',
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          style: const TextStyle(color: ZaWolfColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          children: [
            _periodChip(context, '7 أيام', DashboardPeriodKind.sevenDays),
            _periodChip(context, '30 يوم', DashboardPeriodKind.thirtyDays),
            ActionChip(
              label: const Text('تاريخ مخصص'),
              avatar: const Icon(Icons.date_range_outlined, size: 18),
              onPressed: () => _chooseCustomPeriod(context),
            ),
          ],
        ),
        const SizedBox(height: 14),
        InteractiveAttendanceTrendChart(
          trend: analysis.trend,
          onDateSelected: (date) => context.go(_attendanceUrl(status: 'all', date: date)),
        ),
      ],
    ),
  );

  Widget _periodChip(
    BuildContext context,
    String label,
    DashboardPeriodKind kind,
  ) {
    final selected = context.select(
      (DashboardVisualAnalysisCubit cubit) => cubit.state.period.kind == kind,
    );
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected:
          (_) => context.read<DashboardVisualAnalysisCubit>().selectPeriod(
            kind == DashboardPeriodKind.sevenDays
                ? DashboardPeriod.sevenDays()
                : DashboardPeriod.thirtyDays(),
          ),
    );
  }

  Future<void> _chooseCustomPeriod(BuildContext context) async {
    final current = context.read<DashboardVisualAnalysisCubit>().state.period;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: current.start, end: current.end),
    );
    if (range == null || !context.mounted) return;
    try {
      await context.read<DashboardVisualAnalysisCubit>().selectPeriod(
        DashboardPeriod.custom(range.start, range.end),
      );
    } on ArgumentError {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الفترة المخصصة لا تتجاوز 31 يوماً.')),
        );
      }
    }
  }

  Widget _actionPanel(BuildContext context, DashboardVisualAnalysis analysis) =>
      WolfCard(
        padding: const EdgeInsets.all(DsSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'إجراءات تحتاج قرارك',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in requestTotals.byCategory.entries.where(
                  (item) => item.value > 0,
                ))
                  _actionTile(
                    context,
                    _arabicRequest(item.key),
                    item.value,
                    Icons.pending_actions_outlined,
                    ZaWolfColors.warning,
                    () => context.go(
                      '$requestsRoute?category=${item.key}&smart=true',
                    ),
                  ),
                _actionTile(
                  context,
                  'مهام جديدة',
                  analysis.tasks.newTasks,
                  Icons.fiber_new_outlined,
                  ZaWolfColors.primaryCyan,
                  () => context.go(tasksRoute),
                ),
                _actionTile(
                  context,
                  'مهام متأخرة',
                  analysis.tasks.late,
                  Icons.warning_amber_rounded,
                  ZaWolfColors.error,
                  () => context.go(tasksRoute),
                ),
                _actionTile(
                  context,
                  'قيد التنفيذ',
                  analysis.tasks.inProgress,
                  Icons.timelapse_outlined,
                  ZaWolfColors.permissionTeal,
                  () => context.go(tasksRoute),
                ),
              ],
            ),
            if (requestTotals.total == 0 &&
                analysis.tasks.requiringAttention == 0)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'لا توجد إجراءات معلقة تحتاج قرارك الآن.',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: ZaWolfColors.textSecondary),
                ),
              ),
          ],
        ),
      );

  Widget _actionTile(
    BuildContext context,
    String label,
    int count,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => SizedBox(
    width: 164,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          border: Border.all(color: color.withValues(alpha: .32)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                Text(
                  label,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _departmentPanel(
    BuildContext context,
    DashboardVisualAnalysis analysis,
  ) => WolfCard(
    padding: const EdgeInsets.all(DsSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'مقارنة الأقسام اليوم',
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        for (final department in analysis.departments.take(8))
          ListTile(
            onTap:
                () => context.go(
                  '${_attendanceUrl(status: 'all', date: analysis.today.date)}&department=${Uri.encodeQueryComponent(department.department)}',
                ),
            title: Text(
              department.department,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
            ),
            subtitle: Text(
              'حضور ${department.summary.attended} من ${department.summary.totalEmployees}',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
            ),
            leading: Text(
              '${(department.summary.percentOf(department.summary.attended)).round()}%',
              style: const TextStyle(
                color: ZaWolfColors.primaryCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Icon(
              RtlNavigation.chevronEnd(context),
              color: ZaWolfColors.primaryCyan,
            ),
          ),
      ],
    ),
  );

  String _attendanceUrl({String? status, required DateTime date}) =>
      '$attendanceRoute?date=${DateFormat('yyyy-MM-dd').format(date)}${status == null ? '' : '&status=$status'}';
  String _arabicRequest(String category) => switch (category) {
    'leaves' => 'إجازات معلقة',
    'permissions' => 'أذونات معلقة',
    'advances' => 'سلف معلقة',
    'administrative' => 'طلبات إدارية',
    'resignations' => 'استقالات',
    _ => 'طلبات معلقة',
  };
}

class InteractiveAttendanceTrendChart extends StatefulWidget {
  const InteractiveAttendanceTrendChart({
    super.key,
    required this.trend,
    required this.onDateSelected,
  });

  final List<DashboardAttendanceSummary> trend;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<InteractiveAttendanceTrendChart> createState() =>
      _InteractiveAttendanceTrendChartState();
}

class _InteractiveAttendanceTrendChartState
    extends State<InteractiveAttendanceTrendChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    // Filter out Fridays (weekend off days) or days where no employees were scheduled/present
    final validPoints = widget.trend.where((p) {
      if (p.date.weekday == DateTime.friday) return false;
      return true;
    }).toList();

    if (validPoints.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'لا توجد بيانات حضور للفترة المحددة (تم استثناء العطلات الأسبوعية)',
            style: TextStyle(color: ZaWolfColors.textMuted, fontSize: 12),
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }

    final selectedPoint =
        _hoveredIndex != null && _hoveredIndex! < validPoints.length
            ? validPoints[_hoveredIndex!]
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Interactive Details Banner / Tooltip
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: selectedPoint != null
              ? Container(
                  key: ValueKey(selectedPoint.date),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: ZaWolfColors.surface02,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ZaWolfColors.primaryCyan.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: ZaWolfColors.primaryCyan,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEEE d MMMM yyyy', 'ar').format(selectedPoint.date),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _badge('حاضر: ${selectedPoint.attended}', ZaWolfColors.success),
                          const SizedBox(width: 6),
                          if (selectedPoint.late > 0) ...[
                            _badge('متأخر: ${selectedPoint.late}', ZaWolfColors.warning),
                            const SizedBox(width: 6),
                          ],
                          _badge(
                            'الإجمالي: ${selectedPoint.totalEmployees}',
                            ZaWolfColors.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Chart with Y-Axis and Interactive Dots
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Y-Axis Titles (0%, 50%, 100%)
              SizedBox(
                width: 40,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '100%',
                      style: TextStyle(color: ZaWolfColors.textMuted, fontSize: 10),
                    ),
                    Text(
                      '50%',
                      style: TextStyle(color: ZaWolfColors.textMuted, fontSize: 10),
                    ),
                    Text(
                      '0%',
                      style: TextStyle(color: ZaWolfColors.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),

              // Canvas and Touch Area
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final ratios = validPoints.map((p) {
                      if (p.totalEmployees == 0) return 0.0;
                      return (p.attended / p.totalEmployees).clamp(0.0, 1.0);
                    }).toList();

                    return Stack(
                      children: [
                        // Trend line & fill painting
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _EnhancedTrendPainter(
                              values: ratios,
                              selectedIndex: _hoveredIndex,
                            ),
                          ),
                        ),

                        // Interactive touch overlays for each point
                        Row(
                          children: [
                            for (var i = 0; i < validPoints.length; i++)
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _hoveredIndex = i);
                                    widget.onDateSelected(validPoints[i].date);
                                  },
                                  onHover: (hovering) {
                                    if (hovering) {
                                      setState(() => _hoveredIndex = i);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // X-Axis Date & Day Labels
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < validPoints.length; i++)
                if (validPoints.length <= 10 ||
                    i == 0 ||
                    i == validPoints.length - 1 ||
                    i == (validPoints.length / 2).floor())
                  Text(
                    DateFormat('E d', 'ar').format(validPoints[i].date),
                    style: TextStyle(
                      color: _hoveredIndex == i
                          ? ZaWolfColors.primaryCyan
                          : ZaWolfColors.textMuted,
                      fontSize: 11,
                      fontWeight: _hoveredIndex == i
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _EnhancedTrendPainter extends CustomPainter {
  const _EnhancedTrendPainter({
    required this.values,
    this.selectedIndex,
  });

  final List<double> values;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final gridPaint = Paint()
      ..color = ZaWolfColors.surface03.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    // 3 Horizontal guideline levels (100%, 50%, 0%)
    for (var i = 0; i <= 2; i++) {
      final y = 14.0 + (size.height - 28.0) * (i / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          values.length == 1
              ? size.width / 2
              : size.width * i / (values.length - 1),
          size.height - 14 - values[i] * (size.height - 28),
        ),
    ];

    // Shaded gradient fill under curve
    final fill = Path()
      ..moveTo(points.first.dx, size.height - 14)
      ..lineTo(points.first.dx, points.first.dy);
    final line = Path()..moveTo(points.first.dx, points.first.dy);

    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
      fill.lineTo(point.dx, point.dy);
    }

    fill
      ..lineTo(points.last.dx, size.height - 14)
      ..close();

    canvas.drawPath(
      fill,
      Paint()..color = ZaWolfColors.primaryCyan.withValues(alpha: 0.15),
    );

    // Main line
    canvas.drawPath(
      line,
      Paint()
        ..color = ZaWolfColors.primaryCyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Draw dots
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final isSelected = selectedIndex == i;

      if (isSelected) {
        // Highlight indicator
        canvas.drawCircle(
          point,
          7,
          Paint()..color = ZaWolfColors.primaryCyan.withValues(alpha: 0.3),
        );
        canvas.drawCircle(point, 5.5, Paint()..color = Colors.white);
        canvas.drawCircle(point, 3.5, Paint()..color = ZaWolfColors.primaryCyan);
      } else {
        canvas.drawCircle(point, 4.5, Paint()..color = ZaWolfColors.surface01);
        canvas.drawCircle(point, 3, Paint()..color = ZaWolfColors.primaryCyan);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EnhancedTrendPainter old) =>
      old.values.toString() != values.toString() ||
      old.selectedIndex != selectedIndex;
}
