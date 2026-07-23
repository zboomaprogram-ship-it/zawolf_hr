import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../theme/theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final query = FirebaseFirestore.instance
        .collection('notifications')
        .doc(user.uid)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(100);

    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات والإعلانات')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _NotificationMessage(
              icon: Icons.cloud_off_outlined,
              message: 'تعذر تحميل الإشعارات. أعد المحاولة.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            );
          }
          final notifications = snapshot.data!.docs;
          if (notifications.isEmpty) {
            return const _NotificationMessage(
              icon: Icons.notifications_none,
              message: 'لا توجد إشعارات حالياً.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final data = notification.data();
              final isRead = data['isRead'] == true;
              final type = data['type'] as String? ?? '';
              final title = data['title'] as String? ?? 'إشعار';
              final body = data['body'] as String? ?? '';
              final createdAt = data['createdAt'] as Timestamp?;

              return WolfCard(
                hasBorderGlow: !isRead,
                onTap: () => _openNotification(
                  context: context,
                  notification: notification,
                  type: type,
                  title: title,
                  body: body,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      type == 'hr_announcement'
                          ? Icons.campaign_outlined
                          : type == 'poll_created'
                          ? Icons.how_to_vote_outlined
                          : Icons.notifications_outlined,
                      color: isRead
                          ? ZaWolfColors.textSecondary
                          : ZaWolfColors.primaryCyan,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: isRead
                                      ? FontWeight.w500
                                      : FontWeight.bold,
                                ),
                          ),
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              body,
                              textAlign: TextAlign.right,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (createdAt != null) ...[
                            const SizedBox(height: 7),
                            Text(
                              DateFormat(
                                'd MMMM yyyy، hh:mm a',
                                'ar',
                              ).format(createdAt.toDate()),
                              textAlign: TextAlign.right,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isRead) ...[
                      const SizedBox(width: 8),
                      const CircleAvatar(
                        radius: 4,
                        backgroundColor: ZaWolfColors.primaryCyan,
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openNotification({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> notification,
    required String type,
    required String title,
    required String body,
  }) async {
    if (notification.data()['isRead'] != true) {
      try {
        await notification.reference.update({'isRead': true});
      } catch (_) {
        // Opening the notification must still work if the read receipt fails.
      }
    }
    if (!context.mounted) return;

    if (type == 'hr_announcement') {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: ZaWolfColors.surface01,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.campaign_outlined,
                  color: ZaWolfColors.primaryCyan,
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(body, textAlign: TextAlign.right),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('تم'),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    final rawData = notification.data()['data'];
    final route = NotificationService.instance.safeRoute(
      rawData is Map ? rawData['route'] as String? : null,
      type: type,
    );
    if (route != '/notifications') context.go(route);
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: ZaWolfColors.textSecondary),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    );
  }
}
