import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/diagnostic_report.dart';
import '../cubit/diagnostics_report_cubit.dart';

final class DiagnosticsReportPage extends StatelessWidget {
  const DiagnosticsReportPage({super.key});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('تقارير سلامة النظام'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => context.read<DiagnosticsReportCubit>().load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<DiagnosticsReportCubit, DiagnosticsReportState>(
        builder: (context, state) {
          if (state.loading && state.reports.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.safeErrorCode != null && state.reports.isEmpty) {
            return _Message(
              text: 'تعذر تحميل تقرير سلامة النظام الآن.',
              action: () => context.read<DiagnosticsReportCubit>().load(),
            );
          }
          if (state.reports.isEmpty) {
            return const _Message(text: 'لا توجد مشكلات مجمعة مسجلة.');
          }
          return RefreshIndicator(
            onRefresh: () => context.read<DiagnosticsReportCubit>().load(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _ReportCard(state.reports[index]),
            ),
          );
        },
      ),
    ),
  );
}

final class _ReportCard extends StatelessWidget {
  const _ReportCard(this.report);
  final DiagnosticReport report;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Text('${report.count}')),
      title: Text('${_feature(report.feature)} · ${_code(report.safeCode)}'),
      subtitle: Text(
        'الإصدار: ${report.release}\nآخر ظهور: ${_date(report.lastSeenAt)}',
      ),
      isThreeLine: true,
    ),
  );

  String _feature(String value) => switch (value) {
    'attendance_checkin' => 'تسجيل الحضور',
    'request_visibility' => 'الطلبات',
    'sales_indicators' => 'مؤشرات المبيعات',
    'notification_operations' => 'الإشعارات',
    'required_update' => 'التحديث الإلزامي',
    'company_workspace' => 'ملفات الشركة',
    _ => 'عمليات الموظفين',
  };

  String _code(String value) => switch (value) {
    'session_expired' => 'انتهت الجلسة',
    'access_denied' => 'رفض صلاحية',
    'temporarily_unavailable' => 'الخدمة غير متاحة مؤقتاً',
    'connection_interrupted' => 'انقطع الاتصال',
    'already_submitted' => 'عملية مكررة',
    'validation_failed' => 'بيانات غير صالحة',
    'check_request_status' => 'يلزم التحقق من الحالة',
    _ => 'خطأ غير متوقع',
  };

  String _date(DateTime? value) => value == null
      ? 'غير معروف'
      : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
            '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

final class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});
  final String text;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, textAlign: TextAlign.center),
        if (action != null)
          TextButton(onPressed: action, child: const Text('إعادة المحاولة')),
      ],
    ),
  );
}
