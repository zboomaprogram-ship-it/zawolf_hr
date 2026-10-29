import '../entities/request_record.dart';

final class RequestWorkspaceFilter {
  const RequestWorkspaceFilter({
    this.category,
    this.status,
    this.department,
    this.fromDate,
    this.toDate,
    this.searchTerm,
  });

  final RequestWorkspaceCategory? category;
  final RequestWorkspaceStatus? status;
  final String? department;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? searchTerm;
}

sealed class RequestListResult {
  const RequestListResult();
}

final class RequestListLoaded extends RequestListResult {
  const RequestListLoaded({
    required this.records,
    this.nextCursor,
    this.totalCount,
  });

  final List<RequestRecord> records;
  final String? nextCursor;
  final int? totalCount;
}

final class RequestListEmpty extends RequestListResult {
  const RequestListEmpty();
}

final class RequestListFailure extends RequestListResult {
  const RequestListFailure(this.errorMessage);
  final String errorMessage;
}

sealed class RequestDetailResult {
  const RequestDetailResult();
}

final class RequestDetailLoaded extends RequestDetailResult {
  const RequestDetailLoaded(this.record);
  final RequestRecord record;
}

final class RequestDetailNotFound extends RequestDetailResult {
  const RequestDetailNotFound();
}

final class RequestDetailFailure extends RequestDetailResult {
  const RequestDetailFailure(this.errorMessage);
  final String errorMessage;
}

sealed class RequestActionResult {
  const RequestActionResult();
}

final class RequestActionSuccess extends RequestActionResult {
  const RequestActionSuccess({required this.message});
  final String message;
}

final class RequestActionFailure extends RequestActionResult {
  const RequestActionFailure(this.errorMessage);
  final String errorMessage;
}

/// Domain contract for organizational requests operations (Task C014).
/// Pure Dart: zero UI/infrastructure coupling.
abstract interface class RequestRepository {
  /// Fetches pending requests requiring action by [actorId].
  Future<RequestListResult> getPendingQueue({
    required String actorId,
    required String companyId,
    String? cursor,
    int limit = 20,
  });

  /// Fetches all requests accessible to [actorId] matching optional [filter].
  Future<RequestListResult> getBrowseRequests({
    required String actorId,
    required String companyId,
    RequestWorkspaceFilter? filter,
    String? cursor,
    int limit = 20,
  });

  /// Fetches request history created by [actorId].
  Future<RequestListResult> getMyHistory({
    required String actorId,
    required String companyId,
    String? cursor,
    int limit = 20,
  });

  /// Fetches single request detail with full timeline history.
  Future<RequestDetailResult> getDetail({
    required String collection,
    required String requestId,
  });

  /// Approves a pending request step.
  Future<RequestActionResult> approveRequest({
    required String collection,
    required String requestId,
    required String actorId,
    String? note,
  });

  /// Rejects a pending request step.
  Future<RequestActionResult> rejectRequest({
    required String collection,
    required String requestId,
    required String actorId,
    required String note,
  });

  /// Cancels an open request by the requester.
  Future<RequestActionResult> cancelRequest({
    required String collection,
    required String requestId,
    required String actorId,
    String? reason,
  });
}
