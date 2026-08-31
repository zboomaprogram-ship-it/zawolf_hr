import '../entities/notification_read_state.dart';

abstract interface class NotificationOperationsRepository {
  Stream<NotificationReadState> watchReadState({required String actorId});

  Future<NotificationReadState> markAllRead({
    required String actorId,
    required NotificationReadState current,
    required String operationId,
  });

  Future<NotificationRouteDestination?> resolveDestination({
    required String actorId,
    required String notificationId,
  });
}
