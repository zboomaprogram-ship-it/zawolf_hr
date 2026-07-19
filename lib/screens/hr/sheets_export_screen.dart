import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';
import '../../services/sheets_export_service.dart';
import '../../models/attendance_model.dart';
import '../../models/leave_model.dart';
import '../../models/permission_model.dart';
import '../../models/performance_model.dart';
import '../../models/payroll_run_model.dart';
import '../../models/user_model.dart';
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';
import '../../components/wolf_button.dart';
import '../../utils/payroll_cycle.dart';

class SheetsExportScreen extends StatefulWidget {
  const SheetsExportScreen({super.key});

  @override
  State<SheetsExportScreen> createState() => _SheetsExportScreenState();
}

class _SheetsExportScreenState extends State<SheetsExportScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SheetsExportService _sheetsExportService = SheetsExportService();

  DateTime _selectedMonth = PayrollCycle.forDate(DateTime.now()).end;
  bool _isExporting = false;
  String _exportStatus = '';

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: ZaWolfColors.primaryCyan,
              onPrimary: ZaWolfColors.background,
              surface: ZaWolfColors.surface01,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = picked;
      });
    }
  }

  Future<void> _shareCsvFile(String csv, String fileName) async {
    try {
      final file = XFile.fromData(
        Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]),
        mimeType: 'text/csv',
        name: '$fileName.csv',
      );
      await SharePlus.instance.share(
        ShareParams(files: [file], subject: fileName),
      );
    } catch (e) {
      // Fallback to clipboard
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: ZaWolfColors.warning,
          content: Text(
            'تعذرت المشاركة — تم نسخ البيانات للحافظة بدلاً من ذلك.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ZaWolfColors.success,
        content: Text('تم تجهيز ملف $fileName.csv — افتحه في Google Sheets.'),
      ),
    );
  }

  Future<void> _exportAttendance() async {
    setState(() {
      _isExporting = true;
      _exportStatus = 'جاري جلب سجلات الحضور والغياب...';
    });

    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);
    final cycle = PayrollCycle.forKey(monthKey);

    try {
      final logsSnap = await _db
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: cycle.startDateKey)
          .where('date', isLessThan: cycle.nextStartDateKey)
          .get();

      final logs = logsSnap.docs
          .map((doc) => AttendanceModel.fromFirestore(doc))
          .toList();

      if (logs.isEmpty) {
        throw Exception('لا توجد سجلات حضور لهذا الشهر ($monthKey).');
      }

      setState(() => _exportStatus = 'جاري تجهيز ملف CSV...');

      final csv = await _sheetsExportService.exportAttendanceToSheet(
        'attendance_$monthKey',
        logs,
      );
      await _shareCsvFile(csv, 'حضور_$monthKey');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text(
              'فشل التصدير: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportStatus = '';
        });
      }
    }
  }

  Future<void> _exportLeaves() async {
    setState(() {
      _isExporting = true;
      _exportStatus = 'جاري جلب سجلات الإجازات...';
    });

    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);
    final cycle = PayrollCycle.forKey(monthKey);
    try {
      final leavesSnap = await _db.collection('leaves').get();
      final leaves = leavesSnap.docs
          .map((doc) => LeaveModel.fromFirestore(doc))
          .where(
            (leave) =>
                !leave.startDate.isAfter(cycle.end) &&
                !leave.endDate.isBefore(cycle.start),
          )
          .toList();

      if (leaves.isEmpty) {
        throw Exception('لا توجد إجازات مسجلة لتصديرها.');
      }

      setState(() => _exportStatus = 'جاري تجهيز ملف CSV...');

      final csv = await _sheetsExportService.exportLeavesToSheet(
        'leaves_$monthKey',
        leaves,
      );
      await _shareCsvFile(csv, 'اجازات_$monthKey');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text(
              'فشل التصدير: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportStatus = '';
        });
      }
    }
  }

  Future<void> _exportPermissions() async {
    setState(() {
      _isExporting = true;
      _exportStatus = 'جاري جلب سجلات الأذونات...';
    });

    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);

    try {
      final snap = await _db
          .collection('permissions')
          .where('monthKey', isEqualTo: monthKey)
          .get();

      final list = snap.docs
          .map((doc) => PermissionModel.fromFirestore(doc))
          .toList();

      if (list.isEmpty) {
        throw Exception('لا توجد أذونات مسجلة لهذا الشهر ($monthKey).');
      }

      setState(() => _exportStatus = 'جاري تجهيز ملف CSV...');

      final csv = await _sheetsExportService.exportPermissionsToSheet(
        'permissions_$monthKey',
        list,
      );
      await _shareCsvFile(csv, 'اذونات_$monthKey');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text(
              'فشل التصدير: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportStatus = '';
        });
      }
    }
  }

  Future<void> _exportPerformance() async {
    setState(() {
      _isExporting = true;
      _exportStatus = 'جاري جلب تقييمات الأداء...';
    });

    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);

    try {
      final snap = await _db
          .collection('performance')
          .where('monthKey', isEqualTo: monthKey)
          .get();

      final list = snap.docs
          .map((doc) => PerformanceModel.fromFirestore(doc))
          .toList();

      if (list.isEmpty) {
        throw Exception('لا توجد تقييمات أداء لهذا الشهر ($monthKey).');
      }

      setState(() => _exportStatus = 'جاري تجهيز ملف CSV...');

      final csv = await _sheetsExportService.exportPerformanceToSheet(
        'performance_$monthKey',
        list,
      );
      await _shareCsvFile(csv, 'اداء_$monthKey');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text(
              'فشل التصدير: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportStatus = '';
        });
      }
    }
  }

  Future<void> _exportEmployees() async {
    setState(() {
      _isExporting = true;
      _exportStatus = 'جاري جلب بيانات الموظفين...';
    });

    try {
      final snap = await _db.collection('users').get();
      final employees = snap.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      if (employees.isEmpty) {
        throw Exception('لا يوجد موظفون مسجلون لتصديرهم.');
      }

      setState(() => _exportStatus = 'جاري تجهيز ملف CSV...');

      final csv = await _sheetsExportService.exportEmployeesToSheet(
        'employees',
        employees,
      );
      await _shareCsvFile(csv, 'بيانات_الموظفين');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text(
              'فشل التصدير: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportStatus = '';
        });
      }
    }
  }

  Future<void> _exportPayroll() async {
    setState(() {
      _isExporting = true;
      _exportStatus = 'جاري جلب كشوف الرواتب...';
    });

    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);

    try {
      final snap = await _db
          .collection('payrollRuns')
          .where('monthKey', isEqualTo: monthKey)
          .get();

      final list = snap.docs
          .map((doc) => PayrollRunModel.fromFirestore(doc))
          .toList();

      if (list.isEmpty) {
        throw Exception('لا توجد كشوف رواتب لهذا الشهر ($monthKey).');
      }

      setState(() => _exportStatus = 'جاري تجهيز ملف CSV...');

      final csv = await _sheetsExportService.exportPayrollToSheet(
        'payroll_$monthKey',
        list,
      );
      await _shareCsvFile(csv, 'رواتب_$monthKey');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ZaWolfColors.error,
            content: Text(
              'فشل التصدير: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthStr = DateFormat('yyyy-MM').format(_selectedMonth);

    return Scaffold(
      appBar: AppBar(
        title: Text('تصدير التقارير', style: theme.textTheme.headlineMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تصدير كشوف العمل والتقييمات',
              style: theme.textTheme.titleLarge!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 4),
            Text(
              'دورة التقارير من يوم 26 إلى يوم 25. يتم تجهيز ملف CSV للمشاركة أو التنزيل.',
              style: theme.textTheme.bodyMedium,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 24),

            // Date Picker Month Card
            WolfCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => _selectMonth(context),
                    icon: const Icon(
                      Icons.calendar_today,
                      color: ZaWolfColors.primaryCyan,
                      size: 18,
                    ),
                    label: Text(
                      monthStr,
                      style: const TextStyle(
                        color: ZaWolfColors.primaryCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    'دورة التقارير · ${PayrollCycle.forKey(monthStr).arabicRangeLabel}',
                    style: theme.textTheme.titleMedium!.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Loading Indicator
            if (_isExporting) ...[
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      color: ZaWolfColors.primaryCyan,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _exportStatus,
                      style: const TextStyle(
                        color: ZaWolfColors.primaryCyan,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Export Buttons Grid
            _buildExportSection(
              title: 'تقارير شهرية',
              icon: Icons.date_range,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: WolfButton(
                        onPressed: _isExporting ? null : _exportAttendance,
                        text: 'الحضور',
                        secondaryText: 'ATTENDANCE',
                        height: 52,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WolfButton(
                        onPressed: _isExporting ? null : _exportPermissions,
                        text: 'الأذونات',
                        secondaryText: 'PERMISSIONS',
                        variant: WolfButtonVariant.teal,
                        height: 52,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: WolfButton(
                        onPressed: _isExporting ? null : _exportPerformance,
                        text: 'تقييم الأداء',
                        secondaryText: 'PERFORMANCE',
                        variant: WolfButtonVariant.purple,
                        height: 52,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WolfButton(
                        onPressed: _isExporting ? null : _exportPayroll,
                        text: 'كشوف الرواتب',
                        secondaryText: 'PAYROLL',
                        variant: WolfButtonVariant.outline,
                        height: 52,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            _buildExportSection(
              title: 'تقارير عامة',
              icon: Icons.people_outline,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: WolfButton(
                        onPressed: _isExporting ? null : _exportLeaves,
                        text: 'الإجازات',
                        secondaryText: 'LEAVES',
                        variant: WolfButtonVariant.outline,
                        height: 52,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WolfButton(
                        onPressed: _isExporting ? null : _exportEmployees,
                        text: 'بيانات الموظفين',
                        secondaryText: 'EMPLOYEES',
                        height: 52,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: ZaWolfColors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: ZaWolfColors.textMuted, size: 18),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}
