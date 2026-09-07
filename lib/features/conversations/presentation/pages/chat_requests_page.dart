import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';
import '../cubit/chat_requests_cubit.dart';
import '../widgets/chat_feedback.dart';
import 'chat_request_form_page.dart';

class ChatRequestsPage extends StatelessWidget {
  const ChatRequestsPage({super.key, required this.repository, required this.canReview, required this.openChannel});
  final RichChatRepository repository;
  final bool canReview;
  final void Function(BuildContext, RichChannel) openChannel;
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChatRequestsCubit(repository)..load(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(canReview ? 'طلبات القنوات — HR' : 'طلبات القنوات الخاصة بي'),
              actions: [
                IconButton(
                  tooltip: 'تحديث',
                  onPressed: () => context.read<ChatRequestsCubit>().load(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push<ChannelRequest>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatRequestFormPage(repository: repository, canReview: canReview),
                  ),
                );
                if (context.mounted) {
                  await context.read<ChatRequestsCubit>().load();
                }
              },
              icon: const Icon(Icons.add),
              label: Text(canReview ? 'إنشاء / طلب قناة' : 'طلب قناة'),
            ),
            body: BlocBuilder<ChatRequestsCubit, ChatRequestsState>(
              builder: (context, state) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      if (state.loading) const LinearProgressIndicator(),
                      if (state.error != null)
                        ChatFeedback(
                          text: chatErrorText(state.error!),
                          onRetry: () => context.read<ChatRequestsCubit>().load(),
                        ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 96),
                          children: [
                            if (state.requests.isEmpty && !state.loading)
                              const ListTile(title: Text('لا توجد طلبات قنوات حتى الآن')),
                            for (final request in state.requests)
                              Card(
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: Icon(
                                        request.status == 'approved'
                                            ? Icons.check_circle_outline
                                            : request.status == 'rejected'
                                                ? Icons.cancel_outlined
                                                : Icons.pending_actions,
                                      ),
                                      title: Text(request.name),
                                      subtitle: Text('${chatRequestStatus(request.status)}\n${request.reason}'),
                                      isThreeLine: true,
                                      trailing: const Icon(
                                        Icons.chevron_left,
                                        textDirection: TextDirection.ltr,
                                      ),
                                      onTap: () async {
                                        await Navigator.push<ChannelRequest>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ChatRequestFormPage(
                                              repository: repository,
                                              request: request,
                                              canReview: canReview,
                                            ),
                                          ),
                                        );
                                        if (context.mounted) {
                                          await context.read<ChatRequestsCubit>().load();
                                        }
                                      },
                                    ),
                                    if (request.conversationId != null && request.status == 'approved')
                                      TextButton.icon(
                                        onPressed: () => openChannel(
                                          context,
                                          RichChannel(
                                            id: request.conversationId!,
                                            name: request.name,
                                            memberUserIds: request.memberUserIds,
                                            canPost: request.memberUserIds.contains(repository.actorId),
                                            hrReadable: true,
                                          ),
                                        ),
                                        icon: const Icon(Icons.forum_outlined),
                                        label: const Text('فتح القناة'),
                                      ),
                                  ],
                                ),
                              ),
                            if (state.cursor != null)
                              TextButton(
                                onPressed: state.loading ? null : () => context.read<ChatRequestsCubit>().load(more: true),
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
          ),
        ),
      ),
    );
  }
}
