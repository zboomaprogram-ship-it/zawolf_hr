import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../components/wolf_card.dart';
import '../../../design_system/components/rtl_navigation.dart';
import '../../../design_system/tokens.dart';
import '../../../models/user_model.dart';
import '../../../services/notification_service.dart';
import '../../../features/conversations/domain/in_app_notification_alert.dart';
import '../../../theme/theme.dart';

/// Web dashboard card showing recent conversations, quick channels,
/// and live incoming message alerts.
class WebRecentChatsCard extends StatefulWidget {
  final UserModel user;
  final Stream<List<InAppNotificationAlert>>? messagesStream;

  const WebRecentChatsCard({
    super.key,
    required this.user,
    this.messagesStream,
  });

  @override
  State<WebRecentChatsCard> createState() => _WebRecentChatsCardState();
}

class _WebRecentChatsCardState extends State<WebRecentChatsCard> {
  Stream<List<InAppNotificationAlert>>? _messagesStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(covariant WebRecentChatsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid ||
        oldWidget.messagesStream != widget.messagesStream) {
      _initStream();
    }
  }

  void _initStream() {
    if (widget.messagesStream != null) {
      _messagesStream = widget.messagesStream;
      return;
    }
    try {
      _messagesStream = NotificationService.instance
          .watchRecentConversationMessages(widget.user.uid, limit: 5);
    } catch (_) {
      _messagesStream = const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WolfCard(
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ZaWolfColors.primaryCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: ZaWolfColors.primaryCyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: DsSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المحادثات والتواصل السريع',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'القنوات المباشرة، الأقسام، والمحادثات الخاصة',
                      style: TextStyle(
                        color: ZaWolfColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/conversations'),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('فتح المحادثات'),
                style: FilledButton.styleFrom(
                  backgroundColor: ZaWolfColors.primaryCyan.withValues(
                    alpha: 0.15,
                  ),
                  foregroundColor: ZaWolfColors.primaryCyan,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),

          // Quick Action Channel Tiles
          Row(
            children: [
              Expanded(
                child: _buildChannelShortcut(
                  title:
                      widget.user.department.isNotEmpty
                          ? 'قناة ${widget.user.department}'
                          : 'قناة القسم',
                  subtitle: 'تواصل مع فريقك',
                  icon: Icons.groups_outlined,
                  color: ZaWolfColors.primaryCyan,
                  onTap: () => context.go('/conversations'),
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: _buildChannelShortcut(
                  title: 'محادثة خاصة',
                  subtitle: 'رسالة مباشرة لزميل',
                  icon: Icons.person_search_outlined,
                  color: ZaWolfColors.warning,
                  onTap: () => context.go('/conversations'),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          const Divider(height: 1, color: ZaWolfColors.surface03),
          const SizedBox(height: DsSpacing.md),

          // Live incoming message feed / recent alerts
          StreamBuilder<List<InAppNotificationAlert>>(
            stream: _messagesStream,
            builder: (context, snapshot) {
              final messages = snapshot.data ?? const [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        messages.isNotEmpty
                            ? 'آخر الرسائل والتنبيهات المباشرة'
                            : 'حالة التواصل والنشاط',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (messages.any((m) => !m.isRead))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: ZaWolfColors.primaryCyan.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: ZaWolfColors.primaryCyan.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(
                            '${messages.where((m) => !m.isRead).length} جديد',
                            style: const TextStyle(
                              color: ZaWolfColors.primaryCyan,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: DsSpacing.sm),

                  if (messages.isNotEmpty)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: messages.length,
                      separatorBuilder:
                          (context, index) => const Divider(
                            height: 12,
                            color: ZaWolfColors.surface02,
                          ),
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return _buildMessageRow(context, message);
                      },
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: ZaWolfColors.surface02,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mark_chat_read_outlined,
                              color: ZaWolfColors.primaryCyan,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'أنت على اطلاع بكل المحادثات',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'ستظهر أي رسائل أو تنبيهات واردة إليك هنا وإشعار منبثق فوري أعلى الشاشة.',
                            style: TextStyle(
                              color: ZaWolfColors.textMuted,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChannelShortcut({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ZaWolfColors.surface02,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZaWolfColors.surface03),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: ZaWolfColors.textMuted,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageRow(
    BuildContext context,
    InAppNotificationAlert message,
  ) {
    final formattedTime =
        DateFormat('hh:mm a', 'ar').format(message.timestamp);

    return InkWell(
      onTap: () async {
        if (!message.isRead) {
          unawaited(NotificationService.instance
              .markAsRead(widget.user.uid, message.id));
        }
        if (context.mounted) {
          if (message.route.isNotEmpty && message.route != '/') {
            context.go(message.route);
          } else {
            context.go('/conversations');
          }
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  message.isRead
                      ? ZaWolfColors.surface03
                      : ZaWolfColors.primaryCyan.withValues(alpha: 0.15),
              child: Icon(
                Icons.chat_bubble_rounded,
                color:
                    message.isRead
                        ? ZaWolfColors.textSecondary
                        : ZaWolfColors.primaryCyan,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!message.isRead)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            color: ZaWolfColors.primaryCyan,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          message.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight:
                                message.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formattedTime,
                        style: const TextStyle(
                          color: ZaWolfColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.body,
                    style: TextStyle(
                      color:
                          message.isRead
                              ? ZaWolfColors.textMuted
                              : ZaWolfColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              RtlNavigation.chevronEnd(context),
              color: ZaWolfColors.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
