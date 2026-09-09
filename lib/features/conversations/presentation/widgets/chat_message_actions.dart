import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';
import '../cubit/chat_action_cubit.dart';
import '../cubit/chat_inbox_cubit.dart';
import 'chat_feedback.dart';

Future<void> showChatMessageActions(
  BuildContext context, {
  required RichChatRepository repository,
  required RichMessage message,
  required bool canPost,
  required bool canReview,
  required List<ChatReader> readers,
  required void Function(RichMessage) onReply,
  required ChatActionCubit actions,
}) async {
  final selected = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder:
        (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!message.isDeleted && message.body.isNotEmpty)
                    _option(context, 'copy', 'نسخ النص', Icons.copy),
                  if (canPost &&
                      !message.isDeleted &&
                      message.syncState == ChatSyncState.synced) ...[
                    _option(context, 'reply', 'رد', Icons.reply),
                    _option(
                      context,
                      'react',
                      'تفاعل',
                      Icons.add_reaction_outlined,
                    ),
                    _option(context, 'forward', 'إعادة توجيه', Icons.forward),
                    if (message.canEdit(
                      repository.actorId,
                      DateTime.now(),
                    )) ...[
                      _option(context, 'edit', 'تعديل', Icons.edit_outlined),
                      _option(
                        context,
                        'delete',
                        'حذف لدى الجميع',
                        Icons.delete_outline,
                      ),
                    ],
                  ],
                  if (message.syncState == ChatSyncState.synced)
                    _option(
                      context,
                      'readers',
                      'معلومات المشاهدة',
                      Icons.done_all,
                    ),
                  if (canReview && message.syncState == ChatSyncState.synced)
                    _option(
                      context,
                      'audit',
                      'سجل تعديلات الرسالة',
                      Icons.history,
                    ),
                ],
              ),
            ),
          ),
        ),
  );
  if (!context.mounted || selected == null) return;
  switch (selected) {
    case 'copy':
      await Clipboard.setData(ClipboardData(text: message.body));
    case 'reply':
      onReply(message);
    case 'react':
      final emoji = await showDialog<String>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('اختر تفاعلاً'),
              content: SizedBox(
                width: 360,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children:
                      const [
                        '👍',
                        '❤️',
                        '😂',
                        '😮',
                        '😢',
                        '🙏',
                        '🎉',
                        '👏',
                        '🔥',
                        '💯',
                        '✅',
                        '👀',
                        '🤝',
                        '💡',
                        '🚀',
                        '❗',
                      ].map((emoji) => _ReactionButton(emoji)).toList(),
                ),
              ),
            ),
      );
      if (emoji != null) await actions.execute(message, 'react', emoji: emoji);
    case 'edit':
      final body = await _editText(context, message.body);
      if (body != null) await actions.execute(message, 'edit', body: body);
    case 'delete':
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('حذف الرسالة لدى الجميع؟'),
              content: const Text(
                'سيظهر مكانها إشعار بالحذف، ويُحتفظ بسجل المراجعة لدى HR.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('حذف'),
                ),
              ],
            ),
      );
      if (confirmed == true) await actions.execute(message, 'delete');
    case 'forward':
      final destination = await Navigator.push<RichChannel>(
        context,
        MaterialPageRoute(
          builder: (_) => _ForwardPicker(repository: repository),
        ),
      );
      if (destination != null)
        await actions.execute(
          message,
          'forward',
          destinationId: destination.id,
        );
    case 'readers':
      final viewed =
          readers
              .where(
                (reader) =>
                    reader.userId != message.senderUserId &&
                    (reader.messageId == message.id ||
                        (reader.sentAt != null &&
                            !reader.sentAt!.isBefore(message.sentAt))),
              )
              .toList();
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('شاهد الرسالة'),
              content: SizedBox(
                width: 400,
                child:
                    viewed.isEmpty
                        ? const Text('لم يشاهدها أحد بعد')
                        : ListView(
                          shrinkWrap: true,
                          children:
                              viewed
                                  .map(
                                    (reader) => ListTile(
                                      title: Text(
                                        reader.name.isEmpty
                                            ? reader.userId
                                            : reader.name,
                                      ),
                                      subtitle: Text(
                                        '${reader.readAt.toLocal()}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
              ),
            ),
      );
    case 'audit':
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('سجل التعديلات — HR'),
              content: SizedBox(
                width: 500,
                child: FutureBuilder<List<Map<String, Object?>>>(
                  future: repository.audit(message.conversationId, message.id),
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return Text(chatErrorText(snapshot.error.toString()));
                    if (!snapshot.hasData)
                      return const SizedBox(
                        height: 64,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    if (snapshot.data!.isEmpty)
                      return const Text('لا توجد تعديلات');
                    return ListView(
                      shrinkWrap: true,
                      children:
                          snapshot.data!
                              .map(
                                (entry) => ListTile(
                                  title: Text(
                                    '${entry['body'] ?? entry['action'] ?? 'تعديل'}',
                                  ),
                                  subtitle: Text(
                                    '${entry['createdAt'] ?? entry['at'] ?? ''}',
                                  ),
                                ),
                              )
                              .toList(),
                    );
                  },
                ),
              ),
            ),
      );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton(this.emoji);
  final String emoji;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: emoji,
    onPressed: () => Navigator.pop(context, emoji),
    icon: Text(emoji, style: const TextStyle(fontSize: 27)),
  );
}

Widget _option(
  BuildContext context,
  String action,
  String label,
  IconData icon,
) => ListTile(
  leading: Icon(icon),
  title: Text(label),
  onTap: () => Navigator.pop(context, action),
);

Future<String?> _editText(BuildContext context, String initial) async {
  final controller = TextEditingController(text: initial);
  final form = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder:
        (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تعديل الرسالة'),
            content: Form(
              key: form,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                maxLength: 4000,
                minLines: 2,
                maxLines: 6,
                validator:
                    (value) =>
                        (value ?? '').length > 4000
                            ? 'الحد الأقصى 4000 حرف'
                            : null,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  if (form.currentState!.validate())
                    Navigator.pop(context, controller.text);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
  );
  controller.dispose();
  return result;
}

class _ForwardPicker extends StatelessWidget {
  const _ForwardPicker({required this.repository});
  final RichChatRepository repository;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ChatInboxCubit(repository),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إعادة التوجيه إلى')),
        body: BlocBuilder<ChatInboxCubit, ChatInboxState>(
          builder:
              (context, state) => Column(
                children: [
                  if (state.loading) const LinearProgressIndicator(),
                  if (state.error != null)
                    ChatFeedback(
                      text: chatErrorText(state.error!),
                      onRetry: () => context.read<ChatInboxCubit>().load(),
                    ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final channel in state.channels.where(
                          (channel) => channel.canPost,
                        ))
                          ListTile(
                            leading: const Icon(Icons.forum_outlined),
                            title: Text(channel.name),
                            onTap: () => Navigator.pop(context, channel),
                          ),
                        if (!state.loading &&
                            state.channels
                                .where((channel) => channel.canPost)
                                .isEmpty)
                          const ListTile(
                            title: Text('لا توجد جروبات متاحة للإرسال'),
                          ),
                        if (state.cursor != null)
                          TextButton(
                            onPressed:
                                state.loading
                                    ? null
                                    : () => context.read<ChatInboxCubit>().load(
                                      more: true,
                                    ),
                            child: const Text('تحميل المزيد'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
        ),
      ),
    ),
  );
}
