/// Domain snapshot of the unified attendance and remote-work policy.
///
/// Maps are JSON-compatible business data. Runtime consumers resolve shared
/// values before applying remote overrides; the dashboard schema validates
/// their supported shape on the server.
final class RemotePolicyAggregate {
  const RemotePolicyAggregate({
    required this.attendancePolicy,
    required this.remoteWorkPolicy,
    this.revision = 0,
    this.version = 0,
  });

  final Map<String, dynamic> attendancePolicy;
  final Map<String, dynamic> remoteWorkPolicy;
  final int revision;
  final int version;

  factory RemotePolicyAggregate.fromMap(Map<String, dynamic> map) {
    final attendance = map['attendancePolicy'];
    final rawRemote = map['remoteWorkPolicy'];
    final attendancePolicy =
        attendance is Map
            ? Map<String, dynamic>.from(attendance)
            : <String, dynamic>{};
    final remote =
        rawRemote is Map
            ? Map<String, dynamic>.from(rawRemote)
            : attendancePolicy['remoteWorkPolicy'] is Map
            ? Map<String, dynamic>.from(
              attendancePolicy['remoteWorkPolicy'] as Map,
            )
            : <String, dynamic>{};
    return RemotePolicyAggregate(
      attendancePolicy: attendancePolicy,
      remoteWorkPolicy: remote,
      revision: (map['revision'] as num?)?.toInt() ?? 0,
      version: (map['version'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toAggregateMap() => {
    'attendancePolicy': {
      ...attendancePolicy,
      'remoteWorkPolicy': remoteWorkPolicy,
    },
    'remoteWorkPolicy': remoteWorkPolicy,
  };
}

final class RemotePolicyCommandReceipt {
  const RemotePolicyCommandReceipt({
    required this.operationId,
    required this.draftId,
    required this.status,
    required this.version,
    this.revision,
    this.revisionId,
    this.effectiveFrom,
  });

  final String operationId;
  final String draftId;
  final String status;
  final int version;
  final int? revision;
  final String? revisionId;
  final DateTime? effectiveFrom;

  factory RemotePolicyCommandReceipt.fromMap(Map<String, dynamic> map) =>
      RemotePolicyCommandReceipt(
        operationId: '${map['operationId'] ?? ''}',
        draftId: '${map['draftId'] ?? ''}',
        status: '${map['status'] ?? ''}',
        version: (map['version'] as num?)?.toInt() ?? 0,
        revision: (map['revision'] as num?)?.toInt(),
        revisionId: map['revisionId']?.toString(),
        effectiveFrom: DateTime.tryParse('${map['effectiveFrom'] ?? ''}'),
      );
}

final class RemotePolicyException implements Exception {
  const RemotePolicyException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}
