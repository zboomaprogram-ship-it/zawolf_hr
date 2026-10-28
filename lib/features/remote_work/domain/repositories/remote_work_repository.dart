import '../entities/remote_work_models.dart';

/// Abstract domain repository contract for Remote Work operations (Feature 020).
/// Strictly pure Dart (no infrastructure/data/Flutter UI coupling).
abstract interface class RemoteWorkRepository {
  /// Fetches paginated remote work attendance days for an employee.
  Future<List<Map<String, dynamic>>> listRemoteDays({
    String? userId,
    int limit = 50,
    String? cursor,
  });

  /// Evaluates remote work eligibility for an employee on a target date.
  Future<RemoteEligibility> evaluateEligibility({
    required String employeeId,
    required DateTime date,
  });

  /// Submits an attendance command (check_in or check_out) with verified proof.
  Future<RemoteReceipt> submitAttendanceCommand(RemoteCommand command);

  /// Submits a remote work session command (save_plan, submit_update, save_summary).
  Future<RemoteReceipt> submitSessionCommand(RemoteCommand command);

  /// Submits a schedule or weekly exception command.
  Future<RemoteReceipt> submitScheduleCommand(RemoteCommand command);

  /// Submits an IT incident declaration or HR financial hold resolution command.
  Future<RemoteReceipt> submitIncidentCommand(RemoteCommand command);
}
