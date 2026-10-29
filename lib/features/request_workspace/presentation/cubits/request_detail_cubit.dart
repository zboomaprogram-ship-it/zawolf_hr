import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/request_record.dart';
import '../../domain/repositories/request_repository.dart';

sealed class RequestDetailState extends Equatable {
  const RequestDetailState();

  @override
  List<Object?> get props => [];
}

final class RequestDetailInitial extends RequestDetailState {
  const RequestDetailInitial();
}

final class RequestDetailLoading extends RequestDetailState {
  const RequestDetailLoading();
}

final class RequestDetailReady extends RequestDetailState {
  const RequestDetailReady({
    required this.record,
    this.isActionInProgress = false,
  });

  final RequestRecord record;
  final bool isActionInProgress;

  RequestDetailReady copyWith({
    RequestRecord? record,
    bool? isActionInProgress,
  }) {
    return RequestDetailReady(
      record: record ?? this.record,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
    );
  }

  @override
  List<Object?> get props => [record, isActionInProgress];
}

final class RequestDetailNotFoundState extends RequestDetailState {
  const RequestDetailNotFoundState();
}

final class RequestDetailFailureState extends RequestDetailState {
  const RequestDetailFailureState(this.errorMessage);
  final String errorMessage;

  @override
  List<Object?> get props => [errorMessage];
}

final class RequestDetailActionSuccessState extends RequestDetailState {
  const RequestDetailActionSuccessState({
    required this.message,
    required this.record,
  });

  final String message;
  final RequestRecord record;

  @override
  List<Object?> get props => [message, record];
}

/// Cubit managing single request details and actions (Task C017).
/// Strictly < 300 lines; depends exclusively on domain contract [RequestRepository].
final class RequestDetailCubit extends Cubit<RequestDetailState> {
  RequestDetailCubit({required RequestRepository repository})
      : _repository = repository,
        super(const RequestDetailInitial());

  final RequestRepository _repository;

  Future<void> loadDetail({
    required String collection,
    required String requestId,
  }) async {
    emit(const RequestDetailLoading());
    final result = await _repository.getDetail(
      collection: collection,
      requestId: requestId,
    );

    if (isClosed) return;

    switch (result) {
      case RequestDetailLoaded(:final record):
        emit(RequestDetailReady(record: record));
      case RequestDetailNotFound():
        emit(const RequestDetailNotFoundState());
      case RequestDetailFailure(:final errorMessage):
        emit(RequestDetailFailureState(errorMessage));
    }
  }

  Future<void> approve({
    required String actorId,
    String? note,
  }) async {
    final currentState = state;
    if (currentState is! RequestDetailReady || currentState.isActionInProgress) {
      return;
    }

    emit(currentState.copyWith(isActionInProgress: true));
    final record = currentState.record;

    final result = await _repository.approveRequest(
      collection: record.collection,
      requestId: record.id,
      actorId: actorId,
      note: note,
    );

    if (isClosed) return;

    switch (result) {
      case RequestActionSuccess(:final message):
        final updatedRecord = record.copyWith(
          status: RequestWorkspaceStatus.approved,
          isActionableByMe: false,
        );
        emit(RequestDetailActionSuccessState(message: message, record: updatedRecord));
      case RequestActionFailure(:final errorMessage):
        emit(currentState.copyWith(isActionInProgress: false));
        emit(RequestDetailFailureState(errorMessage));
    }
  }

  Future<void> reject({
    required String actorId,
    required String note,
  }) async {
    final currentState = state;
    if (currentState is! RequestDetailReady || currentState.isActionInProgress) {
      return;
    }

    emit(currentState.copyWith(isActionInProgress: true));
    final record = currentState.record;

    final result = await _repository.rejectRequest(
      collection: record.collection,
      requestId: record.id,
      actorId: actorId,
      note: note,
    );

    if (isClosed) return;

    switch (result) {
      case RequestActionSuccess(:final message):
        final updatedRecord = record.copyWith(
          status: RequestWorkspaceStatus.rejected,
          isActionableByMe: false,
        );
        emit(RequestDetailActionSuccessState(message: message, record: updatedRecord));
      case RequestActionFailure(:final errorMessage):
        emit(currentState.copyWith(isActionInProgress: false));
        emit(RequestDetailFailureState(errorMessage));
    }
  }

  Future<void> cancel({
    required String actorId,
    String? reason,
  }) async {
    final currentState = state;
    if (currentState is! RequestDetailReady || currentState.isActionInProgress) {
      return;
    }

    emit(currentState.copyWith(isActionInProgress: true));
    final record = currentState.record;

    final result = await _repository.cancelRequest(
      collection: record.collection,
      requestId: record.id,
      actorId: actorId,
      reason: reason,
    );

    if (isClosed) return;

    switch (result) {
      case RequestActionSuccess(:final message):
        final updatedRecord = record.copyWith(
          status: RequestWorkspaceStatus.cancelled,
          isActionableByMe: false,
        );
        emit(RequestDetailActionSuccessState(message: message, record: updatedRecord));
      case RequestActionFailure(:final errorMessage):
        emit(currentState.copyWith(isActionInProgress: false));
        emit(RequestDetailFailureState(errorMessage));
    }
  }
}
