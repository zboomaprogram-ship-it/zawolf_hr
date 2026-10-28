import 'package:flutter/material.dart';

import '../../../models/user_model.dart';
import '../../../theme/theme.dart';

/// Modal dialog for HR administrators to assign one or multiple recurring remote
/// work days to an employee without writing any code or JSON.
/// Pure UI component with dependency-injected loading and persistence.
class AssignRemoteDaysDialog extends StatefulWidget {
  final Map<String, dynamic> eligibility;
  final Future<List<UserModel>> Function() loadEmployees;
  final Future<void> Function(String employeeId, List<int> remoteDays) onSave;

  const AssignRemoteDaysDialog({
    super.key,
    required this.eligibility,
    required this.loadEmployees,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> eligibility,
    required Future<List<UserModel>> Function() loadEmployees,
    required Future<void> Function(String employeeId, List<int> remoteDays) onSave,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AssignRemoteDaysDialog(
        eligibility: eligibility,
        loadEmployees: loadEmployees,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AssignRemoteDaysDialog> createState() => _AssignRemoteDaysDialogState();
}

class _AssignRemoteDaysDialogState extends State<AssignRemoteDaysDialog> {
  bool _loadingEmployees = true;
  bool _saving = false;
  String? _errorMessage;
  List<UserModel> _employees = [];
  UserModel? _selectedEmployee;
  List<int> _selectedDays = [];

  static const Map<int, String> _weekdayLabels = {
    7: 'الأحد',
    1: 'الاثنين',
    2: 'الثلاثاء',
    3: 'الأربعاء',
    4: 'الخميس',
    5: 'الجمعة',
    6: 'السبت',
  };

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    try {
      final list = await widget.loadEmployees();
      if (mounted) {
        setState(() {
          _employees = list;
          _loadingEmployees = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingEmployees = false;
          _errorMessage = 'تعذر تحميل قائمة الموظفين.';
        });
      }
    }
  }

  void _onEmployeeSelected(UserModel? emp) {
    if (emp == null) return;
    setState(() {
      _selectedEmployee = emp;
      _selectedDays = List<int>.from(
        emp.workSchedule.remoteWorkDays ?? const [],
      );
      _errorMessage = null;
    });
  }

  Future<void> _handleSave() async {
    final emp = _selectedEmployee;
    if (emp == null) {
      setState(() => _errorMessage = 'يرجى اختيار الموظف أولاً.');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final days = List<int>.from(_selectedDays)..sort();
      await widget.onSave(emp.uid, days);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.success,
            content: Text(
              'تم حفظ وتعيين أيام العمل عن بُعد بنجاح للموظف ${emp.displayName}.',
              textDirection: TextDirection.rtl,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = 'حدث خطأ أثناء حفظ أيام العمل عن بُعد: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allowedWeekdays =
        (widget.eligibility['allowedWeekdays'] as List?)
            ?.whereType<num>()
            .map((e) => e.toInt())
            .toList() ??
        const [7, 1, 2, 3, 4];

    final maxDaysPerWeek =
        (widget.eligibility['daysPerWeek'] as num?)?.toInt() ?? 2;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: ZaWolfColors.surface01,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ZaWolfColors.surface03),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ZaWolfColors.primaryCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.home_work_outlined,
                        color: ZaWolfColors.primaryCyan,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تعيين جدول العمل عن بُعد للموظف',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'حدد الموظف وأيام العمل عن بُعد المعتمدة له أسبوعياً',
                            style: TextStyle(
                              color: ZaWolfColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: ZaWolfColors.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ZaWolfColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ZaWolfColors.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: ZaWolfColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Employee Selection
                if (_loadingEmployees)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: ZaWolfColors.primaryCyan,
                      ),
                    ),
                  )
                else ...[
                  DropdownButtonFormField<UserModel>(
                    initialValue: _selectedEmployee,
                    decoration: InputDecoration(
                      labelText: 'اختر الموظف',
                      prefixIcon: const Icon(
                        Icons.person_search_outlined,
                        color: ZaWolfColors.primaryCyan,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items:
                        _employees.map((emp) {
                          final codeStr =
                              emp.employeeId.isNotEmpty
                                  ? ' (${emp.employeeId})'
                                  : '';
                          return DropdownMenuItem<UserModel>(
                            value: emp,
                            child: Text(
                              '${emp.displayName}$codeStr',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                    onChanged: _saving ? null : _onEmployeeSelected,
                  ),
                  const SizedBox(height: 20),

                  if (_selectedEmployee != null) ...[
                    // Policy Allowance Info
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: ZaWolfColors.surface02.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ZaWolfColors.surface03),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 16,
                                color: ZaWolfColors.primaryCyan,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'الحد الأقصى في السياسة: $maxDaysPerWeek أيام / أسبوع',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _selectedDays.length <= maxDaysPerWeek
                                      ? ZaWolfColors.primaryCyan.withValues(
                                        alpha: 0.2,
                                      )
                                      : ZaWolfColors.warning.withValues(
                                        alpha: 0.2,
                                      ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'المحدد: ${_selectedDays.length} يوم',
                              style: TextStyle(
                                color:
                                    _selectedDays.length <= maxDaysPerWeek
                                        ? ZaWolfColors.primaryCyan
                                        : ZaWolfColors.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Weekdays Chips
                    Text(
                      'اختر أيام العمل عن بُعد:',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          allowedWeekdays.map((dayNum) {
                            final label = _weekdayLabels[dayNum] ?? 'يوم $dayNum';
                            final selected = _selectedDays.contains(dayNum);
                            return FilterChip(
                              avatar:
                                  selected
                                      ? const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: ZaWolfColors.primaryCyan,
                                      )
                                      : null,
                              label: Text(label),
                              selected: selected,
                              selectedColor: ZaWolfColors.primaryCyan.withValues(
                                alpha: 0.25,
                              ),
                              checkmarkColor: ZaWolfColors.primaryCyan,
                              onSelected:
                                  _saving
                                      ? null
                                      : (enabled) {
                                        setState(() {
                                          if (enabled) {
                                            _selectedDays.add(dayNum);
                                          } else {
                                            _selectedDays.remove(dayNum);
                                          }
                                        });
                                      },
                            );
                          }).toList(),
                    ),

                    if (_selectedDays.length > maxDaysPerWeek) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: ZaWolfColors.warning,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'تنبيه: عدد الأيام المحددة (${_selectedDays.length}) يتجاوز الحد الأقصى للسياسة ($maxDaysPerWeek أيام). يُنصح بزيادة الحد في سياسة الدوام أولاً.',
                              style: const TextStyle(
                                color: ZaWolfColors.warning,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],

                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _saving ? null : () => Navigator.of(context).pop(),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZaWolfColors.primaryCyan,
                          foregroundColor: Colors.black,
                        ),
                        onPressed:
                            (_saving || _selectedEmployee == null)
                                ? null
                                : _handleSave,
                        icon:
                            _saving
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                                : const Icon(Icons.check, size: 18),
                        label: Text(
                          _saving
                              ? 'جارٍ الحفظ...'
                              : 'حفظ جدول العمل عن بُعد',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
