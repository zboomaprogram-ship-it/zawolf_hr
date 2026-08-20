import '../../../../core/errors/app_failure.dart';
import 'check_in_receipt.dart';
import 'pending_check_in.dart';

enum CheckInViewStatus {
  idle,
  submitting,
  saved,
  pendingSync,
  requiresStatusCheck,
  failed,
}

class CheckInPresentationState {
  const CheckInPresentationState({
    this.status = CheckInViewStatus.idle,
    this.receipt,
    this.pending,
    this.failure,
  });

  final CheckInViewStatus status;
  final CheckInReceipt? receipt;
  final PendingCheckIn? pending;
  final AppFailure? failure;
}
