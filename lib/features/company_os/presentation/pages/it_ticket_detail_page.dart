import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/it_ticket.dart';
import '../../domain/repositories/it_operations_repository.dart';
import '../cubit/it_ticket_workflow_cubit.dart';

class ItTicketDetailPage extends StatelessWidget {
  const ItTicketDetailPage({
    super.key,
    required this.repository,
    required this.ticketId,
  });
  final ItOperationsRepository repository;
  final String ticketId;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: BlocProvider(
      create: (_) => ItTicketWorkflowCubit(repository),
      child: Scaffold(
        appBar: AppBar(title: const Text('تفاصيل تذكرة الدعم')),
        body: FutureBuilder<ItTicket>(
          future: repository.ticket(ticketId),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('تعذر تحميل التذكرة.'));
            }
            return _TicketDetails(
              ticket: snapshot.data!,
              repository: repository,
            );
          },
        ),
      ),
    ),
  );
}

class _TicketDetails extends StatelessWidget {
  const _TicketDetails({required this.ticket, required this.repository});
  final ItTicket ticket;
  final ItOperationsRepository repository;
  @override
  Widget build(BuildContext context) =>
      BlocListener<ItTicketWorkflowCubit, ItTicketWorkflowState>(
        listener: (context, state) {
          if (state case ItTicketWorkflowFailure(:final message)) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              ticket.subject,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(ticket.description),
            const Divider(height: 32),
            const Text('المحتوى العام — يظهر للموظف'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: ticket.status == ItTicketStatus.newTicket
                      ? () => _assign(context)
                      : null,
                  child: const Text('إسناد التذكرة'),
                ),
                FilledButton(
                  onPressed: ticket.status == ItTicketStatus.assigned
                      ? () => _transition(context, ItTicketStatus.inProgress)
                      : null,
                  child: const Text('بدء التنفيذ'),
                ),
                FilledButton(
                  onPressed: ticket.status == ItTicketStatus.inProgress
                      ? () => _transition(context, ItTicketStatus.resolved)
                      : null,
                  child: const Text('تم الحل'),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('ملاحظات IT الخاصة — لا تظهر للموظف'),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _privateNote(context),
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('إضافة ملاحظة خاصة'),
              ),
            ),
            FutureBuilder(
              future: repository.privateNotes(ticket.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final notes = snapshot.data!.items;
                return Column(
                  children: notes
                      .map(
                        (n) => ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: Text(n.body),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      );
  Future<void> _assign(BuildContext context) async {
    final controller = TextEditingController();
    final uid = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إسناد التذكرة'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'معرّف موظف IT'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('إسناد'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (uid != null && uid.isNotEmpty && context.mounted) {
      await context.read<ItTicketWorkflowCubit>().assign(
        ticket,
        uid,
        _operation('assign'),
      );
    }
  }

  Future<void> _privateNote(BuildContext context) async {
    final controller = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ملاحظة خاصة بفريق IT'),
        content: TextField(controller: controller, maxLines: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (body != null && body.isNotEmpty && context.mounted) {
      await context.read<ItTicketWorkflowCubit>().privateNote(
        ticket,
        body,
        _operation('private-note'),
      );
    }
  }

  void _transition(BuildContext context, ItTicketStatus status) =>
      context.read<ItTicketWorkflowCubit>().transition(
        ticket,
        status,
        _operation(status.name),
        resolution: status == ItTicketStatus.resolved
            ? 'تم الحل بواسطة فريق IT'
            : null,
      );
  String _operation(String action) =>
      'it-${ticket.id}-$action-${DateTime.now().microsecondsSinceEpoch}';
}
