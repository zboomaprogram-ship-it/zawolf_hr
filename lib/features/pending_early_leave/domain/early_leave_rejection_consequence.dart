enum EarlyLeaveConsequenceStatus {
  none,
  pendingHr,
  approved,
  rejected,
  reversed,
}

final class EarlyLeaveRejectionConsequence {
  const EarlyLeaveRejectionConsequence({
    required this.id,
    required this.attendanceId,
    required this.executionDate,
    required this.requestedMinutes,
    required this.dayFraction,
    required this.status,
    this.amount = 0,
    this.currency = 'EGP',
    this.rejectionReason,
    this.actualCheckoutAt,
  });

  final String id;
  final String attendanceId;
  final String executionDate;
  final int requestedMinutes;
  final double dayFraction;
  final double amount;
  final String currency;
  final EarlyLeaveConsequenceStatus status;
  final String? rejectionReason;
  final DateTime? actualCheckoutAt;

  bool get affectsPayroll => status == EarlyLeaveConsequenceStatus.approved;
}
