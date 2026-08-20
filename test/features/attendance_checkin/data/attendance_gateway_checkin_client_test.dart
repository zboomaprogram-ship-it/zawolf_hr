import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/attendance_checkin/data/remote/attendance_gateway_checkin_client.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/check_in_action.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/check_in_receipt.dart';

void main() {
  final action = CheckInAction(
    actionId: 'employee-1_2026-08-20',
    employeeScopeId: 'employee-1',
    dateKey: '2026-08-20',
    capturedAt: DateTime.utc(2026, 8, 20),
    payload: const {'attendanceId': 'employee-1_2026-08-20', 'type': 'checkIn'},
  );

  test('maps a gateway recorded receipt into the domain', () async {
    final client = AttendanceGatewayCheckInClient(
      transport: _FakeTransport(const {
        'action': 'check_in',
        'status': 'recorded',
        'attendanceId': 'employee-1_2026-08-20',
      }),
    );

    final receipt = await client.submit(action);

    expect(receipt.status, CheckInReceiptStatus.recorded);
  });

  test('maps an idempotent gateway receipt into saved state', () async {
    final client = AttendanceGatewayCheckInClient(
      transport: _FakeTransport(const {
        'action': 'check_in',
        'status': 'already_recorded',
        'attendanceId': 'employee-1_2026-08-20',
      }),
    );

    final receipt = await client.submit(action);

    expect(receipt.status, CheckInReceiptStatus.alreadyRecorded);
  });
}

class _FakeTransport implements AttendanceGatewayCheckInTransport {
  const _FakeTransport(this.receipt);

  final Map<String, Object?> receipt;

  @override
  Future<Map<String, Object?>> submit(Map<String, Object?> action) async =>
      receipt;

  @override
  Future<Map<String, Object?>> status(String attendanceId) async => const {
    'status': 'not_recorded',
  };
}
