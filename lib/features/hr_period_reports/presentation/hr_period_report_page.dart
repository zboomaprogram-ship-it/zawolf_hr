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
    final scheduled = records.length;
    final attended =
        status('present') + status('late') + status('field_mission');
    final approvedDeductions =
        records.where((item) => item.approvedDeduction).length;
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
            'إجازة / راحة',
            '${status('day_off')}',
            Icons.event_available_outlined,
            ZaWolfColors.textSecondary,
          ),
          _metric(
            'خصم معتمد',
            '$approvedDeductions',
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
            SizedBox(
              height: 190,
              child: CustomPaint(
                painter: _ReportLineChart(_dailyRate(records, report.period)),
              ),
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
      _requestsSection(report.requestsForEmployee(state.employeeId)),
      const SizedBox(height: 18),
      _deductionsSection(report.deductionsForEmployee(state.employeeId)),
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
            child: Text('لا توجد إجازات أو أذونات ضمن الفترة.'),
          ),
        ),
      ...requests.map(
        (request) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: WolfCard(
            child: ListTile(
              leading: Icon(
                request.type == 'إجازة'
                    ? Icons.event_available_outlined
                    : Icons.schedule_outlined,
              ),
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
            child: ListTile(
              leading: const Icon(
                Icons.payments_outlined,
                color: ZaWolfColors.warning,
              ),
              title: Text('${deduction.reason} · ${deduction.employee.name}'),
              subtitle: Text(
                '${_date(deduction.date)} · ${deduction.source}${deduction.amount > 0 ? ' · ${deduction.amount.toStringAsFixed(2)} EGP' : ''}${deduction.fraction > 0 ? ' · ${(deduction.fraction * 100).toStringAsFixed(0)}%' : ''}',
              ),
              trailing: Chip(
                label: Text(
                  deduction.affectsDiscipline ? 'معتمد' : 'قيد المراجعة',
                ),
              ),
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
        title: Text('${_status(r.status)} · ${_date(r.date)}'),
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
  List<double> _dailyRate(
    List<HrAttendanceRecord> records,
    HrReportPeriod period,
  ) => List.generate(period.days, (index) {
    final day = period.start.add(Duration(days: index));
    final items =
        records
            .where((record) => DateUtils.isSameDay(record.date, day))
            .toList();
    if (items.isEmpty) return 0;
    return items
            .where(
              (record) =>
                  ['present', 'late', 'field_mission'].contains(record.status),
            )
            .length /
        items.length;
  });
  static String _date(DateTime date) =>
      DateFormat('yyyy/MM/dd', 'ar').format(date);
  static String _status(String value) =>
      {
        'present': 'حاضر',
        'late': 'متأخر',
        'permission': 'إذن معتمد',
        'day_off': 'إجازة أو راحة',
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

class _ReportLineChart extends CustomPainter {
  _ReportLineChart(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    final axis =
        Paint()..color = ZaWolfColors.textSecondary.withValues(alpha: 0.35);
    final line =
        Paint()
          ..color = ZaWolfColors.primaryCyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 4; index++) {
      canvas.drawLine(
        Offset(0, size.height * index / 3),
        Offset(size.width, size.height * index / 3),
        axis,
      );
    }
    if (values.isEmpty) return;
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x =
          values.length == 1
              ? size.width / 2
              : size.width * index / (values.length - 1);
      final y = size.height * (1 - values[index].clamp(0, 1));
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _ReportLineChart old) => old.values != values;
}
