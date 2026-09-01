import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/services/geofence_service.dart').readAsStringSync();

  test(
    'web attendance permits a short-lived browser position with an app timeout',
    () {
      expect(source, contains('locationSettings: WebSettings('));
      expect(source, contains('maximumAge: const Duration(minutes: 1)'));
      expect(source, contains('.timeout(timeLimit);'));
      expect(source, contains('getPositionStream('));
      expect(source, contains('_getWebWatchPosition'));
      expect(source, contains('_webLocationFailureMessage'));
    },
  );

  test(
    'web location acquisition keeps the existing attendance accuracy policy',
    () {
      expect(
        source,
        contains('maxAccuracyAllowanceMeters: strictLocationOnly ? 12 : 25'),
      );
      expect(source, contains("تعذر الحصول على موقع حديث من المتصفح"));
      expect(source, contains('خدمة الموقع في الجهاز لم تُرجع إحداثيات'));
      expect(source, isNot(contains('longitude: location.longitude')));
      expect(source, isNot(contains('final isWithin = kDebugMode ||')));
      expect(source, isNot(contains('if (kIsWeb) return true')));
      expect(source, isNot(contains('longitude: 0.0')));
    },
  );
}
