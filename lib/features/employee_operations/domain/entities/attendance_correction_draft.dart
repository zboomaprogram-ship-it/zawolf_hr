/// Validated correction intent; persistence and reviewer routing are outside
/// this entity. The original attendance day remains the accounting date.
final class AttendanceCorrectionDraft {
  factory AttendanceCorrectionDraft.create({
    required String attendanceId,
    required DateTime originalCheckIn,
    required DateTime requestedCheckIn,
    required String reason,
    required String operationId,
  }) {
    final cleanReason = reason.trim();
    if (attendanceId.trim().isEmpty || operationId.trim().isEmpty) {
      throw ArgumentError('سجل الحضور أو معرّف العملية غير صالح.');
    }
    if (cleanReason.length < 5) {
      throw ArgumentError('اكتب سبب التصحيح بوضوح.');
    }
    if (!_isSameDate(originalCheckIn, requestedCheckIn)) {
      throw ArgumentError('وقت التصحيح يجب أن يكون في يوم الحضور نفسه.');
    }
    if (requestedCheckIn.isAfter(originalCheckIn)) {
      throw ArgumentError('وقت الوصول المقترح يجب ألا يكون بعد الوقت المسجل.');
    }
    return AttendanceCorrectionDraft._(
      attendanceId: attendanceId.trim(),
      originalCheckIn: originalCheckIn,
      requestedCheckIn: requestedCheckIn,
      reason: cleanReason,
      operationId: operationId.trim(),
    );
  }

  const AttendanceCorrectionDraft._({
    required this.attendanceId,
    required this.originalCheckIn,
    required this.requestedCheckIn,
    required this.reason,
    required this.operationId,
  });

  final String attendanceId;
  final DateTime originalCheckIn;
  final DateTime requestedCheckIn;
  final String reason;
  final String operationId;

  static bool _isSameDate(DateTime left, DateTime right) =>
      left.year == right.year && left.month == right.month && left.day == right.day;
}
