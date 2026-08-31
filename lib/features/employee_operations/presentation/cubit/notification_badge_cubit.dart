import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/notification_read_state.dart';
import '../../domain/repositories/notification_operations_repository.dart';

final class NotificationBadgeCubit extends Cubit<NotificationReadState> {
  NotificationBadgeCubit({
    required String actorId,
    required NotificationOperationsRepository repository,
  }) : _actorId = actorId,
       _repository = repository,
       super(const NotificationReadState(unreadCount: 0, version: 0)) {
    _subscription = _repository
        .watchReadState(actorId: actorId)
        .listen(emit, onError: (_) {});
  }

  final String _actorId;
  final NotificationOperationsRepository _repository;
  StreamSubscription<NotificationReadState>? _subscription;

  Future<void> markAllRead() async {
    if (state.unreadCount == 0 ||
        state.syncStatus == NotificationSyncStatus.pending) {
      return;
    }
    final operationId =
        'read-all:${DateTime.now().toUtc().microsecondsSinceEpoch}';
    final current = state;
    emit(current.markAllPending(operationId));
    emit(
      await _repository.markAllRead(
        actorId: _actorId,
        current: current,
        operationId: operationId,
      ),
    );
  }

  Future<NotificationRouteDestination?> resolve(String notificationId) =>
      _repository.resolveDestination(
        actorId: _actorId,
        notificationId: notificationId,
      );

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
