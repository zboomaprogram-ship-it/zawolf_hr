import '../../../../core/errors/operation_result.dart';
import '../entities/check_in_receipt.dart';
import '../repositories/attendance_check_in_repository.dart';

class SynchronizePendingCheckIn {
  const SynchronizePendingCheckIn(this._repository);

  final AttendanceCheckInRepository _repository;

  Future<OperationResult<CheckInReceipt>?> call(String employeeScopeId) {
    return _repository.synchronizePending(employeeScopeId);
  }
}
