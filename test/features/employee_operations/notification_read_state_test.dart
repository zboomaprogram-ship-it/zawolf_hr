import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/employee_operations/domain/entities/notification_read_state.dart';

void main() {
  test(
    'mark all read clears badge optimistically and keeps operation identity',
    () {
      const state = NotificationReadState(unreadCount: 8, version: 3);

      final pending = state.markAllPending('read-all-1');

      expect(pending.unreadCount, 0);
      expect(pending.lastOperationId, 'read-all-1');
      expect(pending.syncStatus, NotificationSyncStatus.pending);
    },
  );

  test(
    'canonical reconciliation never restores an older projection version',
    () {
      const state = NotificationReadState(unreadCount: 0, version: 5);

      final reconciled = state.reconcile(
        canonicalUnreadCount: 2,
        canonicalVersion: 4,
      );

      expect(reconciled.unreadCount, 2);
      expect(reconciled.version, 5);
      expect(reconciled.syncStatus, NotificationSyncStatus.synced);
    },
  );

  test('route destination uses opaque focus id and rejects external paths', () {
    const destination = NotificationRouteDestination(
      path: 'https://outside.example/request',
      fallbackPath: '/manager/requests',
      focusId: 'leave-7',
    );

    expect(destination.toUri().path, '/manager/requests');
    expect(destination.toUri().queryParameters['focusId'], 'leave-7');
  });
}
