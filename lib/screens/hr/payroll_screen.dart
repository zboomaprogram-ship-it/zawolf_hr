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
import '../../design_system/components/rtl_navigation.dart';
import 'widgets/payroll_pre_audit_dialog.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final PayrollService _payrollService = PayrollService();
  final SheetsExportService _exportService = SheetsExportService();
  final TextEditingController _searchController = TextEditingController();

  DateTime _selectedMonth = PayrollCycle.forDate(DateTime.now()).end;
  bool _calculating = false;
  String _statusFilter = 'all'; // all, draft, reviewed, locked

  String get _monthKey => DateFormat('yyyy-MM').format(_selectedMonth);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _changeMonth(int deltaMonths) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + deltaMonths,
        15,
      );
    });
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

  Future<void> _preAuditAndCalculate() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => const PayrollPreAuditDialog(),
    );
    if (proceed == true) {
      await _calculate();
    }
  }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حساب رواتب $count موظف بنجاح.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إتمام الحساب: $e'),
            backgroundColor: ZaWolfColors.error,
          ),
        );
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
      const SnackBar(content: Text('تم نسخ كشف الرواتب بصيغة CSV للحافظة.')),
    );
  }

  List<PayrollRunModel> _filteredRuns(List<PayrollRunModel> runs) {
    final query = _searchController.text.trim().toLowerCase();
    return runs.where((run) {
      final matchesSearch =
          query.isEmpty ||
          run.employeeName.toLowerCase().contains(query) ||
          run.employeeId.toLowerCase().contains(query) ||
          run.department.toLowerCase().contains(query);
      final matchesStatus =
          _statusFilter == 'all' || run.status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  void _showDetailDialog(PayrollRunModel run) {
    showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: ZaWolfColors.surface01,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: ZaWolfColors.surface03),
          ),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: ZaWolfColors.primaryCyan.withValues(alpha: 0.15),
                foregroundColor: ZaWolfColors.primaryCyan,
                child: Text(
                  run.employeeName.isNotEmpty ? run.employeeName[0] : '؟',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      run.employeeName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${run.employeeId} • ${run.department.isNotEmpty ? run.department : "الموظف"}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ZaWolfColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: run.status),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ZaWolfColors.success.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ZaWolfColors.success.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'صافي الراتب المستحق:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${run.netSalary.toStringAsFixed(2)} ${run.currency}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ZaWolfColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DetailRow(
                    label: 'الراتب الأساسي',
                    value: '${run.baseSalary.toStringAsFixed(2)} ${run.currency}',
                    color: Colors.white,
                  ),
                  const Divider(color: ZaWolfColors.surface03),
                  _DetailRow(
                    label: 'خصومات الحضور والأذونات (${run.approvedDeductionCount} خصم)',
                    value: '-${run.attendanceDeductions.toStringAsFixed(2)} ${run.currency}',
                    color: run.attendanceDeductions > 0 ? ZaWolfColors.error : ZaWolfColors.textMuted,
                  ),
                  const Divider(color: ZaWolfColors.surface03),
                  _DetailRow(
                    label: 'السلف المستقطعة (${run.advanceRecordCount} سلفة)',
                    value: '-${run.advances.toStringAsFixed(2)} ${run.currency}',
                    color: run.advances > 0 ? ZaWolfColors.warning : ZaWolfColors.textMuted,
                  ),
                  const Divider(color: ZaWolfColors.surface03),
                  _DetailRow(
                    label: 'المكافآت والحوافز (${run.bonusRecordCount} مكافأة)',
                    value: '+${run.rewardsBonus.toStringAsFixed(2)} ${run.currency}',
                    color: run.rewardsBonus > 0 ? ZaWolfColors.success : ZaWolfColors.textMuted,
                  ),
                  const Divider(color: ZaWolfColors.surface03),
                  _DetailRow(
                    label: 'دورة الحساب',
                    value: run.monthKey,
                    color: ZaWolfColors.textSecondary,
                  ),
                  if (run.calculatedBy.isNotEmpty) ...[
                    const Divider(color: ZaWolfColors.surface03),
                    _DetailRow(
                      label: 'حُسب بواسطة',
                      value: run.calculatedBy,
                      color: ZaWolfColors.textMuted,
                    ),
                  ],
                  if (run.reviewedBy != null && run.reviewedBy!.isNotEmpty) ...[
                    const Divider(color: ZaWolfColors.surface03),
                    _DetailRow(
                      label: 'تمت المراجعة بواسطة',
                      value: run.reviewedBy!,
                      color: ZaWolfColors.primaryCyan,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actor = context.watch<AuthService>().currentUser;
    final canExportReports = EmployeeRole.canAccessReports(actor?.role);

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
              title: Text('إدارة الرواتب', style: theme.textTheme.headlineMedium),
              actions: [
                IconButton(
                  tooltip: 'اختيار الشهر يدوياً',
                  onPressed: _selectMonth,
                  icon: const Icon(
                    Icons.calendar_today_outlined,
                    color: ZaWolfColors.primaryCyan,
                  ),
                ),
                if (canExportReports)
                  IconButton(
                    tooltip: 'تصدير كشف الرواتب CSV',
                    onPressed: () async {
                      final runs = await _payrollService.watchPayrollRuns(_monthKey).first;
                      _export(runs);
                    },
                    icon: const Icon(Icons.file_download_outlined),
                  ),
              ],
            ),
            body: StreamBuilder<List<PayrollRunModel>>(
              stream: _payrollService.watchPayrollRuns(_monthKey),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
                  );
                }

                final allRuns = snapshot.data ?? [];
                final filteredRuns = _filteredRuns(allRuns);

                final totalEmployees = allRuns.length;
                final totalNet = allRuns.fold<double>(
                  0,
                  (total, run) => total + run.netSalary,
                );
                final totalDeductions = allRuns.fold<double>(
                  0,
                  (total, run) => total + run.attendanceDeductions,
                );
                final totalBonuses = allRuns.fold<double>(
                  0,
                  (total, run) => total + run.rewardsBonus,
                );
                final totalAdvances = allRuns.fold<double>(
                  0,
                  (total, run) => total + run.advances,
                );
                final draftCount = allRuns
                    .where((r) => r.status == PayrollStatus.draft)
                    .length;
                final reviewedCount = allRuns
                    .where((r) => r.status == PayrollStatus.reviewed)
                    .length;
                final lockedCount = allRuns
                    .where((r) => r.status == PayrollStatus.locked)
                    .length;

                return RefreshIndicator(
                  color: ZaWolfColors.primaryCyan,
                  onRefresh: () async => setState(() {}),
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 24 : 16,
                      vertical: 16,
                    ),
                    children: [
                      // 1. Month Cycle Navigator & Quick Actions
                      WolfCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              tooltip: 'الشهر السابق',
                              onPressed: () => _changeMonth(-1),
                            ),
                            InkWell(
                              onTap: _selectMonth,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_month,
                                      size: 18,
                                      color: ZaWolfColors.primaryCyan,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'دورة $_monthKey',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              tooltip: 'الشهر التالي',
                              onPressed: () => _changeMonth(1),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                PayrollCycle.forKey(_monthKey).arabicRangeLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: ZaWolfColors.textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isDesktop && canExportReports) ...[
                              OutlinedButton.icon(
                                onPressed: allRuns.isEmpty ? null : () => _export(allRuns),
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('نسخ كشف CSV'),
                              ),
                              const SizedBox(width: 12),
                            ],
                            FilledButton.icon(
                              onPressed: _calculating ? null : _preAuditAndCalculate,
                              icon: _calculating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.fact_check_outlined, size: 18),
                              label: Text(
                                _calculating
                                    ? 'جارٍ الحساب...'
                                    : 'تدقيق وحساب $_monthKey',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. High-Impact Metric Bento Grid
                      if (isDesktop)
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryTile(
                                label: 'إجمالي صافي الرواتب',
                                value: '${totalNet.toStringAsFixed(0)} EGP',
                                icon: Icons.payments_outlined,
                                color: ZaWolfColors.success,
                                subtitle: 'لكل الموظفين المستحقين',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SummaryTile(
                                label: 'الموظفون المدرجون',
                                value: '$totalEmployees موظف',
                                icon: Icons.badge_outlined,
                                color: ZaWolfColors.primaryCyan,
                                subtitle: 'مسجلون بكشف الشهر',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SummaryTile(
                                label: 'إجمالي الخصومات',
                                value: '-${totalDeductions.toStringAsFixed(0)} EGP',
                                icon: Icons.remove_circle_outline,
                                color: ZaWolfColors.error,
                                subtitle: 'حضور وأذونات معتمدة',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SummaryTile(
                                label: 'المكافآت والسلف',
                                value: '+${totalBonuses.toStringAsFixed(0)} / -${totalAdvances.toStringAsFixed(0)}',
                                icon: Icons.swap_vert,
                                color: ZaWolfColors.warning,
                                subtitle: 'مكافآت (+) / سلف (-)',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SummaryTile(
                                label: 'حالة الدورة',
                                value: lockedCount == totalEmployees && totalEmployees > 0
                                    ? 'معتمدة ومقفلة'
                                    : reviewedCount > 0
                                        ? '$reviewedCount تمت المراجعة'
                                        : '$draftCount مسودة',
                                icon: Icons.verified_outlined,
                                color: lockedCount == totalEmployees && totalEmployees > 0
                                    ? ZaWolfColors.success
                                    : ZaWolfColors.primaryBlue,
                                subtitle: 'جاهزية كشف الرواتب',
                              ),
                            ),
                          ],
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryTile(
                                label: 'إجمالي الصافي',
                                value: '${totalNet.toStringAsFixed(0)} EGP',
                                icon: Icons.payments_outlined,
                                color: ZaWolfColors.success,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SummaryTile(
                                label: 'الموظفون',
                                value: '$totalEmployees',
                                icon: Icons.badge_outlined,
                                color: ZaWolfColors.primaryCyan,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryTile(
                                label: 'الخصومات',
                                value: '-${totalDeductions.toStringAsFixed(0)}',
                                icon: Icons.remove_circle_outline,
                                color: ZaWolfColors.error,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SummaryTile(
                                label: 'المكافآت / السلف',
                                value: '+${totalBonuses.toStringAsFixed(0)} / -${totalAdvances.toStringAsFixed(0)}',
                                icon: Icons.swap_vert,
                                color: ZaWolfColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // 3. Search and Status Filter Toolbar
                      WolfCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      hintText: 'ابحث باسم الموظف أو الكود أو القسم...',
                                      prefixIcon: const Icon(Icons.search, size: 20),
                                      suffixIcon: _searchController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 18),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() {});
                                              },
                                            )
                                          : null,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: ZaWolfColors.surface03,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (!isDesktop && canExportReports) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'نسخ CSV',
                                    onPressed: allRuns.isEmpty
                                        ? null
                                        : () => _export(allRuns),
                                    icon: const Icon(Icons.copy),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _FilterChip(
                                    label: 'الكل ($totalEmployees)',
                                    selected: _statusFilter == 'all',
                                    onSelected: () => setState(() => _statusFilter = 'all'),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChip(
                                    label: 'مسودة ($draftCount)',
                                    selected: _statusFilter == PayrollStatus.draft,
                                    onSelected: () => setState(
                                      () => _statusFilter = PayrollStatus.draft,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChip(
                                    label: 'تمت المراجعة ($reviewedCount)',
                                    selected: _statusFilter == PayrollStatus.reviewed,
                                    onSelected: () => setState(
                                      () => _statusFilter = PayrollStatus.reviewed,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _FilterChip(
                                    label: 'معتمد / مقفل ($lockedCount)',
                                    selected: _statusFilter == PayrollStatus.locked,
                                    onSelected: () => setState(
                                      () => _statusFilter = PayrollStatus.locked,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. Data View (Desktop Table vs Responsive Cards)
                      if (allRuns.isEmpty)
                        WolfCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 56,
                                  color: ZaWolfColors.textMuted,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'لا توجد كشوف رواتب مدخلة لشهر $_monthKey حتى الآن',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'اضغط "تدقيق وحساب $_monthKey" في الأعلى لبدء توليد مسودة رواتب الشهر.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: ZaWolfColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (filteredRuns.isEmpty)
                        WolfCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                'لا توجد نتائج تطابق البحث أو الفلتر المحدد.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: ZaWolfColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (isDesktop)
                        // Desktop High-Density Table View
                        WolfCard(
                          padding: EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Column(
                              children: [
                                // Table Header
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  color: ZaWolfColors.surface02,
                                  child: const Row(
                                    children: [
                                      Expanded(flex: 3, child: Text('الموظف', style: TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(flex: 2, child: Text('الراتب الأساسي', style: TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(flex: 2, child: Text('الخصومات', style: TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(flex: 2, child: Text('السلف', style: TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(flex: 2, child: Text('المكافآت', style: TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(flex: 2, child: Text('صافي الراتب', style: TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(flex: 2, child: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(flex: 3, child: Center(child: Text('الإجراءات', style: TextStyle(fontWeight: FontWeight.bold)))),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1, color: ZaWolfColors.surface03),
                                // Table Rows
                                ...filteredRuns.map((run) {
                                  return InkWell(
                                    onTap: () => _showDetailDialog(run),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: ZaWolfColors.surface03,
                                            width: 0.6,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Employee info
                                          Expanded(
                                            flex: 3,
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor: ZaWolfColors.primaryCyan.withValues(alpha: 0.15),
                                                  foregroundColor: ZaWolfColors.primaryCyan,
                                                  child: Text(
                                                    run.employeeName.isNotEmpty ? run.employeeName[0] : '؟',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        run.employeeName,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 13,
                                                          color: Colors.white,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      Text(
                                                        '${run.employeeId} • ${run.department.isNotEmpty ? run.department : "عام"}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: ZaWolfColors.textMuted,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Base
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '${run.baseSalary.toStringAsFixed(0)} ${run.currency}',
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                          // Deductions
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              run.attendanceDeductions > 0
                                                  ? '-${run.attendanceDeductions.toStringAsFixed(0)} (${run.approvedDeductionCount})'
                                                  : '0',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: run.attendanceDeductions > 0 ? ZaWolfColors.error : ZaWolfColors.textMuted,
                                                fontWeight: run.attendanceDeductions > 0 ? FontWeight.w600 : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          // Advances
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              run.advances > 0 ? '-${run.advances.toStringAsFixed(0)}' : '0',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: run.advances > 0 ? ZaWolfColors.warning : ZaWolfColors.textMuted,
                                              ),
                                            ),
                                          ),
                                          // Bonuses
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              run.rewardsBonus > 0 ? '+${run.rewardsBonus.toStringAsFixed(0)}' : '0',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: run.rewardsBonus > 0 ? ZaWolfColors.success : ZaWolfColors.textMuted,
                                                fontWeight: run.rewardsBonus > 0 ? FontWeight.w600 : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          // Net
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '${run.netSalary.toStringAsFixed(2)} ${run.currency}',
                                              style: const TextStyle(
                                                color: ZaWolfColors.success,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          // Status
                                          Expanded(
                                            flex: 2,
                                            child: _StatusBadge(status: run.status),
                                          ),
                                          // Actions
                                          Expanded(
                                            flex: 3,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                if (run.status == PayrollStatus.draft)
                                                  FilledButton.tonal(
                                                    onPressed: actor == null
                                                        ? null
                                                        : () => _payrollService.markReviewed(
                                                              run.payrollId,
                                                              actor,
                                                            ),
                                                    style: FilledButton.styleFrom(
                                                      visualDensity: VisualDensity.compact,
                                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                                    ),
                                                    child: const Text('مراجعة', style: TextStyle(fontSize: 12)),
                                                  ),
                                                if (run.status == PayrollStatus.reviewed)
                                                  FilledButton(
                                                    onPressed: actor == null
                                                        ? null
                                                        : () => _payrollService.markLocked(
                                                              run.payrollId,
                                                              actor,
                                                            ),
                                                    style: FilledButton.styleFrom(
                                                      backgroundColor: ZaWolfColors.warning,
                                                      foregroundColor: Colors.black,
                                                      visualDensity: VisualDensity.compact,
                                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                                    ),
                                                    child: const Text('إغلاق', style: TextStyle(fontSize: 12)),
                                                  ),
                                                const SizedBox(width: 6),
                                                IconButton(
                                                  icon: const Icon(Icons.info_outline, size: 18),
                                                  tooltip: 'تفاصيل الحساب',
                                                  onPressed: () => _showDetailDialog(run),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        )
                      else
                        // Mobile Responsive Card List
                        ...filteredRuns.map(
                          (run) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PayrollMobileCard(
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
                              onDetails: () => _showDetailDialog(run),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: ZaWolfColors.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      PayrollStatus.reviewed => (
          'تمت المراجعة',
          ZaWolfColors.primaryCyan,
          ZaWolfColors.primaryCyan.withValues(alpha: 0.12),
        ),
      PayrollStatus.locked => (
          'معتمد ومغلق',
          ZaWolfColors.success,
          ZaWolfColors.success.withValues(alpha: 0.12),
        ),
      _ => (
          'مسودة',
          ZaWolfColors.textMuted,
          ZaWolfColors.surface03,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return WolfCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ZaWolfColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 10.5, color: ZaWolfColors.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? ZaWolfColors.primaryCyan.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? ZaWolfColors.primaryCyan : ZaWolfColors.surface03,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? ZaWolfColors.primaryCyan : ZaWolfColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PayrollMobileCard extends StatelessWidget {
  final PayrollRunModel run;
  final VoidCallback? onReviewed;
  final VoidCallback? onLocked;
  final VoidCallback onDetails;

  const _PayrollMobileCard({
    required this.run,
    required this.onReviewed,
    required this.onLocked,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return WolfCard(
      child: InkWell(
        onTap: onDetails,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: ZaWolfColors.primaryCyan.withValues(alpha: 0.15),
                  foregroundColor: ZaWolfColors.primaryCyan,
                  child: Text(
                    run.employeeName.isNotEmpty ? run.employeeName[0] : '؟',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        run.employeeName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${run.employeeId} • ${run.department.isNotEmpty ? run.department : "عام"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: ZaWolfColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: run.status),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: ZaWolfColors.surface02,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('صافي الراتب:', style: TextStyle(fontSize: 12, color: ZaWolfColors.textSecondary)),
                  Text(
                    '${run.netSalary.toStringAsFixed(2)} ${run.currency}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ZaWolfColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('أساسي: ${run.baseSalary.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11.5, color: ZaWolfColors.textSecondary)),
                Text('خصومات: -${run.attendanceDeductions.toStringAsFixed(0)}', style: TextStyle(fontSize: 11.5, color: run.attendanceDeductions > 0 ? ZaWolfColors.error : ZaWolfColors.textMuted)),
                Text('سلف: -${run.advances.toStringAsFixed(0)}', style: TextStyle(fontSize: 11.5, color: run.advances > 0 ? ZaWolfColors.warning : ZaWolfColors.textMuted)),
                Text('مكافآت: +${run.rewardsBonus.toStringAsFixed(0)}', style: TextStyle(fontSize: 11.5, color: run.rewardsBonus > 0 ? ZaWolfColors.success : ZaWolfColors.textMuted)),
              ],
            ),
            if (run.status == PayrollStatus.draft || run.status == PayrollStatus.reviewed) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (run.status == PayrollStatus.draft)
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: onReviewed,
                        icon: const Icon(Icons.verified, size: 16),
                        label: const Text('اعتماد المراجعة'),
                      ),
                    ),
                  if (run.status == PayrollStatus.reviewed)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onLocked,
                        style: FilledButton.styleFrom(
                          backgroundColor: ZaWolfColors.warning,
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.lock, size: 16),
                        label: const Text('إغلاق الراتب'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
