import 'company_os_sync_state.dart';

final class CompanyOsPendingOperation {
  const CompanyOsPendingOperation({
    required this.operationId,
    required this.actorUid,
    required this.operationType,
    required this.targetId,
    required this.payload,
    required this.state,
    required this.attemptCount,
    required this.nextAttemptAt,
    required this.createdAt,
    this.expectedVersion,
    this.lastSafeCode,
  });

  final String operationId;
  final String actorUid;
  final String operationType;
  final String targetId;
  final Map<String, Object?> payload;
  final int? expectedVersion;
  final CompanyOsSyncState state;
  final int attemptCount;
  final DateTime nextAttemptAt;
  final DateTime createdAt;
  final String? lastSafeCode;

  CompanyOsPendingOperation retryAfter(Duration delay, DateTime now) =>
      CompanyOsPendingOperation(
        operationId: operationId,
        actorUid: actorUid,
        operationType: operationType,
        targetId: targetId,
        payload: payload,
        expectedVersion: expectedVersion,
        state: CompanyOsSyncState.pending,
        attemptCount: attemptCount + 1,
        nextAttemptAt: now.toUtc().add(delay),
        createdAt: createdAt,
        lastSafeCode: lastSafeCode,
      );
}
