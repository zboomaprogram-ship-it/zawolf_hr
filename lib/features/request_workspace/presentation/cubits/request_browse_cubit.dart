import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/request_record.dart';
import '../../domain/repositories/request_repository.dart';

sealed class RequestBrowseState extends Equatable {
  const RequestBrowseState();

  @override
  List<Object?> get props => [];
}

final class RequestBrowseInitial extends RequestBrowseState {
  const RequestBrowseInitial();
}

final class RequestBrowseLoading extends RequestBrowseState {
  const RequestBrowseLoading({
    this.staleRecords = const [],
    this.filter,
  });

  final List<RequestRecord> staleRecords;
  final RequestWorkspaceFilter? filter;

  @override
  List<Object?> get props => [staleRecords, filter];
}

final class RequestBrowseLoaded extends RequestBrowseState {
  const RequestBrowseLoaded({
    required this.records,
    this.filter,
    this.nextCursor,
    this.isRefreshing = false,
  });

  final List<RequestRecord> records;
  final RequestWorkspaceFilter? filter;
  final String? nextCursor;
  final bool isRefreshing;

  bool get hasMore => nextCursor != null;

  RequestBrowseLoaded copyWith({
    List<RequestRecord>? records,
    RequestWorkspaceFilter? filter,
    String? nextCursor,
    bool? isRefreshing,
  }) {
    return RequestBrowseLoaded(
      records: records ?? this.records,
      filter: filter ?? this.filter,
      nextCursor: nextCursor ?? this.nextCursor,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [records, filter, nextCursor, isRefreshing];
}

final class RequestBrowseEmpty extends RequestBrowseState {
  const RequestBrowseEmpty({this.filter});
  final RequestWorkspaceFilter? filter;

  @override
  List<Object?> get props => [filter];
}

final class RequestBrowseFailure extends RequestBrowseState {
  const RequestBrowseFailure(
    this.errorMessage, {
    this.filter,
    this.staleRecords = const [],
  });

  final String errorMessage;
  final RequestWorkspaceFilter? filter;
  final List<RequestRecord> staleRecords;

  @override
  List<Object?> get props => [errorMessage, filter, staleRecords];
}

/// Cubit managing browsing, filtering, and pagination of organizational requests (Task C016).
/// Strictly < 300 lines; depends exclusively on [RequestRepository].
final class RequestBrowseCubit extends Cubit<RequestBrowseState> {
  RequestBrowseCubit({required RequestRepository repository})
      : _repository = repository,
        super(const RequestBrowseInitial());

  final RequestRepository _repository;
  int _activeGeneration = 0;
  RequestWorkspaceFilter? _currentFilter;

  Future<void> load({
    required String actorId,
    required String companyId,
    RequestWorkspaceFilter? filter,
    bool refresh = false,
  }) async {
    _currentFilter = filter ?? _currentFilter;
    final generation = ++_activeGeneration;

    final currentRecords = switch (state) {
      RequestBrowseLoaded(:final records) => records,
      RequestBrowseLoading(:final staleRecords) => staleRecords,
      RequestBrowseFailure(:final staleRecords) => staleRecords,
      _ => const <RequestRecord>[],
    };

    if (currentRecords.isNotEmpty) {
      if (state is RequestBrowseLoaded) {
        emit((state as RequestBrowseLoaded).copyWith(isRefreshing: true, filter: _currentFilter));
      } else {
        emit(RequestBrowseLoading(staleRecords: currentRecords, filter: _currentFilter));
      }
    } else {
      emit(RequestBrowseLoading(filter: _currentFilter));
    }

    final result = await _repository.getBrowseRequests(
      actorId: actorId,
      companyId: companyId,
      filter: _currentFilter,
      limit: 20,
    );

    if (isClosed || generation != _activeGeneration) return;

    switch (result) {
      case RequestListLoaded(:final records, :final nextCursor):
        if (records.isEmpty) {
          emit(RequestBrowseEmpty(filter: _currentFilter));
        } else {
          emit(
            RequestBrowseLoaded(
              records: records,
              filter: _currentFilter,
              nextCursor: nextCursor,
            ),
          );
        }
      case RequestListEmpty():
        emit(RequestBrowseEmpty(filter: _currentFilter));
      case RequestListFailure(:final errorMessage):
        emit(
          RequestBrowseFailure(
            errorMessage,
            filter: _currentFilter,
            staleRecords: currentRecords,
          ),
        );
    }
  }

  Future<void> updateFilter(
    RequestWorkspaceFilter filter, {
    required String actorId,
    required String companyId,
  }) async {
    _currentFilter = filter;
    await load(actorId: actorId, companyId: companyId, filter: filter);
  }

  Future<void> loadMore({
    required String actorId,
    required String companyId,
  }) async {
    final currentState = state;
    if (currentState is! RequestBrowseLoaded || !currentState.hasMore || currentState.isRefreshing) {
      return;
    }

    final generation = ++_activeGeneration;
    final result = await _repository.getBrowseRequests(
      actorId: actorId,
      companyId: companyId,
      filter: currentState.filter,
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
}
