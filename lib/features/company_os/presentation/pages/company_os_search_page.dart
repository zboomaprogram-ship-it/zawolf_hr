import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/company_operations_query.dart';
import '../../domain/repositories/company_os_operations_repository.dart';
import '../cubit/company_os_search_cubit.dart';

class CompanyOsSearchPage extends StatefulWidget {
  const CompanyOsSearchPage({super.key, required this.repository});
  final CompanyOsOperationsRepository repository;
  @override
  State<CompanyOsSearchPage> createState() => _CompanyOsSearchPageState();
}

class _CompanyOsSearchPageState extends State<CompanyOsSearchPage> {
  final _query = TextEditingController();
  String _type = 'ticket';
  late final CompanyOsSearchCubit _cubit;
  @override
  void initState() {
    super.initState();
    _cubit = CompanyOsSearchCubit(widget.repository)
      ..search(const CompanyOperationsFilter());
  }

  @override
  void dispose() {
    _query.dispose();
    _cubit.close();
    super.dispose();
  }

  void _search() =>
      _cubit.search(CompanyOperationsFilter(type: _type, query: _query.text));

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('البحث في عمليات الشركة')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final queryField = TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      labelText: 'كلمة البحث',
                      prefixIcon: Icon(Icons.search),
                    ),
                  );
                  final typeField = SizedBox(
                    width: constraints.maxWidth >= 620 ? 220 : double.infinity,
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'نوع السجل'),
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
                      onChanged: (value) =>
                          setState(() => _type = value ?? 'ticket'),
                    ),
                  );
                  final button = FilledButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.search),
                    label: const Text('بحث'),
                  );
                  return constraints.maxWidth >= 620
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: queryField),
                            const SizedBox(width: 12),
                            typeField,
                            const SizedBox(width: 12),
                            button,
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            queryField,
                            const SizedBox(height: 12),
                            typeField,
                            const SizedBox(height: 12),
                            button,
                          ],
                        );
                },
              ),
            ),
            Expanded(
              child: BlocBuilder<CompanyOsSearchCubit, CompanyOsSearchState>(
                builder: (context, state) => switch (state) {
                  CompanyOsSearchLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  CompanyOsSearchFailure(:final message, :final filter) =>
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SelectableText(message),
                          TextButton(
                            onPressed: () => _cubit.search(filter),
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  CompanyOsSearchReady(page: final page)
                      when page.items.isEmpty =>
                    const Center(
                      child: SelectableText('لا توجد نتائج ضمن نطاق صلاحياتك.'),
                    ),
                  CompanyOsSearchReady(page: final page) => ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: page.items.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = page.items[index];
                      return ListTile(
                        title: SelectableText(item.title),
                        subtitle: SelectableText(item.safeSubtitle),
                        leading: const Icon(Icons.description_outlined),
                        onTap: item.route.isEmpty
                            ? null
                            : () => context.push(item.route),
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
