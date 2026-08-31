import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/sync/authenticated_operation_client.dart';
import '../domain/entities/notification_read_state.dart';
import '../domain/repositories/notification_operations_repository.dart';

final class NotificationOperationsRepositoryImpl
    implements NotificationOperationsRepository {
  NotificationOperationsRepositoryImpl({
    required FirebaseFirestore firestore,
    required AuthenticatedOperationClient operationClient,
    required Uri operationsBaseUri,
  }) : _firestore = firestore,
       _operationClient = operationClient,
       _operationsBaseUri = operationsBaseUri;

  final FirebaseFirestore _firestore;
  final AuthenticatedOperationClient _operationClient;
  final Uri _operationsBaseUri;

  @override
  Stream<NotificationReadState> watchReadState({required String actorId}) =>
      _firestore.collection('users').doc(actorId).snapshots().map((snapshot) {
        final data = snapshot.data() ?? const <String, dynamic>{};
        final unread = (data['unreadNotifications'] as num?)?.toInt() ?? 0;
        final version = (data['notificationReadVersion'] as num?)?.toInt() ?? 0;
        return NotificationReadState(
          unreadCount: unread < 0 ? 0 : unread,
          version: version < 0 ? 0 : version,
        );
      });

  @override
  Future<NotificationReadState> markAllRead({
    required String actorId,
    required NotificationReadState current,
    required String operationId,
  }) async {
    final response = await _operationClient.post(
      _operationsBaseUri.resolve('/operations/notification-read-all'),
      operationId: operationId,
    );
    if (!response.ok) {
      return NotificationReadState(
        unreadCount: current.unreadCount,
        version: current.version,
        lastOperationId: operationId,
        syncStatus: NotificationSyncStatus.failed,
      );
    }
    return NotificationReadState(
      unreadCount: response.data['complete'] == true ? 0 : current.unreadCount,
      version: current.version,
      lastOperationId: operationId,
      syncStatus: response.data['complete'] == true
          ? NotificationSyncStatus.synced
          : NotificationSyncStatus.pending,
    );
  }

  @override
  Future<NotificationRouteDestination?> resolveDestination({
    required String actorId,
    required String notificationId,
  }) async {
    final operationId = 'resolve:$notificationId';
    final response = await _operationClient.post(
      _operationsBaseUri.resolve('/operations/resolve-notification'),
      operationId: operationId,
      body: {'notificationId': notificationId},
    );
    final destination = response.data['destination'];
    if (!response.ok || destination is! Map) return null;
    final path = destination['path']?.toString() ?? '/notifications';
    final fallback =
        destination['fallbackPath']?.toString() ?? '/notifications';
    return NotificationRouteDestination(
      path: path,
      fallbackPath: fallback,
      focusId: destination['focusId']?.toString(),
    );
  }
}
