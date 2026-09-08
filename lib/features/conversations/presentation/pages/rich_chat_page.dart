import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';
import '../cubit/chat_action_cubit.dart';
import '../cubit/chat_composer_cubit.dart';
import '../cubit/chat_timeline_cubit.dart';
import '../widgets/chat_feedback.dart';
import '../widgets/chat_message_actions.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/rich_chat_composer.dart';
import 'chat_search_page.dart';
import 'chat_user_picker_page.dart';
import 'rich_chat_inbox_page.dart';

class RichChatPage extends StatefulWidget {
  const RichChatPage({
    super.key,
    required this.repository,
    required this.channel,
    required this.canReview,
    required this.attachmentBuilder,
    required this.pickAttachments,
    required this.voiceBuilder,
    this.linkPreviewBuilder,
  });
  final RichChatRepository repository;
  final RichChannel channel;
  final bool canReview;
  final Widget Function(BuildContext, RichAttachment) attachmentBuilder;
  final Future<List<ChatDraftFile>> Function(BuildContext) pickAttachments;
  final Widget Function(BuildContext, Future<void> Function(ChatDraftFile))
  voiceBuilder;
  final Widget Function(BuildContext, ChatLinkPreview)? linkPreviewBuilder;
  @override
  State<RichChatPage> createState() => _RichChatPageState();
}

class _RichChatPageState extends State<RichChatPage>
    with WidgetsBindingObserver {
  late final ChatTimelineCubit _timeline;
  late final ChatComposerCubit _composer;
  late final ChatActionCubit _actions;
  final _scroll = ScrollController();
  final _viewport = GlobalKey();
  final _messageKeys = <String, GlobalKey>{};
  bool _foreground = true;
  bool _framePending = false;
  @override
  void initState() {
    super.initState();
    _timeline = ChatTimelineCubit(widget.repository, widget.channel.id);
    _composer = ChatComposerCubit(widget.repository, widget.channel.id);
    _actions = ChatActionCubit(widget.repository);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    widget.repository.setForeground(_foreground);
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_scheduleVisibility);
    _scheduleVisibility();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    widget.repository.setForeground(
      _foreground && (ModalRoute.of(context)?.isCurrent ?? false),
    );
    if (!_foreground) _composer.stopTyping();
    _scheduleVisibility();
  }

  void _scheduleVisibility() {
    if (_framePending) return;
    _framePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _framePending = false;
      if (!mounted ||
          !_foreground ||
          !(ModalRoute.of(context)?.isCurrent ?? false)) {
        return;
      }
      final viewport = _viewport.currentContext?.findRenderObject();
      if (viewport is! RenderBox || !viewport.hasSize) return;
      final bounds = viewport.localToGlobal(Offset.zero) & viewport.size;
      final messages = [..._timeline.state.snapshot.messages]
        ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
      for (final message in messages) {
        if (message.syncState != ChatSyncState.synced) continue;
        final box =
            _messageKeys[message.id]?.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize) continue;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        if (bounds.overlaps(rect) && bounds.intersect(rect).height >= 24) {
          unawaited(
            _timeline.visibleMessage(
              message,
              active: true,
              member:
                  widget.channel.memberUserIds.contains(
                    widget.repository.actorId,
                  ) ||
                  _timeline.state.snapshot.canPost,
            ),
          );
          break;
        }
      }
    });
  }

  Future<void> _actionsFor(RichMessage message) async {
    _composer.stopTyping();
    await showChatMessageActions(
      context,
      repository: widget.repository,
      message: message,
      canPost: _timeline.state.snapshot.canPost,
      canReview: widget.canReview,
      readers: _timeline.state.snapshot.readers,
      onReply: _composer.replyTo,
      actions: _actions,
    );
    _scheduleVisibility();
  }

  Future<void> _members() async {
    final members = await pickChatUsers(
      context,
      widget.repository,
      selected: widget.channel.memberUserIds,
    );
    if (members == null || !mounted) return;
    try {
      await widget.repository.updateMembers(
        widget.channel.id,
        members,
        widget.channel.revision,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم تحديث أعضاء القناة. افتح القناة مجددًا لمراجعة العضوية.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(chatErrorText(error.toString()))),
        );
      }
    }
  }

  Future<void> _showMembers() {
    final members = widget.repository.members(widget.channel.id);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .72,
                child: FutureBuilder<ChatPage<ChatUser>>(
                  future: members,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(chatErrorText(snapshot.error.toString())),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final users = snapshot.data!.items;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'أعضاء ${widget.channel.name}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Expanded(
                          child:
                              users.isEmpty
                                  ? const Center(
                                    child: Text(
                                      'لا توجد أسماء أعضاء متاحة لهذه القناة.',
                                    ),
                                  )
                                  : ListView.separated(
                                    itemCount: users.length,
                                    separatorBuilder:
                                        (_, __) => const Divider(height: 1),
                                    itemBuilder: (_, index) {
                                      final user = users[index];
                                      return ListTile(
                                        leading: const CircleAvatar(
                                          child: Icon(Icons.person),
                                        ),
                                        title: Text(user.name),
                                        subtitle:
                                            user.department.isEmpty
                                                ? null
                                                : Text(user.department),
                                      );
                                    },
                                  ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'كل المحادثات',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder:
                      (_) => RichChatInboxPage(
                        repository: widget.repository,
                        canReview: widget.canReview,
                        openChannel:
                            (ctx, ch) => Navigator.of(ctx).pushReplacement(
                              MaterialPageRoute<void>(
                                builder:
                                    (_) => RichChatPage(
                                      repository: widget.repository,
                                      channel: ch,
                                      canReview: widget.canReview,
                                      attachmentBuilder:
                                          widget.attachmentBuilder,
                                      pickAttachments: widget.pickAttachments,
                                      voiceBuilder: widget.voiceBuilder,
                                      linkPreviewBuilder:
                                          widget.linkPreviewBuilder,
                                    ),
                              ),
                            ),
                      ),
                ),
              );
            }
          },
        ),
        title: Text(widget.channel.name),
        actions: [
          IconButton(
            tooltip: 'كل المحادثات',
            icon: const Icon(Icons.forum_outlined),
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => RichChatInboxPage(
                          repository: widget.repository,
                          canReview: widget.canReview,
                          openChannel:
                              (ctx, ch) => Navigator.of(ctx).pushReplacement(
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => RichChatPage(
                                        repository: widget.repository,
                                        channel: ch,
                                        canReview: widget.canReview,
                                        attachmentBuilder:
                                            widget.attachmentBuilder,
                                        pickAttachments: widget.pickAttachments,
                                        voiceBuilder: widget.voiceBuilder,
                                        linkPreviewBuilder:
                                            widget.linkPreviewBuilder,
                                      ),
                                ),
                              ),
                        ),
                  ),
                ),
          ),
          IconButton(
            tooltip: 'أعضاء القناة',
            icon: const Icon(Icons.people),
            onPressed: _showMembers,
          ),
          IconButton(
            tooltip: 'البحث في المحادثة',
            icon: const Icon(Icons.search),
            onPressed: () async {
              _composer.stopTyping();
              widget.repository.setForeground(false);
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => ChatSearchPage(
                        repository: widget.repository,
                        channelId: widget.channel.id,
                        attachmentBuilder: widget.attachmentBuilder,
                      ),
                ),
              );
              if (mounted) {
                widget.repository.setForeground(_foreground);
                _scheduleVisibility();
              }
            },
          ),
          IconButton(
            tooltip: 'معلومات القناة',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              final memberText =
                  widget.channel.kind == 'department'
                      ? (widget.channel.memberUserIds.isNotEmpty
                          ? '${widget.channel.memberUserIds.length} عضو (أعضاء القسم)'
                          : 'جميع موظفي القسم')
                      : widget.channel.kind == 'manager'
                      ? (widget.channel.memberUserIds.isNotEmpty
                          ? '${widget.channel.memberUserIds.length} عضو (فريق الإدارة)'
                          : 'أعضاء الإدارة والمديرين')
                      : '${widget.channel.memberUserIds.length} عضو';
              showDialog<void>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: Text(widget.channel.name),
                      content: Text(
                        '$memberText\n\n${widget.channel.hrReadable ? 'يمكن للموارد البشرية قراءة هذه القناة ومرفقاتها. الأعضاء الجدد يمكنهم قراءة السجل.' : 'قناة العمل'}',
                      ),
                    ),
              );
            },
          ),
          if (widget.canReview && widget.channel.kind == 'custom')
            IconButton(
              tooltip: 'إدارة أعضاء القناة',
              onPressed: _members,
              icon: const Icon(Icons.people),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            children: [
              BlocBuilder<ChatActionCubit, ChatActionState>(
                bloc: _actions,
                builder:
                    (context, state) => Column(
                      children: [
                        if (state.busy) const LinearProgressIndicator(),
                        if (state.error != null)
                          ChatFeedback(text: chatErrorText(state.error!)),
                      ],
                    ),
              ),
              Expanded(
                child: BlocConsumer<ChatTimelineCubit, ChatTimelineState>(
                  bloc: _timeline,
                  listener: (context, state) => _scheduleVisibility(),
                  builder: (context, state) {
                    final messages = [...state.snapshot.messages]
                      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
                    final ids = messages.map((message) => message.id).toSet();
                    _messageKeys.removeWhere((id, _) => !ids.contains(id));
                    final byId = {
                      for (final message in messages) message.id: message,
                    };
                    return Column(
                      children: [
                        if (state.snapshot.offline)
                          const ChatFeedback(
                            text:
                                'أنت غير متصل. الرسائل المحفوظة متاحة، وسيستأنف الإرسال عند عودة الاتصال.',
                            icon: Icons.cloud_off,
                          ),
                        if (state.error != null)
                          ChatFeedback(
                            text: chatErrorText(state.error!),
                            onRetry: _timeline.loadOlder,
                          ),
                        if (widget.channel.hrReadable &&
                            !state.snapshot.canPost &&
                            !state.loading)
                          const ChatFeedback(
                            text:
                                'عرض HR للقراءة فقط — العضوية مطلوبة للإرسال والتفاعل.',
                          ),
                        if (state.loading) const LinearProgressIndicator(),
                        Expanded(
                          child: Container(
                            key: _viewport,
                            child:
                                messages.isEmpty
                                    ? Center(
                                      child: Text(
                                        state.loading
                                            ? 'جارٍ تحميل المحادثة…'
                                            : 'لا توجد رسائل بعد. ابدأ المحادثة.',
                                      ),
                                    )
                                    : ListView.builder(
                                      controller: _scroll,
                                      reverse: true,
                                      itemCount:
                                          messages.length +
                                          (state.snapshot.nextCursor == null
                                              ? 0
                                              : 1),
                                      itemBuilder: (context, index) {
                                        if (index == messages.length) {
                                          return Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: TextButton(
                                              onPressed:
                                                  state.paging
                                                      ? null
                                                      : _timeline.loadOlder,
                                              child: Text(
                                                state.paging
                                                    ? 'جارٍ التحميل…'
                                                    : 'تحميل رسائل أقدم',
                                              ),
                                            ),
                                          );
                                        }
                                        final message = messages[index];
                                        final seen = state.snapshot.readers.any(
                                          (reader) =>
                                              reader.userId !=
                                                  message.senderUserId &&
                                              (reader.messageId == message.id ||
                                                  (reader.sentAt != null &&
                                                      !reader.sentAt!.isBefore(
                                                        message.sentAt,
                                                      ))),
                                        );
                                        return KeyedSubtree(
                                          key: _messageKeys.putIfAbsent(
                                            message.id,
                                            GlobalKey.new,
                                          ),
                                          child: ChatMessageBubble(
                                            message: message,
                                            mine:
                                                message.senderUserId ==
                                                widget.repository.actorId,
                                            seen: seen,
                                            reply:
                                                byId[message.replyToMessageId],
                                            attachmentBuilder:
                                                widget.attachmentBuilder,
                                            onActions:
                                                () => _actionsFor(message),
                                            onRetry:
                                                () =>
                                                    _timeline.retry(message.id),
                                          ),
                                        );
                                      },
                                    ),
                          ),
                        ),
                        if (state.snapshot.typing.any(
                          (typing) =>
                              typing.userId != widget.repository.actorId &&
                              typing.expiresAt.isAfter(DateTime.now()),
                        ))
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              '${state.snapshot.typing.where((typing) => typing.userId != widget.repository.actorId && typing.expiresAt.isAfter(DateTime.now())).map((typing) => typing.name).join('، ')} يكتب الآن…',
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              BlocBuilder<ChatTimelineCubit, ChatTimelineState>(
                bloc: _timeline,
                builder:
                    (context, state) =>
                        state.snapshot.canPost
                            ? RichChatComposer(
                              cubit: _composer,
                              pickAttachments: widget.pickAttachments,
                              voiceBuilder: widget.voiceBuilder,
                            )
                            : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    unawaited(_timeline.close());
    unawaited(_composer.close());
    unawaited(_actions.close());
    super.dispose();
  }
}
