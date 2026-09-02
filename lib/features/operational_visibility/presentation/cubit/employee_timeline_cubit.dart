import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/employee_timeline_entry.dart';
import '../../domain/entities/employee_timeline_query.dart';
import '../../domain/repositories/operational_visibility_repository.dart';

final class EmployeeTimelineState {
  const EmployeeTimelineState({
    this.items = const [],
    this.loading = false,
    this.hasMore = false,
    this.summary = const EmployeeTimelineSummary(),
    this.nextCursor,
    this.safeErrorCode,
  });

  final List<EmployeeTimelineEntry> items;
  final bool loading;
  final bool hasMore;
  final EmployeeTimelineSummary summary;
  final String? nextCursor;
  final String? safeErrorCode;
}

final class EmployeeTimelineCubit extends Cubit<EmployeeTimelineState> {
  EmployeeTimelineCubit(this._repository)
    : super(const EmployeeTimelineState());

  final OperationalVisibilityRepository _repository;
  EmployeeTimelineQuery? _query;

  Future<void> load(EmployeeTimelineQuery query) async {
    _query = query;
    emit(const EmployeeTimelineState(loading: true));
    await _load(query, append: false);
  }

  Future<void> loadMore() async {
    final query = _query;
    if (query == null || !state.hasMore || state.loading) return;
    emit(
      EmployeeTimelineState(
        items: state.items,
        loading: true,
        hasMore: state.hasMore,
        summary: state.summary,
        nextCursor: state.nextCursor,
      ),
    );
    await _load(
      EmployeeTimelineQuery(
        employeeUserId: query.employeeUserId,
        from: query.from,
        to: query.to,
        pageSize: query.pageSize,
        cursor: state.nextCursor,
      ),
      append: true,
    );
  }

  Future<void> _load(
    EmployeeTimelineQuery query, {
    required bool append,
  }) async {
    try {
      final page = await _repository.loadTimeline(query);
      emit(
        EmployeeTimelineState(
          items: [if (append) ...state.items, ...page.items],
          hasMore: page.hasMore,
          summary: page.summary,
          nextCursor: page.nextCursor,
        ),
      );
    } catch (_) {
      emit(
        EmployeeTimelineState(
          items: append ? state.items : const [],
          safeErrorCode: 'temporarily_unavailable',
        ),
      );
    }
  }
}
