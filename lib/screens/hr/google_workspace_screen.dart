import 'package:flutter/material.dart';

import '../../components/wolf_card.dart';
import '../../services/google_workspace_service.dart';
import '../../theme/theme.dart';
import '../../utils/binary_file_action.dart';

class GoogleWorkspaceScreen extends StatefulWidget {
  const GoogleWorkspaceScreen({super.key});

  @override
  State<GoogleWorkspaceScreen> createState() => _GoogleWorkspaceScreenState();
}

class _GoogleWorkspaceScreenState extends State<GoogleWorkspaceScreen> {
  final GoogleWorkspaceService _service = GoogleWorkspaceService();
  List<Map<String, dynamic>> _rows = const [];
  List<Map<String, dynamic>> _files = const [];
  bool _loading = false;
  String? _activeFileId;
  String _sheetQuery = '';
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } on GoogleWorkspaceException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.statusCode == 401
              ? 'تعذر التحقق من جلسة الدخول مع الخادم. أعد المحاولة، وإذا استمر الخطأ راجع حالة خدمة Hostinger.'
              : error.message;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تنفيذ العملية حالياً.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _readSheets() => _run(() async {
    final rows = await _service.readSheetRows();
    if (mounted) setState(() => _rows = rows);
  });

  Future<void> _readDrive() => _run(() async {
    final files = await _service.listDriveFiles();
    if (mounted) setState(() => _files = files);
  });

  Future<void> _createDriveFile() => _run(() async {
    await _service.createDriveTestFile();
    final files = await _service.listDriveFiles();
    if (mounted) setState(() => _files = files);
  });

  Future<void> _editRow(Map<String, dynamic> row) async {
    final formKey = GlobalKey<FormState>();
    final taskController = TextEditingController(
      text: '${row['task_name'] ?? ''}',
    );
    final amountController = TextEditingController(
      text: '${row['amount'] ?? ''}',
    );
    final notesController = TextEditingController(
      text: '${row['notes'] ?? ''}',
    );
    var status = '${row['status'] ?? 'pending'}';
    if (!const ['pending', 'in_progress', 'completed'].contains(status)) {
      status = 'pending';
    }
    final update = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'تعديل ${row['record_id']}',
            textDirection: TextDirection.rtl,
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: taskController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(labelText: 'المهمة'),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'اسم المهمة مطلوب.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'الحالة'),
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('معلق')),
                        DropdownMenuItem(
                          value: 'in_progress',
                          child: Text('قيد التنفيذ'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('مكتمل'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setDialogState(() => status = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'القيمة'),
                      validator: (value) {
                        final amount = num.tryParse((value ?? '').trim());
                        return amount == null || amount < 0
                            ? 'أدخل قيمة صحيحة لا تقل عن صفر.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 5,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(labelText: 'ملاحظات'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(dialogContext, {
                  'taskName': taskController.text.trim(),
                  'status': status,
                  'amount': num.parse(amountController.text.trim()),
                  'notes': notesController.text.trim(),
                });
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ في Google Sheet'),
            ),
          ],
        ),
      ),
    );
    taskController.dispose();
    amountController.dispose();
    notesController.dispose();
    if (update == null) return;
    await _run(() async {
      final updated = await _service.updateTestRow(
        '${row['record_id']}',
        taskName: update['taskName'] as String,
        status: update['status'] as String,
        amount: update['amount'] as num,
        notes: update['notes'] as String,
      );
      if (!mounted) return;
      setState(() {
        _rows = [
          for (final current in _rows)
            if (current['record_id'] == updated['record_id'])
              updated
            else
              current,
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التعديلات في Google Sheet.')),
      );
    });
  }

  Future<void> _openDriveFile(
    Map<String, dynamic> file, {
    required bool download,
  }) async {
    final id = '${file['id'] ?? ''}';
    final name = '${file['name'] ?? 'download'}';
    final mimeType = '${file['mimeType'] ?? 'application/octet-stream'}';
    final preparedView = download ? null : prepareBinaryView();
    setState(() => _activeFileId = id);
    try {
      await _run(() async {
        final payload = await _service.downloadDriveFile(
          id,
          fileName: name,
          mimeType: mimeType,
        );
        final handled = download
            ? await downloadBinaryFile(
                payload.bytes,
                payload.fileName,
                payload.mimeType,
              )
            : await viewBinaryFile(
                payload.bytes,
                payload.fileName,
                payload.mimeType,
                preparedView: preparedView,
              );
        if (!handled) {
          throw const GoogleWorkspaceException(
            400,
            'فتح الملفات متاح حالياً من نسخة الويب.',
          );
        }
      });
    } finally {
      if (mounted) setState(() => _activeFileId = null);
    }
  }

  String _statusLabel(Object? status) => switch ('$status') {
    'completed' => 'مكتمل',
    'in_progress' => 'قيد التنفيذ',
    _ => 'معلق',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleRows = _rows.where((row) {
      final query = _sheetQuery.trim().toLowerCase();
      if (query.isEmpty) return true;
      return row.values.any((value) => '$value'.toLowerCase().contains(query));
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Google Workspace')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'مساحة عمل Google الخاصة',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'تقرأ وتعدّل الملفات من خلال النظام. لا تظهر مفاتيح Google أو روابط الملفات الأصلية.',
            ),
            const SizedBox(height: 16),
            if (_error != null)
              WolfCard(
                child: Text(
                  _error!,
                  style: const TextStyle(color: ZaWolfColors.error),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _loading ? null : _readSheets,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تحديث بيانات Sheets'),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : _readDrive,
                  icon: const Icon(Icons.folder_outlined),
                  label: const Text('تحديث ملفات Drive'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _createDriveFile,
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('إنشاء ملف اختبار'),
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 16),
            if (_rows.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'صفوف Sheets (${visibleRows.length})',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const Icon(Icons.table_chart_outlined),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => setState(() => _sheetQuery = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'بحث في جميع بيانات الجدول',
                ),
              ),
              const SizedBox(height: 8),
              ...visibleRows.map(
                (row) => WolfCard(
                  child: ListTile(
                    title: Text(
                      '${row['record_id']} · ${row['employee_name'] ?? ''}',
                    ),
                    subtitle: Text(
                      '${row['task_name'] ?? ''}\n${_statusLabel(row['status'])} · ${row['notes'] ?? ''}',
                    ),
                    isThreeLine: true,
                    leading: IconButton(
                      tooltip: 'تعديل الصف',
                      onPressed: _loading ? null : () => _editRow(row),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    trailing: Text('${row['amount'] ?? ''}'),
                  ),
                ),
              ),
            ],
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ملفات Drive (${_files.length})',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const Icon(Icons.folder_copy_outlined),
                ],
              ),
              const SizedBox(height: 8),
              ..._files.map((file) {
                final id = '${file['id'] ?? ''}';
                final busy = _activeFileId == id;
                final isFolder =
                    file['mimeType'] == 'application/vnd.google-apps.folder';
                return WolfCard(
                  child: ListTile(
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text('${file['name'] ?? ''}'),
                    subtitle: Text('${file['mimeType'] ?? ''}'),
                    trailing: busy
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'عرض داخل المتصفح',
                                onPressed: isFolder
                                    ? null
                                    : () =>
                                          _openDriveFile(file, download: false),
                                icon: const Icon(Icons.visibility_outlined),
                              ),
                              IconButton(
                                tooltip: 'تنزيل الملف',
                                onPressed: isFolder
                                    ? null
                                    : () =>
                                          _openDriveFile(file, download: true),
                                icon: const Icon(Icons.download_outlined),
                              ),
                            ],
                          ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
