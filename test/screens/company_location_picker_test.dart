import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final locationPicker = File(
    'lib/screens/hr/location_mgmt.dart',
  ).readAsStringSync();

  test('web map waits for the Maps script before constructing GoogleMap', () {
    expect(locationPicker, contains('GoogleMapsLoader.ensureLoaded()'));
    expect(locationPicker, contains('FutureBuilder<void>'));
    expect(locationPicker, contains('else if (snapshot.hasError)'));
    expect(locationPicker, contains('GoogleMap('));
    final loader = File(
      'lib/services/google_maps_loader_web.dart',
    ).readAsStringSync();
    expect(loader, contains('_waitUntilReady()'));
    expect(loader, contains("globalContext.has('google')"));
    expect(loader, isNot(contains('if (existing != null) return;')));
  });

  test('map selection preserves a reviewed coordinate fallback', () {
    expect(locationPicker, contains('onTap: _selectPosition'));
    expect(locationPicker, contains('onDragEnd: _selectPosition'));
    expect(locationPicker, contains('void _refreshMapOverlays()'));
    expect(locationPicker, contains('Set<Marker>.unmodifiable'));
    expect(locationPicker, contains('onKeepCoordinates'));
    expect(locationPicker, contains('استخدام الإحداثيات الحالية'));
    expect(
      locationPicker,
      contains('Navigator.pop(context, _selectedPosition)'),
    );
  });

  test(
    'map gives a safe external fallback when the web map is unavailable',
    () {
      expect(
        locationPicker,
        contains("https://www.google.com/maps/search/?api=1"),
      );
      expect(locationPicker, contains('فتح خرائط Google'));
    },
  );

  test(
    'location save keeps coordinates and radius in one document mutation',
    () {
      final locationService = File(
        'lib/services/location_service.dart',
      ).readAsStringSync();
      expect(locationService, contains("'latitude': location.latitude"));
      expect(locationService, contains("'longitude': location.longitude"));
      expect(
        locationService,
        contains("'geofenceRadiusMeters': location.geofenceRadiusMeters"),
      );
      expect(locationPicker, contains('userFacingError(error)'));
      expect(locationPicker, isNot(contains(r"'خطأ أثناء الحفظ: $e'")));
    },
  );
}
