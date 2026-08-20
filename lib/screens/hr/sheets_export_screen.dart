import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../../components/wolf_card.dart';
import '../../models/company_workspace_models.dart';
import '../../services/google_workspace_service.dart';
import '../../theme/theme.dart';
import '../shared/workspace_sheet_editor_screen.dart';

class SheetsExportScreen extends StatefulWidget {
  const SheetsExportScreen({super.key});

  @override
  State<SheetsExportScreen> createState() => _SheetsExportScreenState();
}

class _SheetsExportScreenState extends State<SheetsExportScreen> {
  final GoogleWorkspaceService _service = GoogleWorkspaceService();
  DateTime _selectedDay = DateTime.now();
  GoogleDailyReport? _report;
  bool _loading = false;
  bool _auditLoading = false;
  String? _error;
  DateTimeRange _auditRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  WorkspaceAuditReport? _auditReport;

  Future<void> _selectDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: ZaWolfColors.primaryCyan,
            onPrimary: ZaWolfColors.background,
            surface: ZaWolfColors.surface01,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDay = picked);
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await _service.generateDailyReport(_selectedDay);
      if (!mounted) return;
      setState(() => _report = report);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ZaWolfColors.success,
          content: Text('تم تحديث ${report.rowCount} سجل في Google Sheet.'),
        ),
      );
    } on GoogleWorkspaceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر إنشاء التقرير اليومي.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSheet() async {
    final url = _report?.spreadsheetUrl ?? '';
    if (url.isEmpty || !await launchUrl(Uri.parse(url))) {
      if (mounted) {
        setState(
          () =>
              _error = 'تعذر فتح جدول التقارير. تحقق من صلاحية Google للحساب.',
        );
      }
    }
  }

  Future<void> _selectAuditRange() async {
    final value = await showDateRangePicker(
      context: context,
      initialDateRange: _auditRange,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (value != null) setState(() => _auditRange = value);
  }

  Future<void> _generateAuditReport() async {
    setState(() {
      _auditLoading = true;
      _error = null;
    });
    try {
      final report = await _service.generateWorkspaceAuditReport(
        startDate: _auditRange.start,
        endDate: _auditRange.end,
      );
      if (!mounted) return;
      setState(() => _auditReport = report);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث ${report.rowCount} عملية في سجل التدقيق.'),
        ),
      );
    } on GoogleWorkspaceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر إنشاء سجل التدقيق.');
    } finally {
      if (mounted) setState(() => _auditLoading = false);
    }
  }

  Future<void> _openAuditReport() async {
    final report = _auditReport;
    if (report == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkspaceSheetEditorScreen(
          resource: CompanyWorkspaceResource(
            id: report.resourceId,
            name: report.name,
            type: 'sheet',
            department: 'التقارير',
            description: 'سجل تدقيق Workspace',
            hasExternalId: true,
            schemaProfileId: '',
            sheetTab: report.sheetTab,
            managerIds: const [],
            isActive: true,
            syncStatus: 'connected',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat('yyyy/MM/dd', 'ar').format(_selectedDay);
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير اليومية')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('سجل تدقيق Workspace', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'ينشئ Google Sheet داخل مجلد 04_التقارير ويجمع العرض والتعديل والتنزيل وتغييرات الصفوف والأعمدة والصلاحيات.',
            ),
            const SizedBox(height: 12),
            WolfCard(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _auditLoading ? null : _selectAuditRange,
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      '${DateFormat('yyyy/MM/dd').format(_auditRange.start)} — ${DateFormat('yyyy/MM/dd').format(_auditRange.end)}',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _auditLoading ? null : _generateAuditReport,
                    icon: const Icon(Icons.history_outlined),
                    label: const Text('إنشاء أو تحديث سجل التدقيق'),
                  ),
                  if (_auditReport != null)
                    OutlinedButton.icon(
                      onPressed: _openAuditReport,
                      icon: const Icon(Icons.table_view_outlined),
                      label: Text('فتح السجل (${_auditReport!.rowCount})'),
                    ),
                ],
              ),
            ),
            if (_auditLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 24),
            Text('تقرير تشغيلي مباشر', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'اختر يوماً واحداً. يجمع النظام الحضور والانصراف والتأخير والإجازات والأذونات في صفحة Google Sheet واحدة، ويحدّث صفحة اليوم نفسها عند إعادة الإنشاء.',
            ),
            const SizedBox(height: 16),
            WolfCard(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _selectDay,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(dateLabel),
                  ),
                  FilledButton.icon(
                    onPressed: _loading ? null : _generate,
                    icon: const Icon(Icons.table_view_outlined),
                    label: const Text('إنشاء أو تحديث Google Sheet'),
                  ),
                  if (_report != null)
                    OutlinedButton.icon(
                      onPressed: _openSheet,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('فتح جدول التقرير'),
                    ),
                ],
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              WolfCard(
                child: Text(
                  _error!,
                  style: const TextStyle(color: ZaWolfColors.error),
                ),
              ),
            if (_report != null) ...[
              const SizedBox(height: 16),
              Text(
                '${_report!.tabTitle} · ${_report!.rowCount} موظف',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ..._report!.preview
                  .take(100)
                  .map(
                    (row) => WolfCard(
                      child: ListTile(
                        title: Text(row.length > 2 ? '${row[2]}' : 'موظف'),
                        subtitle: Text(
                          row.length > 4
                              ? '${row[3]} · ${row[4]} · حضور ${row.length > 5 ? row[5] : '-'} · انصراف ${row.length > 6 ? row[6] : '-'}'
                              : '',
                        ),
                        trailing: Text(
                          row.length > 7 ? 'تأخير ${row[7]} د' : '',
                        ),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}
