import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/core/errors/errors.dart';
import 'package:zawolf_hr/features/attendance_checkin/data/attendance_checkin_failure_mapper.dart';
import 'package:zawolf_hr/services/attendance_gateway_service.dart';

void main() {
  const mapper = AttendanceCheckInFailureMapper();

  AppFailure map(String code) => mapper.map(
    AttendanceGatewayException(code, 'never expose this technical detail'),
  );

  test(
    'maps access and authentication failures to confirmed safe categories',
    () {
      expect(map('device_mismatch').category, FailureCategory.access);
      expect(
        map('unauthenticated').category,
        FailureCategory.authenticationSession,
      );
    },
  );

  test('maps validation failures without retrying them', () {
    final failure = map('invalid_request');
    expect(failure.category, FailureCategory.validation);
    expect(failure.canRetrySafely, isFalse);
  });

  test('maps connectivity separately from temporary service outages', () {
    expect(map('network').category, FailureCategory.connectivity);
    expect(map('timeout').category, FailureCategory.temporaryService);
    expect(
      map('server_unavailable').category,
      FailureCategory.temporaryService,
    );
  });

  test('maps uncertain and unknown outcomes to status check', () {
    expect(map('unknown_outcome').requiresStatusCheck, isTrue);
    expect(map('unrecognised_code').requiresStatusCheck, isTrue);
  });
}
