import 'check_in_action.dart';

enum PendingCheckInState {
  pending,
  checkingStatus,
  saved,
  requiresAttention,
  rejected,
}

class PendingCheckIn {
  const PendingCheckIn({
    required this.action,
    required this.state,
    required this.attemptCount,
    required this.updatedAt,
  });

  final CheckInAction action;
  final PendingCheckInState state;
  final int attemptCount;
  final DateTime updatedAt;
}
