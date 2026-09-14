import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../components/wolf_card.dart';
import '../../../theme/theme.dart';
import '../domain/hr_period_report.dart';
import 'hr_period_report_cubit.dart';

class HrPeriodReportPage extends StatelessWidget {
  const HrPeriodReportPage({super.key});
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('تقرير الموارد البشرية للفترة')),
      body: BlocBuilder<HrPeriodReportCubit, HrPeriodReportState>(
        builder: (context, state) {
          final report = state.report;
          return RefreshIndicator(
            onRefresh: () => context.read<HrPeriodReportCubit>().refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _filters(context, state),
                if (state.refreshing)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 16),
                if (state.loading && report == null) const _LoadingReport(),
                if (state.error != null)
                  _ErrorCard(
                    onRetry:
                        () => context.read<HrPeriodReportCubit>().refresh(),
                  ),
                if (report != null) ..._report(context, state, report),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _filters(BuildContext context, HrPeriodReportState state) => WolfCard(
    child: Wrap(
      alignment: WrapAlignment.start,
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('الفترة', style: Theme.of(context).textTheme.titleMedium),
        ChoiceChip(
          label: const Text('7 أيام'),
          selected: state.period.days == 7,
          onSelected:
              (_) => context.read<HrPeriodReportCubit>().selectPeriod(
                HrReportPeriod.sevenDays(),
              ),
        ),
        ChoiceChip(
          label: const Text('30 يوماً'),
          selected: state.period.days == 30,
          onSelected:
              (_) => context.read<HrPeriodReportCubit>().selectPeriod(
                HrReportPeriod.thirtyDays(),
              ),
        ),
        OutlinedButton.icon(
          onPressed: () => _chooseRange(context, state.period),
          icon: const Icon(Icons.date_range_outlined),
          label: Text(
            '${_date(state.period.start)} — ${_date(state.period.end)}',
          ),
        ),
        if (state.report != null)
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String?>(
              initialValue: state.employeeId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'الموظف',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('كل الموظفين'),
                ),
                ...state.report!.employees.map(
                  (employee) => DropdownMenuItem<String?>(
                    value: employee.id,
                    child: Text('${employee.name} · ${employee.code}'),
                  ),
                ),
              ],
              onChanged: context.read<HrPeriodReportCubit>().selectEmployee,
            ),
          ),
      ],
    ),
  );

  Future<void> _chooseRange(
    BuildContext context,
    HrReportPeriod current,
  ) async {
    final cubit = context.read<HrPeriodReportCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: current.start, end: current.end),
    );
    if (selected == null) return;
    try {
      await cubit.selectPeriod(
        HrReportPeriod.custom(selected.start, selected.end),
      );
    } on ArgumentError {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('الحد الأقصى للفترة المخصصة هو 31 يوماً.'),
        ),
      );
    }
  }

  List<Widget> _report(
    BuildContext context,
    HrPeriodReportState state,
    HrPeriodReport report,
  ) {
    final records = report.forEmployee(state.employeeId);
    int status(String value) =>
        records.where((item) => item.status == value).length;
    final scheduled = records.where((item) => item.status != 'day_off').length;
    final attended =
        status('present') +
        status('late') +
        status('permission') +
        status('field_mission');
    final deductions = report.deductionsForEmployee(state.employeeId);
    final requests = report.requestsForEmployee(state.employeeId);
    final approvedDeductions =
        deductions.where((item) => item.affectsDiscipline).toList();
    final leaveDays =
        records
            .where(
              (item) =>
                  item.status == 'day_off' &&
                  (item.statusDetail?.startsWith('إجازة') == true ||
                      item.statusDetail == 'عمل عن بعد'),
            )
            .length;
    final restDays = status('day_off') - leaveDays;
    return [
      Text('ملخص تحليلي', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _metric(
            'المجدول',
            '$scheduled',
            Icons.people_outline,
            ZaWolfColors.primaryCyan,
          ),
          _metric(
            'الحضور',
            '$attended',
            Icons.how_to_reg_outlined,
            ZaWolfColors.success,
          ),
          _metric(
            'التأخير',
            '${status('late')}',
            Icons.schedule_outlined,
            ZaWolfColors.warning,
          ),
          _metric(
            'غياب دون تسجيل',
            '${status('not_attended')}',
            Icons.person_off_outlined,
            ZaWolfColors.error,
          ),
          _metric(
            'إجازة معتمدة',
            '$leaveDays',
            Icons.event_available_outlined,
            ZaWolfColors.textSecondary,
          ),
          _metric(
            'راحة / يوم غير مجدول',
            '$restDays',
            Icons.weekend_outlined,
            ZaWolfColors.textSecondary,
          ),
          _metric(
            'كل الطلبات',
            '${requests.length}',
            Icons.description_outlined,
            ZaWolfColors.primaryCyan,
          ),
          _metric(
            'إجمالي الخصم المعتمد',
            _deductionTotal(approvedDeductions),
            Icons.payments_outlined,
            ZaWolfColors.error,
          ),
        ],
      ),
      const SizedBox(height: 18),
      WolfCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'اتجاه الحضور والتأخير',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'الحضور يشمل الحضور العادي والتأخير والمهمة الميدانية. الخصومات قيد المراجعة لا تؤثر على الانضباط.',
              style: TextStyle(color: ZaWolfColors.textSecondary),
            ),
            const SizedBox(height: 16),
            _InteractiveReportTrend(
              points: report.trendForEmployee(state.employeeId),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Text('السجل التفصيلي', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      ...records.map((record) => _recordCard(record)),
      if (records.isEmpty)
        const WolfCard(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('لا توجد سجلات ضمن النطاق والموظف المحددين.'),
          ),
        ),
      const SizedBox(height: 18),
      _requestsSection(requests),
      const SizedBox(height: 18),
      _deductionsSection(deductions),
      const SizedBox(height: 28),
      BlocListener<HrPeriodReportCubit, HrPeriodReportState>(
        listenWhen:
            (previous, current) =>
                previous.exportedResourceId != current.exportedResourceId &&
                current.exportedResourceId != null,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'تم إنشاء ملف Google Sheet. ستجده في مركز ملفات الشركة ضمن التقارير.',
              ),
            ),
          );
          context.go('/workspace');
        },
        child: WolfCard(
          child: ListTile(
            leading: const Icon(
              Icons.table_view_outlined,
              color: ZaWolfColors.primaryCyan,
            ),
            title: const Text('تصدير إلى Google Sheet'),
            subtitle: Text(
              state.employeeId == null
                  ? 'تصدير الحضور التفصيلي لكل الموظفين للفترة المحددة.'
                  : 'تصدير الحضور التفصيلي للموظف المحدد للفترة.',
            ),
            trailing:
                state.exporting
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.file_download_outlined),
            onTap:
                state.exporting
                    ? null
                    : () => context.read<HrPeriodReportCubit>().export(),
          ),
        ),
      ),
    ];
  }

  Widget _requestsSection(List<HrRequestRecord> requests) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'الطلبات خلال الفترة',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      if (requests.isEmpty)
        const WolfCard(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('لا توجد طلبات ضمن الفترة المحددة.'),
          ),
        ),
      ...requests.map(
        (request) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: WolfCard(
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text('${request.type} · ${request.employee.name}'),
              subtitle: Text(
                '${_date(request.date)}${request.endDate == null ? '' : ' إلى ${_date(request.endDate!)}'}${request.reason == null ? '' : ' · ${request.reason}'}',
              ),
              trailing: Chip(label: Text(_requestStatus(request.status))),
            ),
          ),
        ),
      ),
    ],
  );
  Widget _deductionsSection(List<HrDeductionRecord> deductions) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'خصومات الراتب خلال الفترة',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      if (deductions.isEmpty)
        const WolfCard(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('لا توجد خصومات مسجلة ضمن الفترة.'),
          ),
        ),
      ...deductions.map(
        (deduction) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: WolfCard(
            child: ExpansionTile(
              leading: const Icon(
                Icons.payments_outlined,
                color: ZaWolfColors.warning,
              ),
              title: Text('${deduction.reason} · ${deduction.employee.name}'),
              subtitle: Text(
                '${_date(deduction.date)} · ${deduction.source} · ${deduction.resolvedAmount().toStringAsFixed(2)} ${deduction.employee.salaryCurrency}${deduction.fraction > 0 ? ' · ${(deduction.fraction * 100).toStringAsFixed(0)}%' : ''}',
              ),
              trailing: Chip(
                label: Text(
                  deduction.affectsDiscipline ? 'معتمد' : 'قيد المراجعة',
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _detail('سبب الخصم', deduction.reason),
                if (deduction.detail?.isNotEmpty == true)
                  _detail('تفاصيل الواقعة', deduction.detail!),
                _detail(
                  'القيمة',
                  '${deduction.resolvedAmount().toStringAsFixed(2)} ${deduction.employee.salaryCurrency}',
                ),
                if (deduction.fraction > 0)
                  _detail(
                    'نسبة اليوم',
                    '${(deduction.fraction * 100).toStringAsFixed(0)}%',
                  ),
                _detail(
                  'الأثر على الانضباط',
                  deduction.affectsDiscipline
                      ? 'يؤثر لأنه معتمد'
                      : 'لا يؤثر قبل اعتماد HR',
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
  static String _requestStatus(String status) =>
      {
            'approved': 'مقبول',
            'pending': 'قيد المراجعة',
            'rejected': 'مرفوض',
            'cancelled': 'ملغي',
          }.containsKey(status)
          ? {
            'approved': 'مقبول',
            'pending': 'قيد المراجعة',
            'rejected': 'مرفوض',
            'cancelled': 'ملغي',
          }[status]!
          : status;

  Widget _metric(String label, String value, IconData icon, Color color) =>
      SizedBox(
        width: 155,
        child: WolfCard(
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(color: ZaWolfColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  Widget _recordCard(HrAttendanceRecord r) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: WolfCard(
      child: ExpansionTile(
        title: Text(
          '${r.statusDetail ?? _status(r.status)} · ${_date(r.date)}',
        ),
        subtitle: Text(
          '${r.employee.name} · ${r.employee.code} · ${r.employee.department}',
        ),
        trailing: _statusPill(r.status),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _detail(
            'الحضور',
            r.checkIn == null
                ? 'لم يسجل حضوراً'
                : DateFormat('hh:mm a', 'ar').format(r.checkIn!),
          ),
          _detail(
            'الانصراف',
            r.checkOut == null
                ? 'لم يسجل انصرافاً'
                : DateFormat('hh:mm a', 'ar').format(r.checkOut!),
          ),
          if (r.lateMinutes > 0) _detail('التأخير', '${r.lateMinutes} دقيقة'),
          if (r.deductionReason != null)
            _detail('سبب الخصم', r.deductionReason!),
          if (r.deductionStatus != null)
            _detail(
              'حالة الخصم',
              r.deductionStatus == 'approved'
                  ? 'معتمد ويؤثر على الانضباط'
                  : 'قيد مراجعة HR ولا يؤثر على الانضباط',
            ),
        ],
      ),
    ),
  );
  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: ZaWolfColors.textSecondary),
        ),
        Expanded(child: Text(value, textAlign: TextAlign.left)),
      ],
    ),
  );
  Widget _statusPill(String status) =>
      Chip(label: Text(_status(status)), visualDensity: VisualDensity.compact);
  String _deductionTotal(List<HrDeductionRecord> deductions) {
    if (deductions.isEmpty) return '0.00 EGP';
    final totals = <String, double>{};
    for (final item in deductions) {
      totals.update(
        item.employee.salaryCurrency,
        (value) => value + item.resolvedAmount(),
        ifAbsent: item.resolvedAmount,
      );
    }
    return totals.entries
        .map((entry) => '${entry.value.toStringAsFixed(2)} ${entry.key}')
        .join(' + ');
  }

  static String _date(DateTime date) =>
      DateFormat('yyyy/MM/dd', 'ar').format(date);
  static String _status(String value) =>
      {
        'present': 'حاضر',
        'late': 'متأخر',
        'permission': 'إذن معتمد',
        'day_off': 'راحة أسبوعية / يوم غير مجدول',
        'field_mission': 'مهمة ميدانية',
        'not_attended': 'غياب دون تسجيل',
      }[value] ??
      value;
}

class _LoadingReport extends StatelessWidget {
  const _LoadingReport();
  @override
  Widget build(BuildContext context) => const WolfCard(
    child: Padding(
      padding: EdgeInsets.all(40),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => WolfCard(
    child: ListTile(
      leading: const Icon(Icons.error_outline, color: ZaWolfColors.error),
      title: const Text('تعذر تحميل التقرير'),
      subtitle: const Text('تحقق من الاتصال والصلاحيات ثم أعد المحاولة.'),
      trailing: TextButton(
        onPressed: onRetry,
        child: const Text('إعادة المحاولة'),
      ),
    ),
  );
}

class _InteractiveReportTrend extends StatefulWidget {
  const _InteractiveReportTrend({required this.points});
  final List<HrAttendanceTrendPoint> points;

  @override
  State<_InteractiveReportTrend> createState() =>
      _InteractiveReportTrendState();
}

class _InteractiveReportTrendState extends State<_InteractiveReportTrend> {
  int? selected;

  @override
  Widget build(BuildContext context) {
    final point = selected == null ? null : widget.points[selected!];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: const [
            _ChartLegend(color: ZaWolfColors.primaryCyan, label: 'نسبة الحضور'),
            _ChartLegend(color: ZaWolfColors.warning, label: 'نسبة التأخير'),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child:
              point == null
                  ? const Text(
                    'مرر المؤشر أو اضغط على يوم لعرض تفاصيله.',
                    key: ValueKey('hint'),
                    style: TextStyle(color: ZaWolfColors.textSecondary),
                  )
                  : Container(
                    key: ValueKey(point.date),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: ZaWolfColors.primaryCyan.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${DateFormat('EEEE d MMMM', 'ar').format(point.date)} · '
                      'الحضور ${(point.attendanceRate * 100).round()}% '
                      '(${point.attended}/${point.scheduled}) · '
                      'التأخير ${(point.lateRate * 100).round()}% (${point.late})',
                    ),
                  ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 235,
          child: LayoutBuilder(
            builder:
                (context, constraints) => MouseRegion(
                  onHover:
                      (event) =>
                          _select(event.localPosition.dx, constraints.maxWidth),
                  onExit: (_) => setState(() => selected = null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown:
                        (event) => _select(
                          event.localPosition.dx,
                          constraints.maxWidth,
                        ),
                    child: CustomPaint(
                      painter: _ReportTrendPainter(widget.points, selected),
                      size: Size.infinite,
                    ),
                  ),
                ),
          ),
        ),
      ],
    );
  }

  void _select(double x, double width) {
    if (widget.points.isEmpty || width <= 56) return;
    final chartX = (x - 44).clamp(0.0, width - 56);
    final index =
        widget.points.length == 1
            ? 0
            : (chartX / (width - 56) * (widget.points.length - 1)).round();
    if (selected != index) setState(() => selected = index);
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 18,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: ZaWolfColors.textSecondary)),
    ],
  );
}

class _ReportTrendPainter extends CustomPainter {
  _ReportTrendPainter(this.points, this.selected);
  final List<HrAttendanceTrendPoint> points;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 44.0;
    const right = 12.0;
    const top = 10.0;
    const bottom = 34.0;
    final width = size.width - left - right;
    final height = size.height - top - bottom;
    if (width <= 0 || height <= 0) return;
    final grid =
        Paint()..color = ZaWolfColors.textSecondary.withValues(alpha: .18);
    for (var index = 0; index < 3; index++) {
      final y = top + height * index / 2;
      canvas.drawLine(Offset(left, y), Offset(left + width, y), grid);
      _text(canvas, '${100 - index * 50}%', Offset(0, y - 8), 11);
    }
    if (points.isEmpty) return;
    Offset offset(int index, double value) => Offset(
      points.length == 1
          ? left + width / 2
          : left + width * index / (points.length - 1),
      top + height * (1 - value.clamp(0, 1)),
    );
    void drawSeries(
      double Function(HrAttendanceTrendPoint) value,
      Color color,
    ) {
      final path = Path();
      for (var index = 0; index < points.length; index++) {
        final p = offset(index, value(points[index]));
        index == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      for (var index = 0; index < points.length; index++) {
        if (points.length > 14 && index != selected && index % 3 != 0) continue;
        canvas.drawCircle(
          offset(index, value(points[index])),
          index == selected ? 5 : 3,
          Paint()..color = color,
        );
      }
    }

    drawSeries((point) => point.attendanceRate, ZaWolfColors.primaryCyan);
    drawSeries((point) => point.lateRate, ZaWolfColors.warning);
    if (selected != null && selected! < points.length) {
      final x = offset(selected!, 0).dx;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + height),
        Paint()
          ..color = Colors.white.withValues(alpha: .35)
          ..strokeWidth = 1,
      );
    }
    final step = points.length <= 7 ? 1 : (points.length / 6).ceil();
    for (var index = 0; index < points.length; index += step) {
      final x = offset(index, 0).dx;
      _text(
        canvas,
        DateFormat('d/M', 'ar').format(points[index].date),
        Offset(x - 18, top + height + 9),
        10,
      );
    }
  }

  void _text(Canvas canvas, String value, Offset offset, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: ZaWolfColors.textSecondary, fontSize: size),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ReportTrendPainter old) =>
      old.points != points || old.selected != selected;
}
