import '../entities/request_view_query.dart';
import '../entities/request_visibility_record.dart';

sealed class RequestViewResult {
  const RequestViewResult();
}

final class RequestViewLoaded extends RequestViewResult {
  const RequestViewLoaded(this.records, {this.nextCursor});
  final List<RequestVisibilityRecord> records;
  final String? nextCursor;
}

final class RequestViewEmpty extends RequestViewResult {
  const RequestViewEmpty();
}

final class RequestViewRetryableFailure extends RequestViewResult {
  const RequestViewRetryableFailure(this.safeMessage);
  final String safeMessage;
}

final class RequestViewAccessDenied extends RequestViewResult {
  const RequestViewAccessDenied(this.safeMessage);
  final String safeMessage;
}

abstract interface class RequestVisibilityRepository {
  Future<RequestViewResult> load(RequestViewQuery query);
}
