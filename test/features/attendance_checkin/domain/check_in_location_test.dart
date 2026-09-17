import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/attendance_checkin/domain/entities/check_in_location.dart';

void main() {
  test('CheckInLocation encapsulates pure domain location evidence', () {
    const location = CheckInLocation(
      latitude: 31.0472,
      longitude: 31.3764,
      accuracyMeters: 18.5,
      isWithinZone: true,
      distanceMeters: 45.0,
      allowedRadiusMeters: 125.0,
      locationId: 'SEG',
      locationName: 'Mansoura Head Office',
      isMocked: false,
    );

    expect(location.isWithinZone, isTrue);
    expect(location.locationId, 'SEG');
    expect(location.distanceMeters, 45.0);
    expect(location.accuracyMeters, 18.5);
    expect(location.isMocked, isFalse);
  });
}
