class WebAttendanceAccessGrant {
  const WebAttendanceAccessGrant({
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.scope,
    required this.status,
    required this.revision,
    this.startDate,
    this.endDate,
    this.note,
  });
  final String employeeId, employeeName, employeeCode, scope, status;
  final int revision;
  final String? startDate, endDate, note;
  bool get permanent => scope == 'permanent';
  bool get active => status == 'active';
  factory WebAttendanceAccessGrant.fromJson(Map<String, Object?> json) =>
      WebAttendanceAccessGrant(
        employeeId: '${json['employeeId'] ?? ''}',
        employeeName: '${json['employeeName'] ?? ''}',
        employeeCode: '${json['employeeCode'] ?? ''}',
        scope: '${json['scope'] ?? 'period'}',
        status: '${json['status'] ?? ''}',
        revision: (json['revision'] as num?)?.toInt() ?? 0,
        startDate: json['startDate'] as String?,
        endDate: json['endDate'] as String?,
        note: json['note'] as String?,
      );
}

class WebAttendanceEmployee {
  const WebAttendanceEmployee({
    required this.id,
    required this.name,
    required this.code,
    required this.position,
  });
  final String id, name, code, position;
}
