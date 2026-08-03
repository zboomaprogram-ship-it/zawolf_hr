import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../components/wolf_card.dart';
import '../../services/auth_service.dart';
import '../../services/request_log_service.dart';
import '../../theme/theme.dart';
import '../../utils/csv_file_download.dart';
import '../../utils/payroll_cycle.dart';

class RequestsLogScreen extends StatefulWidget {
  const RequestsLogScreen({super.key});

  @override
  State<RequestsLogScreen> createState() => _RequestsLogScreenState();
}

class _RequestsLogScreenState extends State<RequestsLogScreen> {
  final _nameController = TextEditingController();
  late Future<List<RequestLogItem>> _logsFuture;
  String _statusFilter = 'all';
  String _typeFilter = 'all';
  String _departmentFilter = 'all';
  String _requestFilter = 'all';
  DateTime _selectedCycleDate = DateTime.now();

  PayrollCycle get _selectedCycle => PayrollCycle.forDate(_selectedCycleDate);
  bool get _isCurrentCycle =>
      _selectedCycle.key == PayrollCycle.forDate(DateTime.now()).key;

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _refreshLogs() {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    setState(() {
      _logsFuture = RequestLogService.instance.getMonthlyLogs(
        user,
        selectedCycle: _selectedCycle,
      );
    });
  }

  void _changeCycle(int monthOffset) {
    final end = _selectedCycle.end;
    final target = DateTime(end.year, end.month + monthOffset);
    _selectedCycleDate = DateTime(
      target.year,
      target.month,
      PayrollCycle.closingDay,
    );
    _refreshLogs();
  }

  List<RequestLogItem> _filtered(List<RequestLogItem> logs) {
    final name = _nameController.text.trim().toLowerCase();
    return logs.where((log) {
      final statusMatches =
          _statusFilter == 'all' ||
          (_statusFilter == 'pending' && log.isPending) ||
          log.status == _statusFilter;
      return (_typeFilter == 'all' || log.type == _typeFilter) &&
          statusMatches &&
          (_departmentFilter == 'all' || log.department == _departmentFilter) &&
          (_requestFilter == 'all' || log.requestType == _requestFilter) &&
          (name.isEmpty ||
              log.employeeName.toLowerCase().contains(name) ||
              log.employeeId.toLowerCase().contains(name));
    }).toList();
  }

  String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }

  String _createCsv(List<RequestLogItem> logs) {
    final dateFormat = intl.DateFormat('yyyy/MM/dd hh:mm a');
    final rows = <List<Object?>>[
      [
        'رقم الطلب',
        'كود الموظف',
        'اسم الموظف',
        'القسم',
        'نوع الطلب',
        'الحالة',
        'تاريخ التقديم',
        'موعد تنفيذ الطلب',
        'نهاية الطلب',
        'تاريخ الرد',
        'المراجع',
        'التفاصيل',
        'السبب',
        'الرد',
      ],
      ...logs.map(
        (item) => [
          item.id,
          item.employeeId,
          item.employeeName,
          item.department,
          item.requestType,
          item.statusLabel,
          dateFormat.format(item.submittedAt),
          item.occursAt == null ? '' : dateFormat.format(item.occursAt!),
          item.occursEndAt == null ? '' : dateFormat.format(item.occursEndAt!),
          item.reviewedAt == null ? '' : dateFormat.format(item.reviewedAt!),
          item.reviewedBy,
          item.details,
          item.reason,
          item.response,
        ],
      ),
    ];
    return rows.map((row) => row.map(_csvCell).join(',')).join('\n');
  }

  Future<void> _export(List<RequestLogItem> logs) async {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد نتائج مطابقة لتصديرها.')),
      );
      return;
    }
    final csv = _createCsv(logs);
    final fileName = 'سجل_الطلبات_${_selectedCycle.key}';
    try {
      if (await downloadCsvFile(csv, fileName)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تنزيل التقرير بنجاح.')),
        );
        return;
      }
      final file = XFile.fromData(
        Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]),
        mimeType: 'text/csv',
        name: '$fileName.csv',
      );
      await SharePlus.instance.share(
        ShareParams(files: [file], subject: fileName),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذرت المشاركة، فتم نسخ التقرير إلى الحافظة.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الطلبات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLogs,
          ),
        ],
      ),
      body: FutureBuilder<List<RequestLogItem>>(
        future: _logsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            );
          }
          if (snapshot.hasError) {
            return _ErrorState(onRetry: _refreshLogs);
          }

          final logs = snapshot.data ?? const <RequestLogItem>[];
          final departments =
              logs
                  .map((item) => item.department)
                  .where((value) => value.trim().isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          final requestTypes =
              logs.map((item) => item.requestType).toSet().toList()..sort();
          final filtered = _filtered(logs);

          return Column(
            children: [
              _CycleSelector(
                cycle: _selectedCycle,
                isCurrent: _isCurrentCycle,
                onPrevious: () => _changeCycle(-1),
                onNext: () => _changeCycle(1),
              ),
              _Filters(
                nameController: _nameController,
                type: _typeFilter,
                status: _statusFilter,
                department: departments.contains(_departmentFilter)
                    ? _departmentFilter
                    : 'all',
                requestType: requestTypes.contains(_requestFilter)
                    ? _requestFilter
                    : 'all',
                departments: departments,
                requestTypes: requestTypes,
                resultCount: filtered.length,
                onChanged:
                    ({
                      String? type,
                      String? status,
                      String? department,
                      String? requestType,
                    }) {
                      setState(() {
                        if (type != null) _typeFilter = type;
                        if (status != null) _statusFilter = status;
                        if (department != null) _departmentFilter = department;
                        if (requestType != null) _requestFilter = requestType;
                      });
                    },
                onNameChanged: (_) => setState(() {}),
                onExport: () => _export(filtered),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const _EmptyState()
                    : RefreshIndicator(
                        onRefresh: () async => _refreshLogs(),
                        color: ZaWolfColors.primaryCyan,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) =>
                              _RequestLogCard(item: filtered[index]),
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

class _CycleSelector extends StatelessWidget {
  const _CycleSelector({
    required this.cycle,
    required this.isCurrent,
    required this.onPrevious,
    required this.onNext,
  });

  final PayrollCycle cycle;
  final bool isCurrent;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: ZaWolfColors.primaryCyan.withValues(alpha: 0.1),
      child: Row(
        children: [
          IconButton(
            tooltip: 'الدورة السابقة',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_right),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'دورة ${cycle.key}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  cycle.arabicRangeLabel,
                  style: const TextStyle(
                    color: ZaWolfColors.primaryCyan,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'الدورة التالية',
            onPressed: isCurrent ? null : onNext,
            icon: const Icon(Icons.chevron_left),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.nameController,
    required this.type,
    required this.status,
    required this.department,
    required this.requestType,
    required this.departments,
    required this.requestTypes,
    required this.resultCount,
    required this.onChanged,
    required this.onNameChanged,
    required this.onExport,
  });

  final TextEditingController nameController;
  final String type;
  final String status;
  final String department;
  final String requestType;
  final List<String> departments;
  final List<String> requestTypes;
  final int resultCount;
  final void Function({
    String? type,
    String? status,
    String? department,
    String? requestType,
  })
  onChanged;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onExport;

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: ZaWolfColors.surface01,
    isDense: true,
    border: const OutlineInputBorder(),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          TextField(
            controller: nameController,
            onChanged: onNameChanged,
            decoration: _decoration('بحث بالاسم أو كود الموظف').copyWith(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: nameController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        nameController.clear();
                        onNameChanged('');
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth > 720
                  ? (constraints.maxWidth - 24) / 4
                  : (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: width,
                    child: _dropdown('نوع المجموعة', type, const {
                      'all': 'جميع الأنواع',
                      'leave': 'الإجازات',
                      'permission': 'الأذونات',
                      'advance': 'السلف',
                      'administrative': 'الطلبات الإدارية',
                      'resignation': 'الاستقالات',
                    }, (value) => onChanged(type: value)),
                  ),
                  SizedBox(
                    width: width,
                    child: _dropdown('الحالة', status, const {
                      'all': 'جميع الحالات',
                      'pending': 'قيد الانتظار',
                      'approved': 'المقبولة',
                      'rejected': 'المرفوضة',
                      'cancelled': 'الملغاة',
                    }, (value) => onChanged(status: value)),
                  ),
                  SizedBox(
                    width: width,
                    child: _dynamicDropdown(
                      'القسم',
                      department,
                      departments,
                      (value) => onChanged(department: value),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _dynamicDropdown(
                      'الطلب المحدد',
                      requestType,
                      requestTypes,
                      (value) => onChanged(requestType: value),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '$resultCount نتيجة',
                style: const TextStyle(color: ZaWolfColors.textMuted),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('تصدير النتائج'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    Map<String, String> values,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: _decoration(label),
      dropdownColor: ZaWolfColors.surface01,
      items: values.entries
          .map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  Widget _dynamicDropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> onChanged,
  ) {
    return _dropdown(label, value, {
      'all': label == 'القسم' ? 'جميع الأقسام' : 'جميع الطلبات',
      for (final item in values) item: item,
    }, onChanged);
  }
}

class _RequestLogCard extends StatelessWidget {
  const _RequestLogCard({required this.item});

  final RequestLogItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.status) {
      'approved' => ZaWolfColors.success,
      'rejected' => ZaWolfColors.error,
      'cancelled' => ZaWolfColors.textMuted,
      _ => ZaWolfColors.warning,
    };
    final dateFormat = intl.DateFormat('yyyy/MM/dd hh:mm a');
    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_typeIcon(item.type), color: ZaWolfColors.primaryCyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.requestType,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text(
                  item.statusLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.employeeName,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          Text(
            [
              if (item.employeeId.isNotEmpty) item.employeeId,
              item.department,
              item.details,
            ].join(' · '),
            style: const TextStyle(color: ZaWolfColors.textSecondary),
          ),
          if (item.reason.isNotEmpty) ...[
            const Divider(color: ZaWolfColors.surface03),
            Text(
              'السبب: ${item.reason}',
              style: const TextStyle(color: ZaWolfColors.textSecondary),
            ),
          ],
          if (item.response.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'رد المراجع: ${item.response}',
              style: TextStyle(color: color),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'تاريخ التقديم: ${dateFormat.format(item.submittedAt)}',
            style: const TextStyle(color: ZaWolfColors.textMuted, fontSize: 11),
          ),
          if (item.occursAt != null)
            Text(
              'موعد تنفيذ الطلب: ${dateFormat.format(item.occursAt!)}'
              '${item.occursEndAt == null ? '' : ' حتى ${dateFormat.format(item.occursEndAt!)}'}',
              style: const TextStyle(
                color: ZaWolfColors.primaryCyan,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textDirection: TextDirection.rtl,
            ),
          if (item.reviewedAt != null)
            Text(
              'تاريخ الرد: ${dateFormat.format(item.reviewedAt!)}'
              '${item.reviewedBy.isEmpty ? '' : ' · ${item.reviewedBy}'}',
              style: const TextStyle(
                color: ZaWolfColors.textMuted,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  IconData _typeIcon(String type) => switch (type) {
    'leave' => Icons.beach_access,
    'permission' => Icons.access_time,
    'advance' => Icons.payments_outlined,
    'administrative' => Icons.assignment_outlined,
    'resignation' => Icons.logout,
    _ => Icons.description_outlined,
  };
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.manage_search, color: ZaWolfColors.textMuted, size: 56),
          SizedBox(height: 12),
          Text(
            'لا توجد طلبات مطابقة للفلاتر.',
            style: TextStyle(color: ZaWolfColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: ZaWolfColors.error, size: 48),
          const SizedBox(height: 12),
          const Text('تعذر تحميل سجل الطلبات الآن.'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
