import '../entities/remote_policy.dart';

abstract interface class RemotePolicyRepository {
  Future<Map<String, dynamic>> loadSchema();

  Future<RemotePolicyAggregate> loadCurrent();

  Future<Map<String, dynamic>> loadDraft(String draftId);

  Future<RemotePolicyCommandReceipt> saveDraft({
    required String operationId,
    required String draftId,
    required int expectedVersion,
    required RemotePolicyAggregate aggregate,
    required DateTime effectiveFrom,
  });

  Future<Map<String, dynamic>> preview({
    required RemotePolicyAggregate aggregate,
    required String employeeId,
    required DateTime date,
  });

  Future<RemotePolicyCommandReceipt> approve({
    required String operationId,
    required String draftId,
    required int expectedVersion,
    required String reason,
  });

  Future<RemotePolicyCommandReceipt> publish({
    required String operationId,
    required String draftId,
    required int expectedVersion,
    required DateTime effectiveFrom,
  });

  Future<RemotePolicyCommandReceipt> revert({
    required String operationId,
    required String draftId,
    required String targetRevisionId,
    required DateTime effectiveFrom,
  });

  Future<Map<String, dynamic>> loadHistory({int limit = 50, String? cursor});
}
