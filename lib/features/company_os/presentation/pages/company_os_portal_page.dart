import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/repositories/employee_portal_repository.dart';
import '../../domain/repositories/company_announcement_repository.dart';
import '../cubit/portal_summary_cubit.dart';
import '../cubit/ticket_list_cubit.dart';
import 'company_knowledge_page.dart';
import 'employee_ticket_page.dart';
import '../widgets/announcements_feed_card.dart';

class CompanyOsPortalPage extends StatelessWidget {
  const CompanyOsPortalPage({
    super.key,
    required this.repository,
    this.announcementRepository,
  });

  final EmployeePortalRepository repository;
  final CompanyAnnouncementRepository? announcementRepository;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => PortalSummaryCubit(repository)..load()),
        BlocProvider(create: (_) => TicketListCubit(repository)..load()),
      ],
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('خدمات الشركة والدعم')),
            body: RefreshIndicator(
              onRefresh: () async {
                final summary = context.read<PortalSummaryCubit>();
                final tickets = context.read<TicketListCubit>();
                await Future.wait([summary.load(), tickets.load()]);
              },
              child: ListView(
                key: const Key('company-os-portal-list'),
                padding: const EdgeInsets.all(16),
                children: [
                  _Summary(repository: repository),
                  if (announcementRepository case final repository?)
                    AnnouncementsFeedCard(repository: repository),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        key: const Key('new-ticket-button'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                EmployeeTicketPage(repository: repository),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('طلب دعم تقني'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                CompanyKnowledgePage(repository: repository),
                          ),
                        ),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('قاعدة المعرفة'),
                      ),
                      FilledButton.tonalIcon(
                        key: const Key('new-technical-operational-request'),
                        onPressed: () => context.push(
                          '/employee/requests/operational/new?category=technical',
                        ),
                        icon: const Icon(Icons.computer_outlined),
                        label: const Text('خدمات تقنية وتشغيلية'),
                      ),
                      FilledButton.tonalIcon(
                        key: const Key('new-financial-operational-request'),
                        onPressed: () => context.push(
                          '/employee/requests/operational/new?category=financial',
                        ),
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        label: const Text('مصروفات ومدفوعات الشركة'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('تذاكري', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const _TicketList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.repository});
  final EmployeePortalRepository repository;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<PortalSummaryCubit, PortalSummaryState>(
        builder: (context, state) => switch (state) {
          PortalSummaryLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          PortalSummaryFailure(:final message) => _RetryState(
            message: message,
            onRetry: context.read<PortalSummaryCubit>().load,
          ),
          PortalSummaryEmpty() => const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('لا توجد عناصر تشغيلية تحتاج متابعتك الآن.'),
            ),
          ),
          PortalSummaryReady(:final summary) => LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth > 760
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Metric(
                    width: width,
                    label: 'تذاكر مفتوحة',
                    value: summary.openTicketCount,
                  ),
                  _Metric(
                    width: width,
                    label: 'أصول مسندة',
                    value: summary.assignedAssetCount,
                  ),
                  _Metric(
                    width: width,
                    label: 'طلبات معلقة',
                    value: summary.pendingRequestCount,
                  ),
                ],
              );
            },
          ),
        },
      );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.width,
    required this.label,
    required this.value,
  });
  final double width;
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            Text(label),
          ],
        ),
      ),
    ),
  );
}

class _TicketList extends StatelessWidget {
  const _TicketList();
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<TicketListCubit, TicketListState>(
        builder: (context, state) => switch (state) {
          TicketListLoading() => const LinearProgressIndicator(),
          TicketListFailure(:final message) => _RetryState(
            message: message,
            onRetry: context.read<TicketListCubit>().load,
          ),
          TicketListReady(:final items) when items.isEmpty => const Text(
            'لم ترسل أي تذكرة بعد.',
          ),
          TicketListReady(:final items) => Column(
            children: items
                .map(
                  (ticket) => Card(
                    child: ListTile(
                      title: Text(ticket.subject),
                      subtitle: Text(ticket.category),
                      trailing: Text(ticket.status.name),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        },
      );
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    ),
  );
}
