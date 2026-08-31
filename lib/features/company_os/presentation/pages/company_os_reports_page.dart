import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/company_operations_query.dart';
import '../../domain/repositories/company_os_operations_repository.dart';
import '../cubit/company_os_reports_cubit.dart';

class CompanyOsReportsPage extends StatefulWidget {
  const CompanyOsReportsPage({super.key, required this.repository});
  final CompanyOsOperationsRepository repository;
  @override
  State<CompanyOsReportsPage> createState() => _CompanyOsReportsPageState();
}

class _CompanyOsReportsPageState extends State<CompanyOsReportsPage> {
  String _type = 'ticket';
  late final CompanyOsReportsCubit _cubit;
  @override
  void initState() {
    super.initState();
    _cubit = CompanyOsReportsCubit(widget.repository)
      ..load(_type, const CompanyOperationsFilter());
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  void _load() => _cubit.load(_type, CompanyOperationsFilter(type: _type));

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تقارير عمليات الشركة')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: 'نوع التقرير',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ticket',
                          child: Text('التذاكر'),
                        ),
                        DropdownMenuItem(value: 'asset', child: Text('الأصول')),
                        DropdownMenuItem(
                          value: 'license',
                          child: Text('التراخيص'),
                        ),
                        DropdownMenuItem(
                          value: 'request',
                          child: Text('الطلبات'),
                        ),
                        DropdownMenuItem(
                          value: 'employee',
                          child: Text('الموظفون'),
                        ),
                      ],
                      onChanged: (value) {
                        _type = value ?? 'ticket';
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _cubit.export(),
                    icon: const Icon(Icons.download),
                    label: const Text('تصدير CSV'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocConsumer<CompanyOsReportsCubit, CompanyOsReportsState>(
                listener: (context, state) {
                  if (state is CompanyOsReportsReady && state.csv != null) {
                    showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('ملف التصدير جاهز'),
                        content: SizedBox(
                          width: 640,
                          child: SingleChildScrollView(
                            child: SelectableText(state.csv!),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('إغلاق'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                builder: (context, state) => switch (state) {
                  CompanyOsReportsLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  CompanyOsReportsFailure(:final message) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SelectableText(message),
                        TextButton(
                          onPressed: _load,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                  CompanyOsReportsReady(page: final page)
                      when page.items.isEmpty =>
                    const Center(
                      child: SelectableText(
                        'لا توجد بيانات للتقرير ضمن النطاق المحدد.',
                      ),
                    ),
                  CompanyOsReportsReady(page: final page) => ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: page.items.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (_, index) {
                      final row = page.items[index];
                      return ListTile(
                        title: SelectableText('${row['title'] ?? ''}'),
                        subtitle: SelectableText(
                          '${row['safeSubtitle'] ?? ''}',
                        ),
                      );
                    },
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
