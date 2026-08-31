import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/request_view_query.dart';
import '../../domain/entities/request_visibility_record.dart';
import '../../domain/repositories/request_visibility_repository.dart';

final class RequestVisibilityState {
  const RequestVisibilityState({
    this.records = const <RequestVisibilityRecord>[],
    this.loading = false,
    this.nextCursor,
    this.safeMessage,
    this.accessDenied = false,
  });

  final List<RequestVisibilityRecord> records;
  final bool loading;
  final String? nextCursor;
  final String? safeMessage;
  final bool accessDenied;

  bool get hasMore => nextCursor != null;
}

final class RequestVisibilityCubit extends Cubit<RequestVisibilityState> {
  RequestVisibilityCubit(this._repository)
    : super(const RequestVisibilityState());

  final RequestVisibilityRepository _repository;
  RequestViewQuery? _query;

  Future<void> load(RequestViewQuery query) async {
    _query = query;
    emit(const RequestVisibilityState(loading: true));
    await _load(query, append: false);
  }

  Future<void> retry() async {
    final query = _query;
    if (query != null) await load(query);
  }

  Future<void> loadMore() async {
    final query = _query;
    if (query == null || state.loading || !state.hasMore) return;
    emit(
      RequestVisibilityState(
        records: state.records,
        loading: true,
        nextCursor: state.nextCursor,
      ),
    );
    await _load(
      RequestViewQuery(
        actorScope: query.actorScope,
        tab: query.tab,
        fromDate: query.fromDate,
        toDate: query.toDate,
        employeeScopeIds: query.employeeScopeIds,
        searchTerm: query.searchTerm,
        pageCursor: state.nextCursor,
        pageSize: query.pageSize,
      ),
      append: true,
    );
  }

  Future<void> _load(RequestViewQuery query, {required bool append}) async {
    final result = await _repository.load(query);
    switch (result) {
      case RequestViewLoaded(:final records, :final nextCursor):
        emit(
          RequestVisibilityState(
            records: [if (append) ...state.records, ...records],
            nextCursor: nextCursor,
          ),
        );
      case RequestViewEmpty():
        emit(
          RequestVisibilityState(records: append ? state.records : const []),
        );
      case RequestViewAccessDenied(:final safeMessage):
        emit(
          RequestVisibilityState(
            records: append ? state.records : const [],
            safeMessage: safeMessage,
            accessDenied: true,
          ),
        );
      case RequestViewRetryableFailure(:final safeMessage):
        emit(
          RequestVisibilityState(
            records: append ? state.records : const [],
            safeMessage: safeMessage,
          ),
        );
    }
  }
}
