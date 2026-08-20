import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/attendance_checkin/data/attendance_checkin_repository_impl.dart';
import 'package:zawolf_hr/features/attendance_checkin/data/local/checkin_outbox.dart';
import 'package:zawolf_hr/features/attendance_checkin/data/remote/attendance_gateway_checkin_client.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/check_in_action.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/check_in_receipt.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/check_in_status_resolution.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/pending_check_in.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/repositories/attendance_check_in_repository.dart';

void main() {
  test(
    'the repository contract works with a non-Firebase service adapter',
    () async {
      final action = CheckInAction(
        actionId: 'employee-a_2026-08-20',
        employeeScopeId: 'employee-a',
        dateKey: '2026-08-20',
        capturedAt: DateTime.utc(2026, 8, 20, 8, 30),
        payload: const <String, Object?>{
          'attendanceId': 'employee-a_2026-08-20',
          'type': 'checkIn',
        },
      );
      final AttendanceCheckInRepository repository =
          AttendanceCheckInRepositoryImpl(
            remote: _CompanyApiSubstitute(),
            outbox: _Outbox(),
          );

      final result = await repository.submit(action);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.attendanceId, action.actionId);
      expect(result.valueOrNull?.status, CheckInReceiptStatus.recorded);
    },
  );
}

class _CompanyApiSubstitute implements CheckInRemoteClient {
  @override
  Future<CheckInStatusResolution> resolveStatus(CheckInAction action) async =>
      CheckInStatusResolution.notRecorded;

  @override
  Future<CheckInReceipt> submit(CheckInAction action) async => CheckInReceipt(
    attendanceId: action.actionId,
    status: CheckInReceiptStatus.recorded,
  );
}

class _Outbox implements CheckInOutbox {
  @override
  Future<PendingCheckIn?> getForEmployee(String employeeScopeId) async => null;

  @override
  Future<void> put(PendingCheckIn item) async {}

  @override
  Future<void> remove(String actionId, String employeeScopeId) async {}
}
