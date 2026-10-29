import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/request_record.dart';
import '../../domain/repositories/request_repository.dart';

sealed class RequestQueueState extends Equatable {
  const RequestQueueState();

  @override
  List<Object?> get props => [];
}

final class RequestQueueInitial extends RequestQueueState {
  const RequestQueueInitial();
}

final class RequestQueueLoading extends RequestQueueState {
  const RequestQueueLoading({this.staleRecords = const []});
  final List<RequestRecord> staleRecords;

  @override
  List<Object?> get props => [staleRecords];
}

final class RequestQueueLoaded extends RequestQueueState {
  const RequestQueueLoaded({
    required this.records,
    this.nextCursor,
    this.isRefreshing = false,
  });

  final List<RequestRecord> records;
  final String? nextCursor;
  final bool isRefreshing;

  bool get hasMore => nextCursor != null;

  RequestQueueLoaded copyWith({
    List<RequestRecord>? records,
    String? nextCursor,
    bool? isRefreshing,
  }) {
    return RequestQueueLoaded(
      records: records ?? this.records,
      nextCursor: nextCursor ?? this.nextCursor,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [records, nextCursor, isRefreshing];
}

final class RequestQueueEmpty extends RequestQueueState {
  const RequestQueueEmpty();
}

final class RequestQueueFailure extends RequestQueueState {
  const RequestQueueFailure(this.errorMessage, {this.staleRecords = const []});
  final String errorMessage;
  final List<RequestRecord> staleRecords;

  @override
  List<Object?> get props => [errorMessage, staleRecords];
}

/// Cubit managing the "طلبات عليا" (pending my action) queue (Task C015).
/// Strictly < 300 lines, depends exclusively on domain contract [RequestRepository].
final class RequestQueueCubit extends Cubit<RequestQueueState> {
  RequestQueueCubit({required RequestRepository repository})
      : _repository = repository,
        super(const RequestQueueInitial());

  final RequestRepository _repository;
  int _activeGeneration = 0;

  Future<void> loadQueue({
    required String actorId,
    required String companyId,
    bool refresh = false,
  }) async {
    final generation = ++_activeGeneration;
    final currentRecords = switch (state) {
      RequestQueueLoaded(:final records) => records,
      RequestQueueLoading(:final staleRecords) => staleRecords,
      RequestQueueFailure(:final staleRecords) => staleRecords,
      _ => const <RequestRecord>[],
    };

    if (currentRecords.isNotEmpty) {
      if (state is RequestQueueLoaded) {
        emit((state as RequestQueueLoaded).copyWith(isRefreshing: true));
      } else {
        emit(RequestQueueLoading(staleRecords: currentRecords));
      }
    } else {
      emit(const RequestQueueLoading());
    }

    final result = await _repository.getPendingQueue(
      actorId: actorId,
      companyId: companyId,
      limit: 20,
    );

    if (isClosed || generation != _activeGeneration) return;

    switch (result) {
      case RequestListLoaded(:final records, :final nextCursor):
        if (records.isEmpty) {
          emit(const RequestQueueEmpty());
        } else {
          emit(RequestQueueLoaded(records: records, nextCursor: nextCursor));
        }
      case RequestListEmpty():
        emit(const RequestQueueEmpty());
      case RequestListFailure(:final errorMessage):
        emit(RequestQueueFailure(errorMessage, staleRecords: currentRecords));
    }
  }

  Future<void> loadMore({
    required String actorId,
    required String companyId,
  }) async {
    final currentState = state;
    if (currentState is! RequestQueueLoaded || !currentState.hasMore || currentState.isRefreshing) {
      return;
    }

    final generation = ++_activeGeneration;
    final result = await _repository.getPendingQueue(
      actorId: actorId,
      companyId: companyId,
      cursor: currentState.nextCursor,
      limit: 20,
    );

    if (isClosed || generation != _activeGeneration) return;

    if (result is RequestListLoaded) {
      emit(
        currentState.copyWith(
          records: [...currentState.records, ...result.records],
          nextCursor: result.nextCursor,
        ),
      );
    }
  }

  /// Optimistically dismisses or updates a resolved request from the pending queue.
  void onItemActionCompleted(String requestId) {
    final currentState = state;
    if (currentState is RequestQueueLoaded) {
      final updated = currentState.records
          .where((r) => r.id != requestId)
          .toList(growable: false);
      if (updated.isEmpty) {
        emit(const RequestQueueEmpty());
      } else {
        emit(currentState.copyWith(records: updated));
      }
    }
  }
}
