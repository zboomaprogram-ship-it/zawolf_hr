import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../design_system/components/filter_bar.dart';
import '../../design_system/bidi.dart';
import '../../design_system/components/skeletons.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../features/employee_operations/domain/entities/notification_read_state.dart';
import '../../features/employee_operations/presentation/cubit/notification_badge_cubit.dart';
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
  String _filter = 'all';
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

  bool _isRead(QueryDocumentSnapshot<Map<String, dynamic>> item) =>
      item.data()['isRead'] == true || _locallyRead.contains(item.id);

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _visibleItems {
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> items =
        _notifications;
    switch (_filter) {
      case 'unread':
        items = items.where((item) => !_isRead(item));
      case 'announcements':
        items = items.where((item) => item.data()['type'] == 'hr_announcement');
      case 'polls':
        items = items.where((item) => item.data()['type'] == 'poll_created');
      case 'system':
        items = items.where(
          (item) =>
              item.data()['type'] != 'hr_announcement' &&
              item.data()['type'] != 'poll_created',
        );
    }
    return items.toList();
  }

  int get _unreadCount => _notifications.where((item) => !_isRead(item)).length;

  NotificationBadgeCubit? _notificationOperations() {
    try {
      return context.read<NotificationBadgeCubit>();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadedUserId == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات والإعلانات'),
        actions: [
          IconButton(
            tooltip: 'تحديد الكل كمقروء',
            onPressed: _unreadCount > 0 ? _markAllRead : null,
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ).copyWith(top: 8),
            child: FilterBar(
              selectedId: _filter,
              onSelected: (id) => setState(() => _filter = id),
              chips: [
                FilterChipItem(id: 'all', label: 'الكل'),
                FilterChipItem(
                  id: 'unread',
                  label: 'غير المقروء',
                  count: _unreadCount,
                ),
                FilterChipItem(id: 'announcements', label: 'الإعلانات'),
                FilterChipItem(id: 'polls', label: 'الاستطلاعات'),
                FilterChipItem(id: 'system', label: 'النظام'),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonList(itemCount: 5, itemHeight: 84),
      );
    }
    if (_error != null && _notifications.isEmpty) {
      return _NotificationMessage(
        icon: Icons.cloud_off_outlined,
        message: 'تعذر تحميل الإشعارات. أعد المحاولة.',
        onRetry: () => _loadPage(reset: true),
      );
    }
    final visible = _visibleItems;
    if (visible.isEmpty) {
      return const _NotificationMessage(
        icon: Icons.notifications_none,
        message: 'لا توجد إشعارات في هذا التصنيف.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadPage(reset: true),
      child: _buildGroupedList(visible),
    );
  }

  /// Day-grouped list with sticky date captions (today / yesterday /
  /// earlier), followed by the bounded load-more control.
  Widget _buildGroupedList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> visible,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <String, List<Widget>>{};
    var currentCaption = '';
    for (final item in visible) {
      final createdAt = item.data()['createdAt'] as Timestamp?;
      final caption = _dayCaption(createdAt, today, yesterday);
      if (caption != currentCaption) currentCaption = caption;
      (groups[currentCaption] ??= []).add(
        Dismissible(
          key: ValueKey('dismiss-${item.id}'),
          direction: _isRead(item)
              ? DismissDirection.none
              : DismissDirection.horizontal,
          background: Container(
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: ZaWolfColors.primaryCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.done, color: ZaWolfColors.primaryCyan),
          ),
          confirmDismiss: (_) async {
            await _markRead(item.reference);
            return false; // stay in place; the read state updates instead
          },
          child: _HoverableNotification(
            isRead: _isRead(item),
            onMarkRead: () => _markRead(item.reference),
            child: _buildNotification(item),
          ),
        ),
      );
    }

    final slivers = <Widget>[
      for (final entry in groups.entries) ...[
        SliverMainAxisGroup(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyDayHeader(label: entry.key),
            ),
            SliverList.builder(
              itemCount: entry.value.length,
              itemBuilder: (_, index) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: entry.value[index],
              ),
            ),
          ],
        ),
      ],
    ];
    if (_hasMore) {
      slivers.add(
        SliverToBoxAdapter(
          child: Center(
            child: TextButton.icon(
              onPressed: _loadingMore ? null : () => _loadPage(reset: false),
              icon: _loadingMore
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: const Text('تحميل المزيد'),
            ),
          ),
        ),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverPadding(padding: EdgeInsets.symmetric(vertical: 4)),
        ...slivers,
        const SliverPadding(padding: EdgeInsets.all(16)),
      ],
    );
  }

  String _dayCaption(Timestamp? createdAt, DateTime today, DateTime yesterday) {
    if (createdAt == null) return 'أقدم';
    final date = createdAt.toDate();
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'اليوم';
    if (day == yesterday) return 'أمس';
    return DateFormat('d MMMM yyyy', 'ar').format(date);
  }

  Widget _buildNotification(
    QueryDocumentSnapshot<Map<String, dynamic>> notification,
  ) {
    final data = notification.data();
    final isRead = _isRead(notification);
    final type = data['type'] as String? ?? '';
    final title = data['title'] as String? ?? 'إشعار';
    final body = data['body'] as String? ?? '';
    final createdAt =
        data['createdAt'] as Timestamp? ?? Timestamp.fromDate(DateTime.now());

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
            _categoryIcon(type),
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
                    // Unread is dot + weight, never color-only.
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
                const SizedBox(height: 7),
                Text(
                  _relativeTime(createdAt.toDate()),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ZaWolfColors.textMuted,
                  ),
                ),
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

  IconData _categoryIcon(String type) {
    if (type == 'hr_announcement') return Icons.campaign_outlined;
    if (type == 'poll_created') return Icons.how_to_vote_outlined;
    if (type.contains('task')) return Icons.task_alt_outlined;
    if (type.contains('approval') || type.contains('request')) {
      return Icons.rule_rounded;
    }
    return Icons.notifications_outlined;
  }

  String _relativeTime(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'قبل ${dsBidi(diff.inMinutes)} دقيقة';
    if (diff.inHours < 24) return 'قبل ${dsBidi(diff.inHours)} ساعة';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 30) return 'قبل ${dsBidi(diff.inDays)} يوم';
    return DateFormat('d MMMM yyyy', 'ar').format(value);
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
        await _markRead(notification.reference);
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

    final operations = _notificationOperations();
    if (operations != null) {
      try {
        final destination = await operations.resolve(notification.id);
        if (!mounted) return;
        final uri = destination?.toUri();
        if (uri != null && uri.path != '/notifications') {
          context.go(uri.toString());
          return;
        }
      } catch (_) {}
    }

    final rawData = notification.data()['data'];
    final candidateRoute = rawData is Map
        ? (rawData['route'] as String? ??
            rawData['url'] as String? ??
            rawData['link'] as String?)
        : (notification.data()['route'] as String?);

    String? finalRoute = candidateRoute;
    if ((finalRoute == null || finalRoute.isEmpty) &&
        rawData is Map &&
        rawData['channelId'] != null) {
      finalRoute =
          '/conversations/channel/${Uri.encodeComponent(rawData['channelId'].toString())}';
    }

    final route = NotificationService.instance.safeRoute(
      finalRoute,
      type: type,
    );
    if (route != '/notifications' && mounted) context.go(route);
  }

  Future<void> _markRead(DocumentReference<Map<String, dynamic>> ref) async {
    final userId = _loadedUserId;
    if (userId == null) return;
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final notification = await transaction.get(ref);
        if (!notification.exists || notification.data()?['isRead'] == true) {
          return;
        }
        final user = await transaction.get(userRef);
        final unread =
            (user.data()?['unreadNotifications'] as num?)?.toInt() ?? 0;
        transaction.update(ref, {'isRead': true});
        if (user.exists) {
          transaction.update(userRef, {
            'unreadNotifications': unread > 0 ? unread - 1 : 0,
          });
        }
      });
      if (mounted) {
        setState(() => _locallyRead.add(ref.id));
        final auth = context.read<AuthService>();
        final currentUnread = auth.currentUser?.unreadNotifications ?? 0;
        auth.updateUnreadNotificationCount(currentUnread > 0 ? currentUnread - 1 : 0);
        unawaited(auth.fetchUserData(userId, showLoading: false));
      }
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    final userId = _loadedUserId;
    if (userId == null) return;
    final operations = _notificationOperations();
    if (operations != null) {
      await operations.markAllRead();
      if (!mounted ||
          operations.state.syncStatus == NotificationSyncStatus.failed) {
        return;
      }
      setState(
        () => _locallyRead.addAll(_notifications.map((item) => item.id)),
      );
      final auth = context.read<AuthService>();
      auth.updateUnreadNotificationCount(0);
      unawaited(auth.fetchUserData(userId, showLoading: false));
      return;
    }
    final db = FirebaseFirestore.instance;
    while (true) {
      final unread = await db
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .where('isRead', isEqualTo: false)
          .limit(400)
          .get();
      if (unread.docs.isEmpty) break;
      final batch = db.batch();
      for (final item in unread.docs) {
        batch.update(item.reference, {'isRead': true});
      }
      batch.update(db.collection('users').doc(userId), {
        'unreadNotifications': 0,
      });
      await batch.commit();
      if (unread.docs.length < 400) break;
    }
    if (!mounted) return;
    setState(() => _locallyRead.addAll(_notifications.map((item) => item.id)));
    final auth = context.read<AuthService>();
    auth.updateUnreadNotificationCount(0);
    unawaited(auth.fetchUserData(userId, showLoading: false));
  }
}

/// Shows a mark-read affordance on pointer hover (desktop web).
class _HoverableNotification extends StatefulWidget {
  const _HoverableNotification({
    required this.isRead,
    required this.onMarkRead,
    required this.child,
  });

  final bool isRead;
  final Future<void> Function() onMarkRead;
  final Widget child;

  @override
  State<_HoverableNotification> createState() => _HoverableNotificationState();
}

class _HoverableNotificationState extends State<_HoverableNotification> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Stack(
        children: [
          widget.child,
          if (wide && _hovering && !widget.isRead)
            PositionedDirectional(
              top: 8,
              end: 8,
              child: Material(
                color: Colors.transparent,
                child: Tooltip(
                  message: 'تحديد كمقروء',
                  child: InkWell(
                    onTap: () => widget.onMarkRead(),
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.done,
                        size: 20,
                        color: ZaWolfColors.primaryCyan,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StickyDayHeader extends SliverPersistentHeaderDelegate {
  const _StickyDayHeader({required this.label});

  final String label;

  static const _height = 40.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      height: _height,
      color: ZaWolfColors.background,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Divider(color: ZaWolfColors.surface03, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: ZaWolfColors.textMuted),
            ),
          ),
          Expanded(child: Divider(color: ZaWolfColors.surface03, thickness: 1)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyDayHeader oldDelegate) =>
      oldDelegate.label != label;
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
