import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../services/sheets_export_service.dart';
import '../../models/attendance_model.dart';
import '../../models/leave_model.dart';
import '../../models/permission_model.dart';
import '../../models/performance_model.dart';
import '../../theme/theme.dart';
import '../../components/wolf_card.dart';
import '../../components/wolf_button.dart';

class SheetsExportScreen extends StatefulWidget {
  const SheetsExportScreen({super.key});

  @override
  State<SheetsExportScreen> createState() => _SheetsExportScreenState();
}

class _SheetsExportScreenState extends State<SheetsExportScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SheetsExportService _sheetsExportService = SheetsExportService();

  DateTime _selectedMonth = DateTime.now();
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

  Future<void> _copyCsvExport(String csv, String reportName) async {
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ZaWolfColors.success,
        content: Text(
          'تم إنشاء ملف CSV لتقرير $reportName ونسخه للحافظة. يمكنك لصقه في Google Sheets.',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _exportAttendance() async {
    setState(() {
      _isExporting = true;
      _exportStatus = 'جاري جلب سجلات الحضور والغياب من قاعدة البيانات...';
    });

    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);

    try {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final nextMonth = month == 12 ? 1 : month + 1;
      final nextYear = month == 12 ? year + 1 : year;
      final nextMonthStr =
          '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01';

      // 1. Fetch attendance logs for selected month
      final logsSnap = await _db
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: '$monthKey-01')
          .where('date', isLessThan: nextMonthStr)
          .get();

      final logs = logsSnap.docs
          .map((doc) => AttendanceModel.fromFirestore(doc))
          .toList();

      if (logs.isEmpty) {
        throw Exception('لا توجد سجلات حضور مسجلة لهذا الشهر ($monthKey).');
      }

      setState(() {
        _exportStatus = 'جاري تجهيز ملف CSV آمن بدون مفاتيح خدمة...';
      });

      final csv = await _sheetsExportService.exportAttendanceToSheet(
        'attendance_$monthKey',
        logs,
      );
      await _copyCsvExport(csv, 'الحضور والانصراف');
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
      _exportStatus = 'جاري جلب سجلات الإجازات من قاعدة البيانات...';
    });

    try {
      // 1. Fetch all leaves logs
      final leavesSnap = await _db.collection('leaves').get();
      final leaves = leavesSnap.docs
          .map((doc) => LeaveModel.fromFirestore(doc))
          .toList();

      if (leaves.isEmpty) {
        throw Exception('لا توجد إجازات مسجلة في قاعدة البيانات لتصديرها.');
      }

      setState(() {
        _exportStatus = 'جاري تجهيز ملف CSV آمن بدون مفاتيح خدمة...';
      });

      final csv = await _sheetsExportService.exportLeavesToSheet(
        'leaves',
        leaves,
      );
      await _copyCsvExport(csv, 'الإجازات');
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
      _exportStatus = 'جاري جلب سجلات الأذونات من قاعدة البيانات...';
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

      setState(() {
        _exportStatus = 'جاري تجهيز ملف CSV آمن بدون مفاتيح خدمة...';
      });

      final csv = await _sheetsExportService.exportPermissionsToSheet(
        'permissions_$monthKey',
        list,
      );
      await _copyCsvExport(csv, 'الأذونات الشخصية');
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
      _exportStatus = 'جاري جلب تقييمات الأداء من قاعدة البيانات...';
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
        throw Exception('لا توجد تقييمات أداء منشورة لهذا الشهر ($monthKey).');
      }

      setState(() {
        _exportStatus = 'جاري تجهيز ملف CSV آمن بدون مفاتيح خدمة...';
      });

      final csv = await _sheetsExportService.exportPerformanceToSheet(
        'performance_$monthKey',
        list,
      );
      await _copyCsvExport(csv, 'تقييم الأداء');
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
              'تصدير كشوف العمل والتقييمات CSV',
              style: theme.textTheme.titleLarge!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 4),
            Text(
              'يتم إنشاء CSV محلياً ونسخه للحافظة حتى لا يتم تضمين مفاتيح Google Service Account داخل التطبيق.',
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
                    'شهر التقارير المستهدف',
                    style: theme.textTheme.titleMedium!.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Loading Indicators
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

            // Export Action Buttons Grid
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: WolfButton(
                        onPressed: _isExporting ? null : _exportAttendance,
                        text: 'تصدير الحضور',
                        secondaryText: 'EXPORT ATTENDANCE',
                        height: 52,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WolfButton(
                        onPressed: _isExporting ? null : _exportLeaves,
                        text: 'تصدير الإجازات',
                        secondaryText: 'EXPORT LEAVES',
                        variant: WolfButtonVariant.outline,
                        height: 52,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: WolfButton(
                        onPressed: _isExporting ? null : _exportPermissions,
                        text: 'تصدير الأذونات',
                        secondaryText: 'EXPORT PERMISSIONS',
                        variant: WolfButtonVariant.teal,
                        height: 52,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WolfButton(
                        onPressed: _isExporting ? null : _exportPerformance,
                        text: 'تصدير الأداء',
                        secondaryText: 'EXPORT PERFORMANCE',
                        variant: WolfButtonVariant.purple,
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
}
