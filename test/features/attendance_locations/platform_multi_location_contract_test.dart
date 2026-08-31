import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('multi-location native platform contract', () {
    final android = File(
      'android/app/src/main/kotlin/com/zbooma/zawolfhr/MainActivity.kt',
    ).readAsStringSync();
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    test('Android bounds, replaces, and registers entry and exit geofences', () {
      expect(android, contains('rawLocations.take(20)'));
      expect(android, contains('removeGeofences(geofencePendingIntent())'));
      expect(android, contains('GEOFENCE_TRANSITION_ENTER'));
      expect(android, contains('GEOFENCE_TRANSITION_EXIT'));
    });

    test('iOS bounds, replaces, and registers entry and exit regions', () {
      expect(ios, contains('rawLocations.prefix(20)'));
      expect(ios, contains('locations.prefix(20)'));
      expect(ios, contains('stopMonitoring'));
      expect(ios, contains('region.notifyOnEntry = true'));
      expect(ios, contains('region.notifyOnExit = true'));
      expect(ios, contains('captureAutomaticAttendanceEvent("exit", region: region)'));
    });

    test('both adapters retain assignment metadata for restart recovery', () {
      expect(android, contains('assignmentId'));
      expect(android, contains('assignmentVersion'));
      expect(ios, contains('assignmentId'));
      expect(ios, contains('assignmentVersion'));
    });
  });
}
