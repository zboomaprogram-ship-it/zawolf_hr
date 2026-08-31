import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/company_os_operations_repository.dart';
import '../cubit/company_os_audit_cubit.dart';

class CompanyOsAuditPage extends StatelessWidget {
  const CompanyOsAuditPage({super.key, required this.repository});
  final CompanyOsOperationsRepository repository;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => CompanyOsAuditCubit(repository)..load(),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('سجل التدقيق')),
        body: BlocBuilder<CompanyOsAuditCubit, CompanyOsAuditState>(
          builder: (context, state) => switch (state) {
            CompanyOsAuditLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            CompanyOsAuditFailure(:final message) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(message),
                  TextButton(
                    onPressed: () => context.read<CompanyOsAuditCubit>().load(),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
            CompanyOsAuditReady(page: final page) when page.items.isEmpty =>
              const Center(
                child: SelectableText(
                  'لا توجد أحداث تدقيق متاحة ضمن نطاق صلاحياتك.',
                ),
              ),
            CompanyOsAuditReady(page: final page) => ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: page.items.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (_, index) {
                final event = page.items[index];
                return Semantics(
                  label: 'حدث تدقيق ${event.action}',
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: SelectableText(
                      '${event.action} · ${event.targetType}',
                    ),
                    subtitle: SelectableText(
                      '${event.actorRole} · ${event.createdAt.toLocal()}',
                    ),
                    trailing: SelectableText(event.targetId),
                  ),
                );
              },
            ),
          },
        ),
      ),
    ),
  );
}
