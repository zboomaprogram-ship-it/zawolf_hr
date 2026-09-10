import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/services/attendance_gateway_service.dart';
import 'package:zawolf_hr/services/offline_attendance_queue_service.dart';

void main() {
  test('expired attendance events are terminal and are never retried', () {
    expect(
      OfflineAttendanceQueueService.shouldRetryGatewayFailure(
        const AttendanceGatewayException(
          'stale_event',
          'Attendance time is outside the allowed window.',
        ),
      ),
      isFalse,
    );
  });

  test('temporary transport failures remain queued for replay', () {
    expect(
      OfflineAttendanceQueueService.shouldRetryGatewayFailure(
        const AttendanceGatewayException('network', 'offline'),
      ),
      isTrue,
    );
  });
}
