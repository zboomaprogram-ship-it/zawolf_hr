import '../../domain/entities/pending_check_in.dart';

abstract interface class CheckInOutbox {
  Future<void> put(PendingCheckIn item);

  Future<PendingCheckIn?> getForEmployee(String employeeScopeId);

  Future<void> remove(String actionId, String employeeScopeId);
}
