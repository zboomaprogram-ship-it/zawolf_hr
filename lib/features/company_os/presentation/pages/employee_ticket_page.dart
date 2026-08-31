import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/it_ticket.dart';
import '../../domain/repositories/employee_portal_repository.dart';
import '../../domain/use_cases/submit_it_ticket.dart';
import '../cubit/ticket_submit_cubit.dart';

class EmployeeTicketPage extends StatefulWidget {
  const EmployeeTicketPage({super.key, required this.repository});
  final EmployeePortalRepository repository;

  @override
  State<EmployeeTicketPage> createState() => _EmployeeTicketPageState();
}

class _EmployeeTicketPageState extends State<EmployeeTicketPage> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  late final String _operationId =
      'ticket:${DateTime.now().toUtc().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => TicketSubmitCubit(SubmitItTicket(widget.repository)),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تذكرة دعم تقني')),
        body: BlocConsumer<TicketSubmitCubit, TicketSubmitState>(
          listener: (context, state) {
            if (state.message != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message!)));
            }
          },
          builder: (context, state) => Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  key: const Key('ticket-subject'),
                  controller: _subject,
                  decoration: const InputDecoration(labelText: 'عنوان المشكلة'),
                  validator: (value) => (value?.trim().length ?? 0) < 3
                      ? 'اكتب عنواناً واضحاً.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('ticket-description'),
                  controller: _description,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'وصف المشكلة'),
                  validator: (value) => (value?.trim().length ?? 0) < 5
                      ? 'أضف تفاصيل تساعد فريق الدعم.'
                      : null,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('ticket-submit'),
                  onPressed: state.status == TicketSubmitStatus.submitting
                      ? null
                      : () {
                          if (!_formKey.currentState!.validate()) return;
                          context.read<TicketSubmitCubit>().submit(
                            operationId: _operationId,
                            subject: _subject.text,
                            description: _description.text,
                            category: 'other',
                            priority: ItTicketPriority.medium,
                          );
                        },
                  child: Text(
                    state.status == TicketSubmitStatus.submitting
                        ? 'جارٍ الإرسال…'
                        : 'إرسال التذكرة',
                  ),
                ),
                if (state.status == TicketSubmitStatus.pendingSync)
                  const ListTile(
                    key: Key('ticket-pending'),
                    leading: Icon(Icons.sync),
                    title: Text('بانتظار تأكيد المزامنة'),
                  ),
                if (state.status == TicketSubmitStatus.saved)
                  const ListTile(
                    key: Key('ticket-saved'),
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('تم حفظ التذكرة'),
                  ),
                if (state.status == TicketSubmitStatus.conflict)
                  const ListTile(
                    key: Key('ticket-conflict'),
                    leading: Icon(Icons.warning_amber),
                    title: Text('تغيرت البيانات. حدّث الصفحة ثم أعد المحاولة.'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
