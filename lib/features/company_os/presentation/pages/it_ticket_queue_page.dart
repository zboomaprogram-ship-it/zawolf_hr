import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../design_system/components/rtl_navigation.dart';
import '../../domain/entities/it_ticket.dart';
import '../../domain/repositories/it_operations_repository.dart';
import '../cubit/it_ticket_queue_cubit.dart';
import 'it_ticket_detail_page.dart';

class ItTicketQueuePage extends StatelessWidget {
  const ItTicketQueuePage({super.key, required this.repository});
  final ItOperationsRepository repository;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: BlocProvider(
      create: (_) => ItTicketQueueCubit(repository)..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('مركز دعم تقنية المعلومات')),
        body: const _QueueBody(),
      ),
    ),
  );
}

class _QueueBody extends StatelessWidget {
  const _QueueBody();
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ItTicketQueueCubit, ItTicketQueueState>(
        builder: (context, state) => switch (state) {
          ItTicketQueueLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          ItTicketQueueFailure(:final message) => _Failure(
            message: message,
            retry: context.read<ItTicketQueueCubit>().load,
          ),
          ItTicketQueueReady(:final items) when items.isEmpty => const Center(
            child: Text('لا توجد تذاكر في قائمة الدعم حالياً.'),
          ),
          ItTicketQueueReady(:final items) => RefreshIndicator(
            onRefresh: context.read<ItTicketQueueCubit>().load,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _TicketCard(ticket: items[index]),
            ),
          ),
        },
      );
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});
  final ItTicket ticket;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      key: Key('it-ticket-${ticket.id}'),
      title: Text(ticket.subject),
      subtitle: Text('${ticket.category} • ${_status(ticket.status)}'),
      trailing: ticket.isOverdue
          ? const Icon(Icons.warning_amber, semanticLabel: 'متأخرة')
          : Icon(RtlNavigation.chevronEnd(context)),
      onTap: () {
        final repo = context.read<ItTicketQueueCubit>().repository;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ItTicketDetailPage(repository: repo, ticketId: ticket.id),
          ),
        );
      },
    ),
  );
  String _status(ItTicketStatus value) => switch (value) {
    ItTicketStatus.newTicket => 'جديدة',
    ItTicketStatus.assigned => 'مسندة',
    ItTicketStatus.inProgress => 'قيد التنفيذ',
    ItTicketStatus.waitingForEmployee => 'بانتظار الموظف',
    ItTicketStatus.resolved => 'تم الحل',
    ItTicketStatus.closed => 'مغلقة',
  };
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.retry});
  final String message;
  final Future<void> Function() retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        TextButton(onPressed: retry, child: const Text('إعادة المحاولة')),
      ],
    ),
  );
}
