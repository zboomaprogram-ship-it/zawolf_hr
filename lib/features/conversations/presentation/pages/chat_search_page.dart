import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';
import '../cubit/chat_search_cubit.dart';
import '../widgets/chat_feedback.dart';

class ChatSearchPage extends StatelessWidget {
  const ChatSearchPage({
    super.key,
    required this.repository,
    required this.channelId,
    required this.attachmentBuilder,
  });
  final RichChatRepository repository;
  final String channelId;
  final Widget Function(BuildContext, RichAttachment) attachmentBuilder;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ChatSearchCubit(repository, channelId),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('البحث في رسائل الجروب')),
        body: BlocBuilder<ChatSearchCubit, ChatSearchState>(
          builder:
              (context, state) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'كلمة أو عبارة',
                            prefixIcon: Icon(Icons.search),
                            helperText: 'اضغط إدخال للبحث',
                          ),
                          onSubmitted:
                              (query) =>
                                  context.read<ChatSearchCubit>().search(query),
                        ),
                      ),
                      if (state.offline)
                        const ChatFeedback(
                          text:
                              'نتائج من الرسائل المحفوظة على هذا الجهاز فقط — غير متصل',
                        ),
                      if (state.error != null)
                        ChatFeedback(
                          text: chatErrorText(state.error!),
                          onRetry:
                              () => context.read<ChatSearchCubit>().search(
                                state.query,
                              ),
                        ),
                      if (state.loading) const LinearProgressIndicator(),
                      Expanded(
                        child: ListView(
                          children: [
                            if (state.messages.isEmpty && !state.loading)
                              ListTile(
                                title: Text(
                                  state.query.isEmpty
                                      ? 'ابحث في سجل المحادثة'
                                      : state.complete
                                      ? 'لا توجد نتائج'
                                      : 'لا توجد نتائج في هذا الجزء من السجل',
                                ),
                              ),
                            for (final message in state.messages)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message.senderDisplayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SelectableText(
                                        message.isDeleted
                                            ? 'تم حذف الرسالة'
                                            : message.body,
                                      ),
                                      if (!message.isDeleted)
                                        ...message.attachments.map(
                                          (attachment) => attachmentBuilder(
                                            context,
                                            attachment,
                                          ),
                                        ),
                                      Text(
                                        '${message.sentAt.toLocal()}',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (state.cursor != null)
                              TextButton(
                                onPressed:
                                    state.loading
                                        ? null
                                        : () => context
                                            .read<ChatSearchCubit>()
                                            .search(state.query, more: true),
                                child: const Text(
                                  'متابعة البحث في الرسائل الأقدم',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ),
    ),
  );
}
