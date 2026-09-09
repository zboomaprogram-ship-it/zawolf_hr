import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';
import '../cubit/chat_inbox_cubit.dart';
import '../widgets/chat_feedback.dart';
import 'chat_requests_page.dart';
import 'direct_chat_picker_page.dart';

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
  int _refreshEpoch = 0;
  @override
  void initState() {
    super.initState();
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
            tooltip: 'محادثة خاصة',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () async {
              final channel = await Navigator.push<RichChannel>(
                context,
                MaterialPageRoute(
                  builder:
                      (_) =>
                          DirectChatPickerPage(repository: widget.repository),
                ),
              );
              if (channel != null && context.mounted) {
                widget.openChannel(context, channel);
              }
            },
          ),
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
            onPressed: () => setState(() => _refreshEpoch++),
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
      body: DefaultTabController(
        key: ValueKey(_refreshEpoch),
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [Tab(text: 'المحادثات الخاصة'), Tab(text: 'الجروبات')],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _InboxSection(
                    repository: widget.repository,
                    section: 'direct',
                    emptyText: 'لا توجد محادثات خاصة.',
                    openChannel: widget.openChannel,
                  ),
                  _InboxSection(
                    repository: widget.repository,
                    section: 'group',
                    emptyText: 'لا توجد جروبات متاحة حتى الآن.',
                    openChannel: widget.openChannel,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _InboxSection extends StatelessWidget {
  const _InboxSection({
    required this.repository,
    required this.section,
    required this.emptyText,
    required this.openChannel,
  });
  final RichChatRepository repository;
  final String section, emptyText;
  final void Function(BuildContext, RichChannel) openChannel;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ChatInboxCubit(repository, section: section),
    child: BlocBuilder<ChatInboxCubit, ChatInboxState>(
      builder: (context, state) {
        final cubit = context.read<ChatInboxCubit>();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                if (state.loading) const LinearProgressIndicator(),
                if (state.offline)
                  const ChatFeedback(
                    text: 'غير متصل — تظهر المحادثات المحفوظة على هذا الجهاز',
                    icon: Icons.cloud_off,
                  ),
                if (state.error != null)
                  ChatFeedback(
                    text: chatErrorText(state.error!),
                    onRetry: cubit.load,
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: cubit.load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (state.channels.isEmpty && !state.loading)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(emptyText, textAlign: TextAlign.center),
                          ),
                        for (final channel in state.channels)
                          ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                section == 'direct'
                                    ? Icons.person_outline
                                    : Icons.group_outlined,
                              ),
                            ),
                            title: Text(channel.name),
                            subtitle: Text(
                              channel.canPost
                                  ? (section == 'direct'
                                      ? 'محادثة خاصة'
                                      : 'جروب العمل')
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
                            onTap: () => openChannel(context, channel),
                          ),
                        if (state.cursor != null)
                          TextButton(
                            onPressed:
                                state.loading
                                    ? null
                                    : () => cubit.load(more: true),
                            child: const Text('تحميل المزيد'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
