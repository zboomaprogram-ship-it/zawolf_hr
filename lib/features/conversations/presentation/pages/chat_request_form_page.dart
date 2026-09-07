import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';
import '../cubit/chat_requests_cubit.dart';
import '../widgets/chat_feedback.dart';
import 'chat_user_picker_page.dart';

class ChatRequestFormPage extends StatefulWidget {
  const ChatRequestFormPage({super.key, required this.repository, this.request, this.canReview = false});
  final RichChatRepository repository;
  final ChannelRequest? request;
  final bool canReview;
  @override
  State<ChatRequestFormPage> createState() => _ChatRequestFormPageState();
}
class _ChatRequestFormPageState extends State<ChatRequestFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _reason;
  late final ChatRequestFormCubit _cubit;
  bool get _editable => widget.request == null || (widget.canReview && widget.request!.status == 'pending');
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.request?.name ?? '');
    _reason = TextEditingController(text: widget.request?.reason ?? '');
    _cubit = ChatRequestFormCubit(widget.repository, widget.request?.memberUserIds ?? [widget.repository.actorId]);
  }
  Future<void> _submit({String decision = 'approved', String? rejectionReason}) async {
    if (decision == 'approved' && !_form.currentState!.validate()) return;
    final result = await _cubit.submit(name: _name.text, reason: _reason.text, request: widget.request, decision: decision, rejectionReason: rejectionReason, canReview: widget.canReview);
    if (result != null && mounted) Navigator.pop(context, result);
  }
  Future<void> _reject() async {
    final controller = TextEditingController();
    final form = GlobalKey<FormState>();
    final reason = await showDialog<String>(context: context, builder: (context) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(title: const Text('سبب رفض الطلب'), content: Form(key: form, child: TextFormField(controller: controller, maxLength: 1000, minLines: 2, maxLines: 5, validator: (value) => (value ?? '').trim().isEmpty ? 'أدخل سبب الرفض' : null)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(context, controller.text.trim()); }, child: const Text('رفض الطلب'))])));
    controller.dispose();
    if (reason != null) await _submit(decision: 'rejected', rejectionReason: reason);
  }
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(appBar: AppBar(title: Text(widget.request == null ? (widget.canReview ? 'إنشاء قناة جديدة — HR' : 'طلب قناة جديدة') : widget.canReview ? 'مراجعة طلب القناة' : 'تفاصيل طلب القناة')), body: BlocBuilder<ChatRequestFormCubit, ChatRequestFormState>(bloc: _cubit, builder: (context, state) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: ListView(padding: const EdgeInsets.all(20), children: [
    const ChatFeedback(text: 'بعد موافقة HR، يمكن للأعضاء والموارد البشرية قراءة القناة ومرفقاتها. الأعضاء الجدد يمكنهم قراءة سجل الرسائل.'),
    const SizedBox(height: 20),
    if (widget.request != null) Text('حالة الطلب: ${chatRequestStatus(widget.request!.status)}', style: Theme.of(context).textTheme.titleMedium),
    if (widget.request?.rejectionReason != null) ChatFeedback(text: 'سبب الرفض: ${widget.request!.rejectionReason}'),
    Form(key: _form, child: Column(children: [
      TextFormField(controller: _name, enabled: _editable && !state.busy, maxLength: 120, decoration: const InputDecoration(labelText: 'اسم القناة'), validator: (value) => (value ?? '').trim().isEmpty ? 'أدخل اسم القناة' : null),
      const SizedBox(height: 12),
      TextFormField(controller: _reason, enabled: widget.request == null && !state.busy, maxLength: 1000, minLines: 3, maxLines: 6, decoration: InputDecoration(labelText: widget.canReview ? 'غرض القناة' : 'سبب إنشاء القناة'), validator: (value) => (value ?? '').trim().isEmpty ? 'أدخل سبب الطلب' : null),
    ])),
    const SizedBox(height: 16),
    OutlinedButton.icon(onPressed: !_editable || state.busy ? null : () async {
      final selected = await pickChatUsers(context, widget.repository, selected: state.members, locked: {widget.request?.requesterId ?? widget.repository.actorId});
      if (selected != null) _cubit.members(selected);
    }, icon: const Icon(Icons.group_add_outlined), label: Text('اختيار الزملاء (${state.members.length}/100)')),
    const Text('من عضوين إلى 100 عضو، بما في ذلك صاحب الطلب.'),
    Wrap(spacing: 8, children: state.members.map((member) => Chip(label: Text(member == widget.repository.actorId ? 'أنت' : member))).toList()),
    if (state.error != null) ChatFeedback(text: chatErrorText(state.error!)),
    if (state.busy) const LinearProgressIndicator(),
    const SizedBox(height: 20),
    if (_editable) Wrap(spacing: 12, runSpacing: 12, children: [
      FilledButton.icon(onPressed: state.busy ? null : _submit, icon: Icon(widget.request == null ? (widget.canReview ? Icons.add_circle_outline : Icons.send) : Icons.check), label: Text(widget.request == null ? (widget.canReview ? 'إنشاء القناة مباشرة' : 'إرسال الطلب إلى HR') : 'الموافقة وإنشاء القناة')),
      if (widget.request != null) OutlinedButton.icon(onPressed: state.busy ? null : _reject, icon: const Icon(Icons.close), label: const Text('رفض مع السبب')),
    ]),
  ]))))));
  @override
  void dispose() { _name.dispose(); _reason.dispose(); _cubit.close(); super.dispose(); }
}

String chatRequestStatus(String status) => switch (status) {'pending' => 'قيد مراجعة HR', 'approved' => 'تمت الموافقة', 'rejected' => 'مرفوض', _ => status};
