enum NotificationSyncStatus { synced, pending, failed }

/// Canonical unread projection owned by the authenticated recipient.
final class NotificationReadState {
  const NotificationReadState({
    required this.unreadCount,
    required this.version,
    this.lastOperationId,
    this.syncStatus = NotificationSyncStatus.synced,
  }) : assert(unreadCount >= 0),
       assert(version >= 0);

  final int unreadCount;
  final int version;
  final String? lastOperationId;
  final NotificationSyncStatus syncStatus;

  NotificationReadState markAllPending(String operationId) {
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(operationId, 'operationId');
    }
    return NotificationReadState(
      unreadCount: 0,
      version: version,
      lastOperationId: operationId,
      syncStatus: NotificationSyncStatus.pending,
    );
  }

  NotificationReadState reconcile({
    required int canonicalUnreadCount,
    required int canonicalVersion,
    String? operationId,
  }) => NotificationReadState(
    unreadCount: canonicalUnreadCount < 0 ? 0 : canonicalUnreadCount,
    version: canonicalVersion < version ? version : canonicalVersion,
    lastOperationId: operationId ?? lastOperationId,
  );
}

final class NotificationRouteDestination {
  const NotificationRouteDestination({
    required this.path,
    required this.fallbackPath,
    this.focusId,
  });

  final String path;
  final String fallbackPath;
  final String? focusId;

  Uri toUri() {
    final safePath = _safePath(path) ? path : fallbackPath;
    return Uri(
      path: safePath,
      queryParameters: focusId == null || focusId!.trim().isEmpty
          ? null
          : <String, String>{'focusId': focusId!},
    );
  }

  static bool _safePath(String value) =>
      value.startsWith('/') && !value.startsWith('//') && !value.contains('..');
}
