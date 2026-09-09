import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';
import '../cubit/chat_inbox_cubit.dart';
import '../widgets/chat_feedback.dart';
import 'chat_requests_page.dart';

class RichChatInboxPage extends StatefulWidget {
  const RichChatInboxPage({
    super.key,
    required this.repository,
    required this.canReview,
    required this.openChannel,
  });
  final RichChatRepository repository;
  final bool canReview;
  final void Function(BuildContext, RichChannel) openChannel;
  @override
  State<RichChatInboxPage> createState() => _RichChatInboxPageState();
}

class _RichChatInboxPageState extends State<RichChatInboxPage>
    with WidgetsBindingObserver {
  late final ChatInboxCubit _cubit;
  @override
  void initState() {
    super.initState();
    _cubit = ChatInboxCubit(widget.repository);
    WidgetsBinding.instance.addObserver(this);
    widget.repository.setForeground(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.repository.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('المحادثات'),
        actions: [
          IconButton(
            tooltip:
                widget.canReview ? 'مراجعة طلبات الجروبات' : 'طلبات الجروبات',
            icon: const Icon(Icons.group_add_outlined),
            onPressed:
                () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => ChatRequestsPage(
                          repository: widget.repository,
                          canReview: widget.canReview,
                          openChannel: widget.openChannel,
                        ),
                  ),
                ),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: _cubit.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder:
                    (_) => ChatRequestsPage(
                      repository: widget.repository,
                      canReview: widget.canReview,
                      openChannel: widget.openChannel,
                    ),
              ),
            ),
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(widget.canReview ? 'إنشاء / طلب جروب' : 'طلب جروب جديدة'),
      ),
      body: BlocBuilder<ChatInboxCubit, ChatInboxState>(
        bloc: _cubit,
        builder:
            (context, state) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [
                    if (state.loading) const LinearProgressIndicator(),
                    if (state.offline)
                      const ChatFeedback(
                        text: 'غير متصل — الجروبات المحفوظة على هذا الجهاز',
                        icon: Icons.cloud_off,
                      ),
                    if (state.error != null)
                      ChatFeedback(
                        text: chatErrorText(state.error!),
                        onRetry: _cubit.load,
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _cubit.load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 88),
                          children: [
                            if (state.channels.isEmpty && !state.loading)
                              Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    const Text(
                                      'لا توجد جروبات متاحة حتى الآن.',
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton.icon(
                                      onPressed:
                                          () => Navigator.push<void>(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => ChatRequestsPage(
                                                    repository:
                                                        widget.repository,
                                                    canReview: widget.canReview,
                                                    openChannel:
                                                        widget.openChannel,
                                                  ),
                                            ),
                                          ),
                                      icon: const Icon(
                                        Icons.group_add_outlined,
                                      ),
                                      label: Text(
                                        widget.canReview
                                            ? 'إنشاء جروب جديدة'
                                            : 'طلب جروب جديدة',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            for (final channel in state.channels)
                              ListTile(
                                leading: CircleAvatar(
                                  child: Icon(
                                    channel.kind == 'custom'
                                        ? Icons.group_outlined
                                        : Icons.business_outlined,
                                  ),
                                ),
                                title: Text(channel.name),
                                subtitle: Text(
                                  channel.canPost
                                      ? 'جروب العمل'
                                      : 'للقراءة فقط',
                                ),
                                trailing:
                                    channel.unreadCount > 0
                                        ? Badge(
                                          label: Text(
                                            channel.unreadCount > 99
                                                ? '99+'
                                                : '${channel.unreadCount}',
                                          ),
                                        )
                                        : const Icon(
                                          Icons.chevron_left,
                                          textDirection: TextDirection.ltr,
                                        ),
                                onTap:
                                    () => widget.openChannel(context, channel),
                              ),
                            if (state.cursor != null)
                              TextButton(
                                onPressed:
                                    state.loading
                                        ? null
                                        : () => _cubit.load(more: true),
                                child: const Text('تحميل المزيد'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cubit.close();
    super.dispose();
  }
}
