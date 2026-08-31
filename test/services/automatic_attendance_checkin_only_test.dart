import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final androidSource = File(
    'android/app/src/main/kotlin/com/zbooma/zawolfhr/MainActivity.kt',
  ).readAsStringSync();
  final iosSource = File('ios/Runner/AppDelegate.swift').readAsStringSync();
  final workerSource = File('scripts/auto-attendance.js').readAsStringSync();

  test('automatic attendance configures entry and exit geofence events for server policy', () {
    expect(
      androidSource,
      contains('Geofence.GEOFENCE_TRANSITION_ENTER'),
    );
    expect(
      androidSource,
      contains('Geofence.GEOFENCE_TRANSITION_EXIT'),
    );
  });

  test('iOS and the worker handle exit events as return-grace evidence', () {
    expect(iosSource, contains('didExitRegion'));
    expect(iosSource, contains('captureAutomaticAttendanceEvent("exit"'));
    expect(workerSource, contains("signal.event !== 'exit'"));
  });
}
