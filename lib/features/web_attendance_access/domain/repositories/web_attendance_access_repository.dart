import '../entities/web_attendance_access_grant.dart';

abstract interface class WebAttendanceAccessRepository {
  Future<WebAttendanceAccessGrant?> myActiveGrant();
  Future<List<WebAttendanceAccessGrant>> listGrants();
  Future<List<WebAttendanceEmployee>> listActiveEmployees();
  Future<void> saveGrant({
    required String employeeId,
    required String scope,
    String? startDate,
    String? endDate,
    String? note,
  });
  Future<void> revokeGrant({required String employeeId, String? note});
}
