import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/payroll_run_model.dart';
import '../../models/employee_role.dart';
import '../../services/auth_service.dart';
import '../../services/payroll_service.dart';
import '../../services/sheets_export_service.dart';
import '../../theme/theme.dart';
import '../../utils/payroll_cycle.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final PayrollService _payrollService = PayrollService();
  final SheetsExportService _exportService = SheetsExportService();
  DateTime _selectedMonth = PayrollCycle.forDate(DateTime.now()).end;
  bool _calculating = false;

  String get _monthKey => DateFormat('yyyy-MM').format(_selectedMonth);

  Future<void> _calculate() async {
    final actor = context.read<AuthService>().currentUser;
    if (actor == null) return;
    setState(() => _calculating = true);
    try {
      final count = await _payrollService.calculateCompanyPayroll(
        actor: actor,
        monthKey: _monthKey,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم حساب رواتب $count موظف.')));
      }
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  Future<void> _export(List<PayrollRunModel> runs) async {
    if (runs.isEmpty) return;
    final csv = await _exportService.exportPayrollToSheet(
      'payroll_$_monthKey',
      runs,
    );
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ كشف الرواتب CSV للحافظة.')),
    );
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) setState(() => _selectedMonth = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actor = context.watch<AuthService>().currentUser;
    final canExportReports = EmployeeRole.canAccessReports(actor?.role);
    return Scaffold(
      appBar: AppBar(
        title: Text('الرواتب', style: theme.textTheme.headlineMedium),
        actions: [
          IconButton(
            tooltip: 'اختيار الشهر',
            onPressed: _selectMonth,
            icon: const Icon(
              Icons.calendar_today,
              color: ZaWolfColors.primaryCyan,
            ),
          ),
          IconButton(
            tooltip: 'حساب الرواتب',
            onPressed: _calculating ? null : _calculate,
            icon: _calculating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.calculate, color: ZaWolfColors.wolfGreen),
          ),
        ],
      ),
      body: StreamBuilder<List<PayrollRunModel>>(
        stream: _payrollService.watchPayrollRuns(_monthKey),
        builder: (context, snapshot) {
          final runs = snapshot.data ?? [];
          final totalNet = runs.fold<double>(
            0,
            (total, run) => total + run.netSalary,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'عدد الموظفين',
                      value: '${runs.length}',
                      color: ZaWolfColors.primaryCyan,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Metric(
                      label: 'إجمالي الصافي',
                      value: totalNet.toStringAsFixed(0),
                      color: ZaWolfColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (canExportReports) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: runs.isEmpty ? null : () => _export(runs),
                        icon: const Icon(Icons.copy),
                        label: const Text('نسخ CSV'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _calculating ? null : _calculate,
                      icon: const Icon(Icons.calculate),
                      label: Text('حساب $_monthKey'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                PayrollCycle.forKey(_monthKey).arabicRangeLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (runs.isEmpty)
                WolfCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      'اضغط حساب الرواتب لإنشاء مسودات شهر $_monthKey',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...runs.map(
                  (run) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PayrollCard(
                      run: run,
                      onReviewed: actor == null
                          ? null
                          : () => _payrollService.markReviewed(
                              run.payrollId,
                              actor,
                            ),
                      onLocked: actor == null
                          ? null
                          : () => _payrollService.markLocked(
                              run.payrollId,
                              actor,
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

class _PayrollCard extends StatelessWidget {
  final PayrollRunModel run;
  final VoidCallback? onReviewed;
  final VoidCallback? onLocked;

  const _PayrollCard({
    required this.run,
    required this.onReviewed,
    required this.onLocked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${run.netSalary.toStringAsFixed(2)} ${run.currency}',
                style: const TextStyle(
                  color: ZaWolfColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    run.employeeName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    PayrollStatus.arabicLabel(run.status),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'أساسي ${run.baseSalary.toStringAsFixed(2)} - خصم ${run.attendanceDeductions.toStringAsFixed(2)} - سلف ${run.advances.toStringAsFixed(2)} + مكافأة ${run.rewardsBonus.toStringAsFixed(2)}',
            textDirection: TextDirection.rtl,
            style: theme.textTheme.bodyMedium,
          ),
          if (run.status == PayrollStatus.draft) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onReviewed,
              icon: const Icon(Icons.verified),
              label: const Text('اعتماد المراجعة'),
            ),
          ],
          if (run.status == PayrollStatus.reviewed) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onLocked,
              style: FilledButton.styleFrom(
                backgroundColor: ZaWolfColors.warning,
              ),
              icon: const Icon(Icons.lock),
              label: const Text('إغلاق الراتب'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZaWolfColors.surface03),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(color: color),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
