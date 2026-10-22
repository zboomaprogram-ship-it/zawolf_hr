import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../models/productivity_score_model.dart';
import '../../models/user_model.dart';
import '../../services/department_report_service.dart';
import '../../theme/theme.dart';
import '../../utils/payroll_cycle.dart';

enum ExportScope { allDepartments, singleDepartment, singleEmployee }
enum ExportPeriodType { cycleToNow, fullCycle, customRange }

Future<void> showPerformanceExportDialog(
  BuildContext context, {
  required List<ProductivityScoreModel> scores,
  required UserModel reviewer,
  String? initialDepartment,
  String? initialEmployeeId,
  String? monthKey,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _PerformanceExportDialog(
      scores: scores,
      reviewer: reviewer,
      initialDepartment: initialDepartment,
      initialEmployeeId: initialEmployeeId,
      monthKey: monthKey,
    ),
  );
}

class _PerformanceExportDialog extends StatefulWidget {
  const _PerformanceExportDialog({
    required this.scores,
    required this.reviewer,
    this.initialDepartment,
    this.initialEmployeeId,
    this.monthKey,
  });

  final List<ProductivityScoreModel> scores;
  final UserModel reviewer;
  final String? initialDepartment;
  final String? initialEmployeeId;
  final String? monthKey;

  @override
  State<_PerformanceExportDialog> createState() =>
      _PerformanceExportDialogState();
}

class _PerformanceExportDialogState extends State<_PerformanceExportDialog> {
  late ExportScope _scope;
  late String _selectedDepartment;
  late String _selectedEmployeeId;
  ExportPeriodType _periodType = ExportPeriodType.cycleToNow;

  late PayrollCycle _cycle;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _cycle = widget.monthKey != null && widget.monthKey!.isNotEmpty
        ? PayrollCycle.forKey(widget.monthKey!)
        : PayrollCycle.forDate(now);

    final departments = _getDepartments();
    if (widget.initialDepartment != null &&
        departments.contains(widget.initialDepartment)) {
      _selectedDepartment = widget.initialDepartment!;
      _scope = ExportScope.singleDepartment;
    } else {
      _selectedDepartment =
          departments.isNotEmpty ? departments.first : 'عام';
      _scope = ExportScope.allDepartments;
    }

    if (widget.initialEmployeeId != null &&
        widget.scores.any((s) => s.employeeId == widget.initialEmployeeId)) {
      _selectedEmployeeId = widget.initialEmployeeId!;
      _scope = ExportScope.singleEmployee;
    } else {
      _selectedEmployeeId =
          widget.scores.isNotEmpty ? widget.scores.first.employeeId : '';
    }

    _applyPeriodType(ExportPeriodType.cycleToNow);
  }

  List<String> _getDepartments() {
    final depts = widget.scores
        .map((s) => s.department.trim().isEmpty ? 'غير محدد' : s.department)
        .toSet()
        .toList()
      ..sort();
    return depts;
  }

  void _applyPeriodType(ExportPeriodType type) {
    final now = DateTime.now();
    setState(() {
      _periodType = type;
      switch (type) {
        case ExportPeriodType.cycleToNow:
          _startDate = _cycle.start;
          _endDate = now;
          break;
        case ExportPeriodType.fullCycle:
          _startDate = _cycle.start;
          _endDate = _cycle.end;
          break;
        case ExportPeriodType.customRange:
          // Kept as user selects
          break;
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: ZaWolfColors.primaryCyan,
              surface: ZaWolfColors.surface01,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _periodType = ExportPeriodType.customRange;
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  List<ProductivityScoreModel> _getScopedScores() {
    switch (_scope) {
      case ExportScope.allDepartments:
        return widget.scores;
      case ExportScope.singleDepartment:
        return widget.scores.where((s) {
          final dept =
              s.department.trim().isEmpty ? 'غير محدد' : s.department;
          return dept == _selectedDepartment;
        }).toList();
      case ExportScope.singleEmployee:
        return widget.scores
            .where((s) => s.employeeId == _selectedEmployeeId)
            .toList();
    }
  }

  String _getExportFileName() {
    final formatter = intl.DateFormat('yyyyMMdd');
    final startStr = formatter.format(_startDate);
    final endStr = formatter.format(_endDate);

    switch (_scope) {
      case ExportScope.allDepartments:
        return 'تقرير_الأداء_جميع_الأقسام_${startStr}_$endStr';
      case ExportScope.singleDepartment:
        final safeDept =
            _selectedDepartment.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        return 'تقرير_أداء_قسم_${safeDept}_${startStr}_$endStr';
      case ExportScope.singleEmployee:
        final emp = widget.scores
            .firstWhere((s) => s.employeeId == _selectedEmployeeId,
                orElse: () => widget.scores.first);
        final safeName =
            emp.employeeName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        return 'تقرير_أداء_${emp.employeeId}_${safeName}_${startStr}_$endStr';
    }
  }

  String _getPeriodLabel() {
    final formatter = intl.DateFormat('yyyy/MM/dd');
    return 'من ${formatter.format(_startDate)} إلى ${formatter.format(_endDate)}';
  }

  Future<void> _handleExport() async {
    final targets = _getScopedScores();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات مطابقة للتصدير.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final detailsMap =
          await DepartmentReportService.instance.loadDepartmentDetails(
        scores: targets,
        reviewer: widget.reviewer,
        startDate: _startDate,
        endDate: _endDate,
        monthKey: widget.monthKey,
      );

      final detailsList = detailsMap.values.toList();
      final fileName = _getExportFileName();
      final periodLabel = _getPeriodLabel();

      final success = await DepartmentReportService.instance.exportReport(
        details: detailsList,
        periodLabel: periodLabel,
        exportFileName: fileName,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.surface02,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: ZaWolfColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم تنزيل تقرير الأداء بنجاح ($periodLabel).',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تنزيل التقرير. يرجى إعادة المحاولة.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء إعداد التقرير: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final departments = _getDepartments();
    final formatter = intl.DateFormat('yyyy/MM/dd');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: ZaWolfColors.surface01,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 540,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ZaWolfColors.primaryCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.file_download_outlined,
                      color: ZaWolfColors.primaryCyan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تصدير تقرير الأداء والأقسام',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'تحميل تقرير شامل بالخصومات، الغياب، الطلبات، ونسب الأداء بصيغة Excel / CSV',
                          style: TextStyle(
                            color: ZaWolfColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: ZaWolfColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: ZaWolfColors.surface03),
              const SizedBox(height: 12),

              // 1. SCOPE SELECTION
              const Text(
                'نطاق التقرير:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('جميع الأقسام'),
                    selected: _scope == ExportScope.allDepartments,
                    onSelected: (val) {
                      if (val) setState(() => _scope = ExportScope.allDepartments);
                    },
                    selectedColor: ZaWolfColors.primaryCyan,
                    labelStyle: TextStyle(
                      color: _scope == ExportScope.allDepartments
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('قسم محدد'),
                    selected: _scope == ExportScope.singleDepartment,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _scope = ExportScope.singleDepartment);
                      }
                    },
                    selectedColor: ZaWolfColors.primaryCyan,
                    labelStyle: TextStyle(
                      color: _scope == ExportScope.singleDepartment
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('موظف محدد'),
                    selected: _scope == ExportScope.singleEmployee,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _scope = ExportScope.singleEmployee);
                      }
                    },
                    selectedColor: ZaWolfColors.primaryCyan,
                    labelStyle: TextStyle(
                      color: _scope == ExportScope.singleEmployee
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Scope dropdown if needed
              if (_scope == ExportScope.singleDepartment) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedDepartment,
                  dropdownColor: ZaWolfColors.surface02,
                  decoration: InputDecoration(
                    labelText: 'اختر القسم',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  items: departments.map((d) {
                    final count = widget.scores
                        .where((s) =>
                            (s.department.trim().isEmpty
                                ? 'غير محدد'
                                : s.department) ==
                            d)
                        .length;
                    return DropdownMenuItem(
                      value: d,
                      child: Text('$d ($count موظف)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDepartment = val);
                  },
                ),
                const SizedBox(height: 14),
              ] else if (_scope == ExportScope.singleEmployee) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedEmployeeId,
                  dropdownColor: ZaWolfColors.surface02,
                  decoration: InputDecoration(
                    labelText: 'اختر الموظف',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  items: widget.scores.map((s) {
                    return DropdownMenuItem(
                      value: s.employeeId,
                      child: Text('${s.employeeName} (${s.employeeId})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedEmployeeId = val);
                  },
                ),
                const SizedBox(height: 14),
              ],

              const SizedBox(height: 10),

              // 2. PERIOD SELECTION
              const Text(
                'فترة التقرير:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('من بداية الدورة حتى الآن'),
                    selected: _periodType == ExportPeriodType.cycleToNow,
                    onSelected: (val) {
                      if (val) _applyPeriodType(ExportPeriodType.cycleToNow);
                    },
                    selectedColor: ZaWolfColors.primaryCyan,
                    labelStyle: TextStyle(
                      color: _periodType == ExportPeriodType.cycleToNow
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('دورة رواتب كاملة'),
                    selected: _periodType == ExportPeriodType.fullCycle,
                    onSelected: (val) {
                      if (val) _applyPeriodType(ExportPeriodType.fullCycle);
                    },
                    selectedColor: ZaWolfColors.primaryCyan,
                    labelStyle: TextStyle(
                      color: _periodType == ExportPeriodType.fullCycle
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('فترة مخصصة...'),
                    selected: _periodType == ExportPeriodType.customRange,
                    onSelected: (val) {
                      if (val) _pickCustomRange();
                    },
                    selectedColor: ZaWolfColors.primaryCyan,
                    labelStyle: TextStyle(
                      color: _periodType == ExportPeriodType.customRange
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Date range preview badge / picker
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: ZaWolfColors.surface02,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ZaWolfColors.surface03),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 20,
                      color: ZaWolfColors.primaryCyan,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'الفترة المحددة: ${formatter.format(_startDate)} ⟵ ${formatter.format(_endDate)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickCustomRange,
                      child: const Text('تغيير التواريخ'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. ACTIONS
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isExporting ? null : () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ZaWolfColors.primaryCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _isExporting ? null : _handleExport,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(
                      _isExporting
                          ? 'جارٍ إعداد التقرير وتنزيله…'
                          : 'تنزيل التقرير (Excel / CSV)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
