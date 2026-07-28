import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../theme/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _pageSize = 20;

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _notifications = [];
  final Set<String> _locallyRead = {};
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  String? _loadedUserId;
  Object? _error;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.watch<AuthService>().currentUser?.uid;
    if (uid != null && uid != _loadedUserId) {
      _loadedUserId = uid;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadPage(reset: true),
      );
    }
  }

  Query<Map<String, dynamic>> _query(String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);
  }

  Future<void> _loadPage({required bool reset}) async {
    final userId = _loadedUserId;
    if (userId == null || _loading || _loadingMore) return;
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });

    try {
      Query<Map<String, dynamic>> query = _query(userId);
      if (!reset && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }
      final result = await query.get();
      if (!mounted || userId != _loadedUserId) return;
      setState(() {
        if (reset) _notifications.clear();
        _notifications.addAll(result.docs);
        _lastDocument = result.docs.isEmpty ? null : result.docs.last;
        _hasMore = result.docs.length == _pageSize;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadedUserId == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات والإعلانات')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            )
          : _error != null && _notifications.isEmpty
          ? _NotificationMessage(
              icon: Icons.cloud_off_outlined,
              message: 'تعذر تحميل الإشعارات. أعد المحاولة.',
              onRetry: () => _loadPage(reset: true),
            )
          : _notifications.isEmpty
          ? const _NotificationMessage(
              icon: Icons.notifications_none,
              message: 'لا توجد إشعارات حالياً.',
            )
          : RefreshIndicator(
              onRefresh: () => _loadPage(reset: true),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _notifications.length + (_hasMore ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == _notifications.length) {
                    return Center(
                      child: TextButton.icon(
                        onPressed: _loadingMore
                            ? null
                            : () => _loadPage(reset: false),
                        icon: _loadingMore
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.expand_more),
                        label: const Text('تحميل المزيد'),
                      ),
                    );
                  }
                  return _buildNotification(_notifications[index]);
                },
              ),
            ),
    );
  }

  Widget _buildNotification(
    QueryDocumentSnapshot<Map<String, dynamic>> notification,
  ) {
    final data = notification.data();
    final isRead =
        data['isRead'] == true || _locallyRead.contains(notification.id);
    final type = data['type'] as String? ?? '';
    final title = data['title'] as String? ?? 'إشعار';
    final body = data['body'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;

    return WolfCard(
      hasBorderGlow: !isRead,
      onTap: () => _openNotification(
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
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
  }

  Future<void> _openNotification({
    required QueryDocumentSnapshot<Map<String, dynamic>> notification,
    required String type,
    required String title,
    required String body,
  }) async {
    if (notification.data()['isRead'] != true) {
      setState(() => _locallyRead.add(notification.id));
      try {
        await notification.reference.update({'isRead': true});
      } catch (_) {}
    }
    if (!mounted) return;

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
    if (route != '/notifications' && mounted) context.go(route);
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: ZaWolfColors.textSecondary),
          const SizedBox(height: 12),
          Text(message),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ],
      ),
    );
  }
}
