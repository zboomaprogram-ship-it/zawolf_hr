import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/repositories/company_os_operations_repository.dart';
import '../cubit/company_operations_dashboard_cubit.dart';

class CompanyOperationsDashboardPage extends StatelessWidget {
  const CompanyOperationsDashboardPage({super.key, required this.repository});
  final CompanyOsOperationsRepository repository;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => CompanyOperationsDashboardCubit(repository)..load(),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مركز عمليات الشركة')),
        body:
            BlocBuilder<
              CompanyOperationsDashboardCubit,
              CompanyOperationsDashboardState
            >(
              builder: (context, state) => switch (state) {
                CompanyOperationsDashboardLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                CompanyOperationsDashboardFailure(:final message) =>
                  _RetryState(
                    message: message,
                    onRetry: () =>
                        context.read<CompanyOperationsDashboardCubit>().load(),
                  ),
                CompanyOperationsDashboardReady(:final value) => LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900
                        ? 4
                        : constraints.maxWidth >= 560
                        ? 2
                        : 1;
                    final cards = <(String, int, IconData)>[
                      ('تذاكر مفتوحة', value.openTickets, Icons.support_agent),
                      ('أصول مسندة', value.assignedAssets, Icons.devices_other),
                      ('تراخيص نشطة', value.expiringLicenses, Icons.key),
                      (
                        'طلبات معلقة',
                        value.pendingRequests,
                        Icons.pending_actions,
                      ),
                    ];
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        SelectableText('النطاق المطبق: ${value.scope}'),
                        const SizedBox(height: 12),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: columns,
                          childAspectRatio: 2.2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          children: [
                            for (final card in cards)
                              _MetricCard(
                                label: card.$1,
                                value: card.$2,
                                icon: card.$3,
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: () =>
                                  context.push('/company-os/operations/search'),
                              icon: const Icon(Icons.search),
                              label: const Text('البحث الشامل'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.push(
                                '/company-os/operations/reports',
                              ),
                              icon: const Icon(Icons.summarize),
                              label: const Text('التقارير والتصدير'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  context.push('/company-os/operations/audit'),
                              icon: const Icon(Icons.history),
                              label: const Text('سجل التدقيق'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              },
            ),
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final int value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Text('$value', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    ),
  );
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectableText(message),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
      ],
    ),
  );
}
