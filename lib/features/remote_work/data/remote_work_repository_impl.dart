import '../domain/entities/remote_work_models.dart';
import '../domain/repositories/remote_work_repository.dart';
import 'remote_work_api.dart';

final class RemoteWorkRepositoryImpl implements RemoteWorkRepository {
  RemoteWorkRepositoryImpl({RemoteWorkApi? api})
      : _api = api ?? RemoteWorkApi();

  final RemoteWorkApi _api;
  static const _base = '/attendance/remote-work';

  @override
  Future<List<Map<String, dynamic>>> listRemoteDays({
    String? userId,
    int limit = 50,
    String? cursor,
  }) async {
    final query = <String, String>{
      'limit': limit.toString(),
      if (userId != null) 'userId': userId,
      if (cursor != null) 'cursor': cursor,
    };
    final response = await _api.get('$_base/days', query: query);
    final items = response['items'];
    if (items is List) {
      return items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  @override
  Future<RemoteEligibility> evaluateEligibility({
    required String employeeId,
    required DateTime date,
  }) async {
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final response = await _api.post(
      '$_base/eligibility/evaluate',
      operationId: 'eval-$employeeId-$dateKey-${DateTime.now().microsecondsSinceEpoch}',
      body: {
        'employeeId': employeeId,
        'date': dateKey,
      },
    );
    return RemoteEligibility.fromMap({
      ...response,
      'date': response['date'] ?? dateKey,
      'weekStart': response['weekStart'] ?? dateKey,
    });
  }

  @override
  Future<RemoteReceipt> submitAttendanceCommand(RemoteCommand command) =>
      _sendCommand(command);

  @override
  Future<RemoteReceipt> submitSessionCommand(RemoteCommand command) =>
      _sendCommand(command);

  @override
  Future<RemoteReceipt> submitScheduleCommand(RemoteCommand command) =>
      _sendCommand(command);

  @override
  Future<RemoteReceipt> submitIncidentCommand(RemoteCommand command) =>
      _sendCommand(command);

  Future<RemoteReceipt> _sendCommand(RemoteCommand command) async {
    final response = await _api.post(
      '$_base/commands',
      operationId: command.operationId,
      body: {
        'command': command.toMap(),
      },
    );
    return RemoteReceipt(
      operationId: command.operationId,
      status: response['status'] as String? ?? 'unknown',
      attendanceId: response['attendanceId'] as String?,
      sessionId: response['sessionId'] as String?,
      mode: response['mode'] as String?,
      version: (response['version'] as num?)?.toInt() ?? 1,
      serverTime: DateTime.tryParse(response['serverTime'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

RemoteWorkRepository createRemoteWorkRepository({RemoteWorkApi? api}) =>
    RemoteWorkRepositoryImpl(api: api);
