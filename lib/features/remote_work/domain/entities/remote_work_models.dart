/// Pure domain entities for remote work attendance (Feature 020).
///
/// Implements domain contracts from specs/020-remote-work-attendance/plan.md Section 4.
/// Strictly pure Dart (no Flutter UI, no Firebase/Firestore, no Dio).
library;

/// Represents verified actor scope and permissions within a specific company.
final class ActorScope {
  const ActorScope({
    required this.uid,
    required this.companyId,
    required this.capabilities,
    this.membershipVersion = 1,
  });

  final String uid;
  final String companyId;
  final List<String> capabilities;
  final int membershipVersion;

  bool hasCapability(String capability) => capabilities.contains(capability);

  factory ActorScope.fromMap(Map<String, dynamic> map) {
    return ActorScope(
      uid: '${map['uid'] ?? ''}',
      companyId: '${map['companyId'] ?? ''}',
      capabilities: List<String>.from(map['capabilities'] ?? const []),
      membershipVersion: (map['membershipVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'companyId': companyId,
    'capabilities': capabilities,
    'membershipVersion': membershipVersion,
  };
}

/// Represents a remote work command sent to the backend.
final class RemoteCommand {
  const RemoteCommand({
    required this.operationId,
    required this.kind,
    this.expectedVersion,
    this.sessionId,
    required this.payload,
    this.proof,
    this.date,
  });

  final String operationId;
  final String kind;
  final int? expectedVersion;
  final String? sessionId;
  final Map<String, dynamic> payload;
  final RemoteProof? proof;
  final String? date;

  Map<String, dynamic> toMap() => {
    'operationId': operationId,
    'kind': kind,
    if (expectedVersion != null) 'expectedVersion': expectedVersion,
    if (sessionId != null) 'sessionId': sessionId,
    if (date != null) 'date': date,
    'payload': payload,
    if (proof != null) 'proof': proof!.toMap(),
  };
}

/// Cryptographic and device proof accompanying an employee session action.
final class RemoteProof {
  const RemoteProof({
    required this.challengeId,
    required this.credentialId,
    required this.assertion,
    this.managedDeviceEvidence,
  });

  final String challengeId;
  final String credentialId;
  final Map<String, dynamic> assertion;
  final Map<String, dynamic>? managedDeviceEvidence;

  Map<String, dynamic> toMap() => {
    'challengeId': challengeId,
    'credentialId': credentialId,
    'assertion': assertion,
    if (managedDeviceEvidence != null) 'managedDeviceEvidence': managedDeviceEvidence,
  };
}

/// Immutable receipt returned for an executed or replayed command.
final class RemoteReceipt {
  const RemoteReceipt({
    required this.operationId,
    required this.status,
    this.attendanceId,
    this.sessionId,
    this.mode,
    required this.version,
    required this.serverTime,
  });

  final String operationId;
  final String status;
  final String? attendanceId;
  final String? sessionId;
  final String? mode;
  final int version;
  final DateTime serverTime;

  bool get isAlreadyRecorded => status == 'already_recorded';

  factory RemoteReceipt.fromMap(Map<String, dynamic> map) {
    return RemoteReceipt(
      operationId: '${map['operationId'] ?? ''}',
      status: '${map['status'] ?? ''}',
      attendanceId: map['attendanceId']?.toString(),
      sessionId: map['sessionId']?.toString(),
      mode: map['mode']?.toString(),
      version: (map['version'] as num?)?.toInt() ?? 0,
      serverTime: DateTime.tryParse('${map['serverTime'] ?? ''}') ?? DateTime.now(),
    );
  }
}

/// Evaluated remote work eligibility for an employee on a target date.
final class RemoteEligibility {
  const RemoteEligibility({
    required this.eligible,
    required this.reason,
    required this.date,
    required this.weekStart,
    this.policyVersion,
    this.scheduleVersion,
    this.employeeEpoch,
    this.calendarEpoch,
  });

  final bool eligible;
  final String reason;
  final String date;
  final String weekStart;
  final int? policyVersion;
  final int? scheduleVersion;
  final int? employeeEpoch;
  final int? calendarEpoch;

  factory RemoteEligibility.fromMap(Map<String, dynamic> map) {
    return RemoteEligibility(
      eligible: map['eligible'] == true,
      reason: '${map['reason'] ?? ''}',
      date: '${map['date'] ?? ''}',
      weekStart: '${map['weekStart'] ?? ''}',
      policyVersion: (map['policyVersion'] as num?)?.toInt(),
      scheduleVersion: (map['scheduleVersion'] as num?)?.toInt(),
      employeeEpoch: (map['employeeEpoch'] as num?)?.toInt(),
      calendarEpoch: (map['calendarEpoch'] as num?)?.toInt(),
    );
  }
}

/// Scoped schedule for an employee defining allowed recurring remote weekdays.
final class RemoteSchedule {
  const RemoteSchedule({
    required this.scheduleId,
    required this.employeeId,
    required this.companyId,
    required this.startDate,
    required this.endDate,
    required this.weekdays,
    required this.status,
    required this.version,
  });

  final String scheduleId;
  final String employeeId;
  final String companyId;
  final String startDate;
  final String endDate;
  final List<int> weekdays;
  final String status;
  final int version;

  factory RemoteSchedule.fromMap(Map<String, dynamic> map) {
    return RemoteSchedule(
      scheduleId: '${map['scheduleId'] ?? ''}',
      employeeId: '${map['employeeId'] ?? ''}',
      companyId: '${map['companyId'] ?? ''}',
      startDate: '${map['startDate'] ?? ''}',
      endDate: '${map['endDate'] ?? ''}',
      weekdays: List<int>.from(map['weekdays'] ?? const []),
      status: '${map['status'] ?? 'pending'}',
      version: (map['version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
    'scheduleId': scheduleId,
    'employeeId': employeeId,
    'companyId': companyId,
    'startDate': startDate,
    'endDate': endDate,
    'weekdays': weekdays,
    'status': status,
    'version': version,
  };
}

/// Weekly exception replacing or adding a remote work date within a week.
final class WeeklyRemoteException {
  const WeeklyRemoteException({
    required this.exceptionId,
    required this.employeeId,
    required this.weekStart,
    required this.action, // 'replace' | 'add'
    this.originalDate,
    required this.targetDate,
    required this.status,
    required this.version,
  });

  final String exceptionId;
  final String employeeId;
  final String weekStart;
  final String action;
  final String? originalDate;
  final String targetDate;
  final String status;
  final int version;

  factory WeeklyRemoteException.fromMap(Map<String, dynamic> map) {
    return WeeklyRemoteException(
      exceptionId: '${map['exceptionId'] ?? ''}',
      employeeId: '${map['employeeId'] ?? ''}',
      weekStart: '${map['weekStart'] ?? ''}',
      action: '${map['action'] ?? 'replace'}',
      originalDate: map['originalDate']?.toString(),
      targetDate: '${map['targetDate'] ?? ''}',
      status: '${map['status'] ?? 'pending'}',
      version: (map['version'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Domain exception for remote work operations.
final class RemoteWorkDomainException implements Exception {
  const RemoteWorkDomainException(this.code, this.messageAr, [this.details]);

  final String code;
  final String messageAr;
  final Map<String, dynamic>? details;

  @override
  String toString() => 'RemoteWorkDomainException [$code]: $messageAr';
}
