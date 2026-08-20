import '../../../../core/errors/operation_result.dart';
import '../entities/check_in_action.dart';
import '../entities/check_in_receipt.dart';
import '../entities/check_in_status_resolution.dart';
import '../entities/pending_check_in.dart';

abstract interface class AttendanceCheckInRepository {
  Future<OperationResult<CheckInReceipt>> submit(CheckInAction action);

  Future<CheckInStatusResolution> resolveStatus(CheckInAction action);

  Future<PendingCheckIn?> pendingFor(String employeeScopeId);

  Future<OperationResult<CheckInReceipt>?> synchronizePending(
    String employeeScopeId,
  );
}
