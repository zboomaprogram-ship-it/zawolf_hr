import '../domain/entities/remote_policy.dart';
import '../domain/repositories/remote_policy_repository.dart';
import 'remote_policy_api.dart';

final class RemotePolicyRepositoryImpl implements RemotePolicyRepository {
  RemotePolicyRepositoryImpl({RemotePolicyApi? api})
    : _api = api ?? RemotePolicyApi();

  final RemotePolicyApi _api;
  static const _base = '/attendance/remote-work';

  @override
  Future<Map<String, dynamic>> loadSchema() => _api.get('$_base/policy-schema');

  @override
  Future<RemotePolicyAggregate> loadCurrent() async {
    final value = await _api.get('$_base/policies/current');
    final attendancePolicy = value['attendancePolicy'];
    final head = value['head'];
    return RemotePolicyAggregate(
      attendancePolicy:
          attendancePolicy is Map
              ? Map<String, dynamic>.from(attendancePolicy)
              : <String, dynamic>{},
      remoteWorkPolicy:
          attendancePolicy is Map && attendancePolicy['remoteWorkPolicy'] is Map
              ? Map<String, dynamic>.from(
                attendancePolicy['remoteWorkPolicy'] as Map,
              )
              : <String, dynamic>{},
      revision:
          head is Map ? (head['activeRevision'] as num?)?.toInt() ?? 0 : 0,
      version: head is Map ? (head['version'] as num?)?.toInt() ?? 0 : 0,
    );
  }

  @override
  Future<Map<String, dynamic>> loadDraft(String draftId) =>
      _api.get('$_base/policies/drafts/${Uri.encodeComponent(draftId)}');

  @override
  Future<RemotePolicyCommandReceipt> saveDraft({
    required String operationId,
    required String draftId,
    required int expectedVersion,
    required RemotePolicyAggregate aggregate,
    required DateTime effectiveFrom,
  }) => _command(
    operationId: operationId,
    command: {
      'operationId': operationId,
      'kind': 'save_policy_draft',
      'draftId': draftId,
      'expectedVersion': expectedVersion,
      'payload': {
        'aggregate': aggregate.toAggregateMap(),
        'effectiveFrom': effectiveFrom.toUtc().toIso8601String(),
      },
    },
  );

  @override
  Future<Map<String, dynamic>> preview({
    required RemotePolicyAggregate aggregate,
    required String employeeId,
    required DateTime date,
  }) => _api.post(
    '$_base/policies/preview',
    operationId:
        'remote-policy-preview-${DateTime.now().microsecondsSinceEpoch}',
    body: {
      'aggregate': aggregate.toAggregateMap(),
      'employeeId': employeeId,
      'date': _dateKey(date),
    },
  );

  @override
  Future<RemotePolicyCommandReceipt> approve({
    required String operationId,
    required String draftId,
    required int expectedVersion,
    required String reason,
  }) => _command(
    operationId: operationId,
    command: {
      'operationId': operationId,
      'kind': 'approve_policy',
      'draftId': draftId,
      'expectedVersion': expectedVersion,
      'payload': {'decision': 'approved', 'reason': reason},
    },
  );

  @override
  Future<RemotePolicyCommandReceipt> publish({
    required String operationId,
    required String draftId,
    required int expectedVersion,
    required DateTime effectiveFrom,
  }) => _command(
    operationId: operationId,
    command: {
      'operationId': operationId,
      'kind': 'publish_policy',
      'draftId': draftId,
      'expectedVersion': expectedVersion,
      'payload': {'effectiveFrom': effectiveFrom.toUtc().toIso8601String()},
    },
  );

  @override
  Future<RemotePolicyCommandReceipt> revert({
    required String operationId,
    required String draftId,
    required String targetRevisionId,
    required DateTime effectiveFrom,
  }) => _command(
    operationId: operationId,
    command: {
      'operationId': operationId,
      'kind': 'revert_policy',
      'draftId': draftId,
      'expectedVersion': 0,
      'payload': {
        'targetRevisionId': targetRevisionId,
        'effectiveFrom': effectiveFrom.toUtc().toIso8601String(),
      },
    },
  );

  @override
  Future<Map<String, dynamic>> loadHistory({int limit = 50, String? cursor}) {
    final boundedLimit = limit.clamp(1, 100);
    final suffix = <String>['limit=$boundedLimit'];
    if (cursor != null && cursor.trim().isNotEmpty) {
      suffix.add('cursor=${Uri.encodeQueryComponent(cursor)}');
    }
    return _api.get('$_base/policies/history?${suffix.join('&')}');
  }

  Future<RemotePolicyCommandReceipt> _command({
    required String operationId,
    required Map<String, Object?> command,
  }) async {
    final result = await _api.post(
      '$_base/policies/commands',
      operationId: operationId,
      body: {'command': command},
    );
    return RemotePolicyCommandReceipt.fromMap(result);
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
