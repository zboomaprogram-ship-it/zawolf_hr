import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../components/wolf_card.dart';
import '../../../design_system/tokens.dart';
import '../../../models/user_model.dart';
import '../../../services/notification_service.dart';
import '../../../features/conversations/domain/in_app_notification_alert.dart';
import '../../../theme/theme.dart';

/// Web dashboard card showing recent conversations, quick channels,
/// and live incoming message alerts.
class WebRecentChatsCard extends StatefulWidget {
  final UserModel user;

  const WebRecentChatsCard({super.key, required this.user});

  @override
  State<WebRecentChatsCard> createState() => _WebRecentChatsCardState();
}

class _WebRecentChatsCardState extends State<WebRecentChatsCard> {
  final List<InAppNotificationAlert> _recentMessages = [];
  StreamSubscription<InAppNotificationAlert>? _alertsSubscription;

  @override
  void initState() {
    super.initState();
    _alertsSubscription = NotificationService.instance.alerts.listen((alert) {
      if (!mounted) return;
      if (alert.isChatMessage) {
        setState(() {
          _recentMessages.removeWhere((item) => item.id == alert.id);
          _recentMessages.insert(0, alert);
          if (_recentMessages.length > 5) {
            _recentMessages.removeLast();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _alertsSubscription?.cancel();
    super.dispose();
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
          Text(
            _recentMessages.isNotEmpty
                ? 'آخر الرسائل والتنبيهات المباشرة'
                : 'حالة التواصل والنشاط',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DsSpacing.sm),

          if (_recentMessages.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentMessages.length,
              separatorBuilder:
                  (context, index) =>
                      const Divider(height: 12, color: ZaWolfColors.surface02),
              itemBuilder: (context, index) {
                final message = _recentMessages[index];
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
    final formattedTime = DateFormat('hh:mm a', 'ar').format(message.timestamp);

    return InkWell(
      onTap:
          () => unawaited(
            NotificationService.instance.openInAppNotification(message),
          ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: ZaWolfColors.primaryCyan.withValues(alpha: 0.15),
              child: const Icon(
                Icons.chat_bubble_rounded,
                color: ZaWolfColors.primaryCyan,
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
                      Expanded(
                        child: Text(
                          message.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
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
                    style: const TextStyle(
                      color: ZaWolfColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: ZaWolfColors.textMuted,
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
}
