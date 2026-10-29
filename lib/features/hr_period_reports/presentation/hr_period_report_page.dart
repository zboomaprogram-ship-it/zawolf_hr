import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../components/wolf_card.dart';
import '../../../design_system/components/skeletons.dart';
import '../../../theme/theme.dart';
import '../domain/hr_period_report.dart';
import 'hr_period_report_cubit.dart';
import 'hr_report_pdf_export.dart';
import 'hr_report_pdf_generator.dart';

class HrPeriodReportPage extends StatefulWidget {
  const HrPeriodReportPage({super.key});

  @override
  State<HrPeriodReportPage> createState() => _HrPeriodReportPageState();
}

class _HrPeriodReportPageState extends State<HrPeriodReportPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedDepartment;
  String _deductionFilter = 'all'; // 'all', 'with_deductions', 'late', 'absence', 'no_deductions'
  String _sortBy = 'deductions_desc'; // 'deductions_desc', 'late_desc', 'absent_desc', 'name_asc'
  bool _exportingPdf = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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
            width: 220,
            child: DropdownButtonFormField<String?>(
              initialValue: state.employeeId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'الموظف',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: ZaWolfColors.primaryCyan,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onPressed: _exportingPdf || state.report == null
              ? null
              : () => _exportPdf(context, state.report!, state.period),
          icon: _exportingPdf
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text(
            'تحميل / طباعة تقرير PDF',
            style: TextStyle(fontWeight: FontWeight.bold),
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
      const SizedBox(height: 22),
      _allEmployeesDeductionsSection(context, report),
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
        'absent': 'غياب',
      }[value] ??
      value;

  Widget _allEmployeesDeductionsSection(
    BuildContext context,
    HrPeriodReport report,
  ) {
    final allItems = report.employees
        .map((e) => EmployeeDeductionSummaryItem.fromReport(employee: e, report: report))
        .toList();

    final departments = report.employees
        .map((e) => e.department.trim())
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    var filtered = allItems.where((item) {
      if (_selectedDepartment != null &&
          _selectedDepartment!.isNotEmpty &&
          item.employee.department.trim() != _selectedDepartment) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchName = item.employee.name.toLowerCase().contains(q);
        final matchCode = item.employee.code.toLowerCase().contains(q);
        if (!matchName && !matchCode) return false;
      }
      switch (_deductionFilter) {
        case 'with_deductions':
          return item.totalDeductionDays > 0 || item.deductionCount > 0;
        case 'late':
          return item.lateDeductionDays > 0 || item.lateDays > 0;
        case 'absence':
          return item.absentDeductionDays > 0 || item.absentDays > 0;
        case 'no_deductions':
          return item.totalDeductionDays == 0 && item.deductionCount == 0;
        case 'all':
        default:
          return true;
      }
    }).toList();

    switch (_sortBy) {
      case 'deductions_desc':
        filtered.sort((a, b) => b.totalDeductionDays.compareTo(a.totalDeductionDays));
        break;
      case 'late_desc':
        filtered.sort((a, b) => b.lateDays.compareTo(a.lateDays));
        break;
      case 'absent_desc':
        filtered.sort((a, b) => b.absentDays.compareTo(a.absentDays));
        break;
      case 'name_asc':
        filtered.sort((a, b) => a.employee.name.compareTo(b.employee.name));
        break;
    }

    final totalDeductionsSum = filtered.fold<double>(0.0, (s, e) => s + e.totalDeductionDays);
    final totalActionsSum = filtered.fold<int>(0, (s, e) => s + e.deductionCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'جدول حصر الخصومات وحضور جميع الموظفين',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 2),
                const Text(
                  'بيان شامل بخصومات وتأخيرات وغياب الموظفين مع إمكانية الفلترة والتفاصيل والطباعة.',
                  style: TextStyle(color: ZaWolfColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ZaWolfColors.primaryCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ZaWolfColors.primaryCyan.withValues(alpha: 0.4)),
              ),
              child: Text(
                'عرض ${filtered.length} من ${allItems.length} موظف · إجمالي: ${totalDeductionsSum.toStringAsFixed(2)} يوم ($totalActionsSum إجراء)',
                style: const TextStyle(
                  color: ZaWolfColors.primaryCyan,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        WolfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 250,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'بحث باسم الموظف أو الكود...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedDepartment,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'القسم',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('كل الأقسام')),
                        ...departments.map(
                          (dept) => DropdownMenuItem<String?>(value: dept, child: Text(dept)),
                        ),
                      ],
                      onChanged: (val) => setState(() => _selectedDepartment = val),
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      initialValue: _sortBy,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'ترتيب حسب',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'deductions_desc', child: Text('الأعلى خصماً')),
                        DropdownMenuItem(value: 'late_desc', child: Text('الأعلى تأخيراً')),
                        DropdownMenuItem(value: 'absent_desc', child: Text('الأعلى غياباً')),
                        DropdownMenuItem(value: 'name_asc', child: Text('أبجدياً بالاسم')),
                      ],
                      onChanged: (val) => setState(() => _sortBy = val ?? 'deductions_desc'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: ZaWolfColors.surface03),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('فلترة الخصم: ', style: TextStyle(color: ZaWolfColors.textSecondary, fontSize: 12)),
                  ChoiceChip(
                    label: const Text('كل الموظفين'),
                    selected: _deductionFilter == 'all',
                    onSelected: (_) => setState(() => _deductionFilter = 'all'),
                  ),
                  ChoiceChip(
                    label: const Text('عليهم خصومات فقط'),
                    selected: _deductionFilter == 'with_deductions',
                    onSelected: (_) => setState(() => _deductionFilter = 'with_deductions'),
                  ),
                  ChoiceChip(
                    label: const Text('تأخيرات فقط'),
                    selected: _deductionFilter == 'late',
                    onSelected: (_) => setState(() => _deductionFilter = 'late'),
                  ),
                  ChoiceChip(
                    label: const Text('غياب فقط'),
                    selected: _deductionFilter == 'absence',
                    onSelected: (_) => setState(() => _deductionFilter = 'absence'),
                  ),
                  ChoiceChip(
                    label: const Text('بدون خصومات'),
                    selected: _deductionFilter == 'no_deductions',
                    onSelected: (_) => setState(() => _deductionFilter = 'no_deductions'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        WolfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('لا يوجد موظفون يطابقون شروط البحث أو الفلترة المحددة.'),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 16,
                    horizontalMargin: 12,
                    headingRowColor: WidgetStateProperty.all(ZaWolfColors.surface02),
                    columns: const [
                      DataColumn(label: Text('#')),
                      DataColumn(label: Text('الموظف والكود')),
                      DataColumn(label: Text('القسم')),
                      DataColumn(label: Text('الحضور')),
                      DataColumn(label: Text('التأخير')),
                      DataColumn(label: Text('الغياب')),
                      DataColumn(label: Text('الأذونات')),
                      DataColumn(label: Text('الإجازات')),
                      DataColumn(label: Text('إجمالي الخصم')),
                      DataColumn(label: Text('عدد الإجراءات')),
                      DataColumn(label: Text('تفصيل الخصومات')),
                      DataColumn(label: Text('المبلغ المقدر')),
                      DataColumn(label: Text('التفاصيل')),
                    ],
                    rows: filtered.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final item = entry.value;
                      final hasDed = item.totalDeductionDays > 0;

                      return DataRow(
                        cells: [
                          DataCell(Text('$index')),
                          DataCell(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.employee.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  item.employee.code,
                                  style: const TextStyle(color: ZaWolfColors.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text(item.employee.department)),
                          DataCell(Text('${item.presentDays} يوم')),
                          DataCell(
                            Text(
                              '${item.lateDays} يوم${item.lateMinutes > 0 ? ' (${item.lateMinutes}د)' : ''}',
                              style: TextStyle(
                                color: item.lateDays > 0 ? ZaWolfColors.warning : ZaWolfColors.textPrimary,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${item.absentDays} يوم',
                              style: TextStyle(
                                color: item.absentDays > 0 ? ZaWolfColors.error : ZaWolfColors.textPrimary,
                                fontWeight: item.absentDays > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              item.permissionCount > 0
                                  ? '${item.permissionCount}${item.permissionMinutes > 0 ? ' (${(item.permissionMinutes / 60).toStringAsFixed(1)}س)' : ''}'
                                  : '—',
                              style: TextStyle(
                                color: item.permissionCount > 0 ? ZaWolfColors.primaryCyan : ZaWolfColors.textMuted,
                                fontWeight: item.permissionCount > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              item.leaveDays > 0
                                  ? '${item.leaveDays} يوم${item.leaveRequestsCount > 0 ? ' (${item.leaveRequestsCount})' : ''}'
                                  : (item.leaveRequestsCount > 0 ? '${item.leaveRequestsCount} طلب' : '—'),
                              style: TextStyle(
                                color: (item.leaveDays > 0 || item.leaveRequestsCount > 0)
                                    ? Colors.lightBlueAccent
                                    : ZaWolfColors.textMuted,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: hasDed
                                    ? ZaWolfColors.error.withValues(alpha: 0.15)
                                    : ZaWolfColors.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.totalDeductionDays.toStringAsFixed(2)} يوم',
                                style: TextStyle(
                                  color: hasDed ? ZaWolfColors.error : ZaWolfColors.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text('${item.deductionCount}')),
                          DataCell(
                            Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              children: [
                                if (item.lateDeductionDays > 0)
                                  _MiniChip(
                                    label: 'تأخير: ${item.lateDeductionDays.toStringAsFixed(2)}',
                                    color: ZaWolfColors.warning,
                                  ),
                                if (item.absentDeductionDays > 0)
                                  _MiniChip(
                                    label: 'غياب: ${item.absentDeductionDays.toStringAsFixed(2)}',
                                    color: ZaWolfColors.error,
                                  ),
                                if (item.otherDeductionDays > 0)
                                  _MiniChip(
                                    label: 'أخرى: ${item.otherDeductionDays.toStringAsFixed(2)}',
                                    color: ZaWolfColors.primaryCyan,
                                  ),
                                if (item.totalDeductionDays == 0)
                                  const Text('لا يوجد خصم', style: TextStyle(color: ZaWolfColors.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              item.totalAmount > 0 ? '${item.totalAmount.toStringAsFixed(2)} ج.م' : '—',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                textStyle: const TextStyle(fontSize: 11),
                              ),
                              icon: const Icon(Icons.visibility_outlined, size: 14),
                              label: const Text('عرض التفاصيل'),
                              onPressed: () => _showEmployeeDeductionDetailsModal(context, item, report),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _showEmployeeDeductionDetailsModal(
    BuildContext context,
    EmployeeDeductionSummaryItem item,
    HrPeriodReport report,
  ) {
    final employeeRecords = report.forEmployee(item.employee.id).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final timeFormat = DateFormat('hh:mm a', 'ar');
    final dayFormat = DateFormat('EEEE، yyyy/MM/dd', 'ar');

    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: ZaWolfColors.surface01,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 780,
            constraints: const BoxConstraints(maxHeight: 700),
            padding: const EdgeInsets.all(20),
            child: DefaultTabController(
              length: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.badge_outlined, color: ZaWolfColors.primaryCyan),
                          const SizedBox(width: 8),
                          Text(
                            'تفاصيل الموظف: ${item.employee.name}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(
                    'كود: ${item.employee.code} · القسم: ${item.employee.department}',
                    style: const TextStyle(color: ZaWolfColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ZaWolfColors.surface02,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ZaWolfColors.surface03),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _kpiItem('إجمالي الخصم', '${item.totalDeductionDays.toStringAsFixed(2)} يوم', ZaWolfColors.error),
                          const SizedBox(width: 16),
                          _kpiItem('عدد الإجراءات', '${item.deductionCount}', ZaWolfColors.warning),
                          const SizedBox(width: 16),
                          _kpiItem('أيام التأخير', '${item.lateDays} (${item.lateMinutes}د)', ZaWolfColors.warning),
                          const SizedBox(width: 16),
                          _kpiItem('أيام الغياب', '${item.absentDays} يوم', ZaWolfColors.error),
                          const SizedBox(width: 16),
                          _kpiItem('الأذونات', '${item.permissionCount}${item.permissionMinutes > 0 ? ' (${(item.permissionMinutes / 60).toStringAsFixed(1)}س)' : ''}', ZaWolfColors.primaryCyan),
                          const SizedBox(width: 16),
                          _kpiItem('الإجازات', '${item.leaveDays} يوم', Colors.lightBlueAccent),
                          if (item.totalAmount > 0) ...[
                            const SizedBox(width: 16),
                            _kpiItem('المبلغ التقديري', '${item.totalAmount.toStringAsFixed(2)} ج.م', Colors.amberAccent),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    indicatorColor: ZaWolfColors.primaryCyan,
                    labelColor: ZaWolfColors.primaryCyan,
                    unselectedLabelColor: ZaWolfColors.textSecondary,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.money_off_outlined, size: 16),
                        text: 'تفاصيل الخصومات (تأخير وغياب)',
                      ),
                      Tab(
                        icon: Icon(Icons.access_time_outlined, size: 16),
                        text: 'سجل وأوقات الحضور اليومي',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // TAB 1: DEDUCTIONS (Late & Absent only)
                        item.deductions.isEmpty
                            ? const Center(
                                child: Text(
                                  '✓ لا توجد أي خصومات مسجلة (تأخير أو غياب) على الموظف في هذه الفترة.',
                                  style: TextStyle(color: ZaWolfColors.success, fontSize: 14),
                                ),
                              )
                            : ListView.separated(
                                itemCount: item.deductions.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, idx) {
                                  final ded = item.deductions[idx];
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: ZaWolfColors.surface02,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: ZaWolfColors.surface03),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                ded.reason,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: ZaWolfColors.warning.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: ZaWolfColors.warning.withValues(alpha: 0.4)),
                                              ),
                                              child: Text(
                                                ded.fraction > 0 ? '${(ded.fraction * 100).toStringAsFixed(0)}% يوم' : 'مبلغ',
                                                style: const TextStyle(
                                                  color: ZaWolfColors.warning,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_date(ded.date)} · المصدر: ${ded.source} · القيمة: ${ded.resolvedAmount().toStringAsFixed(2)} ${ded.employee.salaryCurrency}',
                                          style: const TextStyle(color: ZaWolfColors.textSecondary, fontSize: 11),
                                        ),
                                        if (ded.detail != null && ded.detail!.trim().isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.25),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Icon(Icons.info_outline, size: 14, color: ZaWolfColors.primaryCyan),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    ded.detail!,
                                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),

                        // TAB 2: DAILY ATTENDANCE & PUNCH TIMES
                        employeeRecords.isEmpty
                            ? const Center(
                                child: Text(
                                  'لا توجد سجلات حضور مسجلة لهذا الموظف خلال الفترة.',
                                  style: TextStyle(color: ZaWolfColors.textMuted, fontSize: 14),
                                ),
                              )
                            : ListView.separated(
                                itemCount: employeeRecords.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, idx) {
                                  final r = employeeRecords[idx];
                                  final checkInStr = r.checkIn != null ? timeFormat.format(r.checkIn!) : null;
                                  final checkOutStr = r.checkOut != null ? timeFormat.format(r.checkOut!) : null;

                                  Color statusColor;
                                  String statusLabel;
                                  switch (r.status) {
                                    case 'present':
                                      statusColor = ZaWolfColors.success;
                                      statusLabel = 'حاضر';
                                      break;
                                    case 'late':
                                      statusColor = ZaWolfColors.warning;
                                      statusLabel = 'متأخر';
                                      break;
                                    case 'not_attended':
                                      statusColor = ZaWolfColors.error;
                                      statusLabel = 'غائب';
                                      break;
                                    case 'day_off':
                                      statusColor = (r.statusDetail?.startsWith('إجازة') == true || r.statusDetail == 'عمل عن بعد')
                                          ? Colors.lightBlueAccent
                                          : ZaWolfColors.textMuted;
                                      statusLabel = r.statusDetail ?? 'عطلة / راحة';
                                      break;
                                    case 'permission':
                                      statusColor = ZaWolfColors.primaryCyan;
                                      statusLabel = 'إذن وقتي';
                                      break;
                                    case 'field_mission':
                                      statusColor = Colors.tealAccent;
                                      statusLabel = 'مأمورية';
                                      break;
                                    default:
                                      statusColor = ZaWolfColors.textSecondary;
                                      statusLabel = r.status;
                                  }

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: ZaWolfColors.surface02,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: r.status == 'late'
                                            ? ZaWolfColors.warning.withValues(alpha: 0.3)
                                            : (r.status == 'not_attended'
                                                ? ZaWolfColors.error.withValues(alpha: 0.3)
                                                : ZaWolfColors.surface03),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Date & Day
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                dayFormat.format(r.date),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (r.statusDetail != null && r.statusDetail != statusLabel)
                                                Text(
                                                  r.statusDetail!,
                                                  style: const TextStyle(color: ZaWolfColors.textSecondary, fontSize: 11),
                                                ),
                                            ],
                                          ),
                                        ),
                                        // Status badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                          ),
                                          child: Text(
                                            statusLabel,
                                            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Check-in
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.login_outlined,
                                                size: 14,
                                                color: checkInStr != null ? ZaWolfColors.success : ZaWolfColors.textMuted,
                                              ),
                                              const SizedBox(width: 4),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('الحضور', style: TextStyle(color: ZaWolfColors.textSecondary, fontSize: 10)),
                                                  Text(
                                                    checkInStr ?? 'لم يسجل',
                                                    style: TextStyle(
                                                      color: checkInStr != null ? Colors.white : ZaWolfColors.textMuted,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Check-out
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.logout_outlined,
                                                size: 14,
                                                color: checkOutStr != null ? Colors.lightBlueAccent : ZaWolfColors.textMuted,
                                              ),
                                              const SizedBox(width: 4),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('الانصراف', style: TextStyle(color: ZaWolfColors.textSecondary, fontSize: 10)),
                                                  Text(
                                                    checkOutStr ?? 'لم يسجل',
                                                    style: TextStyle(
                                                      color: checkOutStr != null ? Colors.white : ZaWolfColors.textMuted,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Late minutes if any
                                        if (r.lateMinutes > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: ZaWolfColors.warning.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'تأخير ${r.lateMinutes}د',
                                              style: const TextStyle(color: ZaWolfColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportPdf(
    BuildContext context,
    HrPeriodReport report,
    HrReportPeriod period,
  ) async {
    setState(() => _exportingPdf = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final allSummaries = report.employees
          .map((e) => EmployeeDeductionSummaryItem.fromReport(employee: e, report: report))
          .toList();

      final htmlContent = HrReportPdfGenerator.generateHtml(
        report: report,
        period: period,
        items: allSummaries,
      );

      final fileName = 'HR_Deductions_Report_${DateFormat('yyyyMMdd').format(period.start)}_${DateFormat('yyyyMMdd').format(period.end)}';

      final success = await printOrDownloadPdfReport(
        htmlContent: htmlContent,
        fileName: fileName,
      );

      if (success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('تم فتح نافذة الطباعة / تنزيل التقرير بتنسيق PDF بنجاح.'),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('تعذر استخراج ملف التقرير، يرجى المحاولة مرة أخرى.'),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء إعداد التقرير: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold),
        ),
      );
}

Widget _kpiItem(String title, String val, Color color) => Column(
      children: [
        Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(color: ZaWolfColors.textSecondary, fontSize: 11)),
      ],
    );

class _LoadingReport extends StatelessWidget {
  const _LoadingReport();
  @override
  Widget build(BuildContext context) => const WolfCard(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: SkeletonDetailPane(),
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
