import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../theme/theme.dart';
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
  var _selectedSection = 0;

  String get _section => _selectedSection == 0 ? 'direct' : 'group';

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

  Future<void> _openDirectChat() async {
    final channel = await Navigator.push<RichChannel>(
      context,
      MaterialPageRoute(
        builder: (_) => DirectChatPickerPage(repository: widget.repository),
      ),
    );
    if (channel != null && mounted) widget.openChannel(context, channel);
  }

  void _openRequests() => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder:
          (_) => ChatRequestsPage(
            repository: widget.repository,
            canReview: widget.canReview,
            openChannel: widget.openChannel,
          ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final groups = _selectedSection == 1;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المحادثات'),
          actions: [
            IconButton(
              tooltip: 'بدء محادثة خاصة',
              icon: const Icon(Icons.edit_square),
              onPressed: _openDirectChat,
            ),
            IconButton(
              tooltip:
                  widget.canReview ? 'مراجعة طلبات الجروبات' : 'طلبات الجروبات',
              icon: const Icon(Icons.group_add_outlined),
              onPressed: _openRequests,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'chat-inbox-action',
          onPressed: groups ? _openRequests : _openDirectChat,
          icon: Icon(groups ? Icons.group_add_outlined : Icons.edit_outlined),
          label: Text(
            groups
                ? (widget.canReview ? 'إنشاء أو مراجعة جروب' : 'طلب جروب')
                : 'رسالة جديدة',
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    _InboxHero(
                      groups: groups,
                      onSelected:
                          (index) => setState(() => _selectedSection = index),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      // Only the visible section is mounted. This prevents an
                      // unopened tab from issuing a second inbox request.
                      child: _InboxSection(
                        key: ValueKey(_section),
                        repository: widget.repository,
                        section: _section,
                        emptyText:
                            groups
                                ? 'لا توجد جروبات متاحة الآن. يمكنك طلب جروب جديد.'
                                : 'لا توجد محادثات خاصة بعد. ابدأ رسالة جديدة.',
                        openChannel: widget.openChannel,
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class _InboxHero extends StatelessWidget {
  const _InboxHero({required this.groups, required this.onSelected});
  final bool groups;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'تبديل نوع المحادثات',
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ZaWolfColors.borderGlow),
      ),
      child: Row(
        children: [
          _SectionButton(
            icon: Icons.lock_outline,
            label: 'الرسائل الخاصة',
            selected: !groups,
            onTap: () => onSelected(0),
          ),
          _SectionButton(
            icon: Icons.groups_outlined,
            label: 'الجروبات',
            selected: groups,
            onTap: () => onSelected(1),
          ),
        ],
      ),
    ),
  );
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color:
                  selected
                      ? ZaWolfColors.primaryCyan.withValues(alpha: .14)
                      : null,
              borderRadius: BorderRadius.circular(13),
              border:
                  selected
                      ? Border.all(
                        color: ZaWolfColors.primaryCyan.withValues(alpha: .7),
                      )
                      : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 19,
                  color:
                      selected
                          ? ZaWolfColors.primaryCyan
                          : ZaWolfColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : ZaWolfColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _InboxSection extends StatelessWidget {
  const _InboxSection({
    super.key,
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.offline)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: ChatFeedback(
                  text:
                      'تظهر آخر المحادثات المحفوظة، ويجري تحديثها عند عودة الخدمة.',
                  icon: Icons.cloud_sync_outlined,
                ),
              ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ChatFeedback(
                  text: chatErrorText(state.error!),
                  onRetry: cubit.load,
                ),
              ),
            Expanded(
              child:
                  state.channels.isEmpty &&
                          !state.loading &&
                          state.error == null
                      ? _EmptyInbox(message: emptyText)
                      : RefreshIndicator(
                        onRefresh: cubit.load,
                        child:
                            state.loading && state.channels.isEmpty
                                ? const _InboxSkeleton()
                                : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(bottom: 96),
                                  itemCount:
                                      state.channels.length +
                                      (state.cursor == null ? 0 : 1),
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    if (index == state.channels.length) {
                                      return TextButton.icon(
                                        onPressed:
                                            state.loading
                                                ? null
                                                : () => cubit.load(more: true),
                                        icon: const Icon(Icons.expand_more),
                                        label: const Text('تحميل محادثات أقدم'),
                                      );
                                    }
                                    return _ConversationTile(
                                      channel: state.channels[index],
                                      direct: section == 'direct',
                                      onTap:
                                          () => openChannel(
                                            context,
                                            state.channels[index],
                                          ),
                                    );
                                  },
                                ),
                      ),
            ),
          ],
        );
      },
    ),
  );
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.channel,
    required this.direct,
    required this.onTap,
  });
  final RichChannel channel;
  final bool direct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials =
        channel.name.trim().isEmpty
            ? '?'
            : channel.name.trim().characters.first;
    final time =
        channel.latestActivityAt == null
            ? ''
            : DateFormat(
              'h:mm a',
              'ar',
            ).format(channel.latestActivityAt!.toLocal());
    return Semantics(
      button: true,
      label: 'فتح ${channel.name}',
      child: Material(
        color: ZaWolfColors.surface01,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ZaWolfColors.surface03),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      direct
                          ? ZaWolfColors.primaryBlue
                          : ZaWolfColors.permissionTeal,
                  child:
                      direct
                          ? Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                          : const Icon(
                            Icons.groups_outlined,
                            color: Colors.white,
                          ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        channel.canPost
                            ? (direct ? 'محادثة خاصة' : 'جروب العمل')
                            : 'للقراءة فقط',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ZaWolfColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      time,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ZaWolfColors.textMuted,
                      ),
                    ),
                    if (channel.unreadCount > 0)
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: ZaWolfColors.primaryCyan,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          channel.unreadCount > 99
                              ? '99+'
                              : '${channel.unreadCount}',
                          style: const TextStyle(
                            color: ZaWolfColors.background,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      const Icon(
                        Icons.chevron_left,
                        color: ZaWolfColors.textMuted,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();
  @override
  Widget build(BuildContext context) => ListView.separated(
    physics: const NeverScrollableScrollPhysics(),
    itemCount: 6,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder:
        (_, __) => Container(
          height: 76,
          decoration: BoxDecoration(
            color: ZaWolfColors.surface01,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ZaWolfColors.surface03),
          ),
        ),
  );
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.forum_outlined,
            size: 48,
            color: ZaWolfColors.textMuted,
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: ZaWolfColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    ),
  );
}
