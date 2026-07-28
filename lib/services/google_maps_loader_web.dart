import 'dart:async';

import 'package:web/web.dart' as web;

class GoogleMapsLoader {
  static const _apiKey = String.fromEnvironment(
    'GOOGLE_MAPS_WEB_API_KEY',
    defaultValue: 'AIzaSyDl5bO63kW9ukQkEEyqdg40oSFh1R8mOSM',
  );
  static Future<void>? _loading;

  static Future<void> ensureLoaded() {
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    final existing = web.document.querySelector(
      'script[data-zawolf-google-maps="true"], '
      'script[src*="maps.googleapis.com/maps/api/js"]',
    );
    if (existing != null) return;
    if (_apiKey.trim().isEmpty) {
      throw StateError('Google Maps web API key is missing.');
    }

    final completer = Completer<void>();
    final script = web.HTMLScriptElement()
      ..src =
          'https://maps.googleapis.com/maps/api/js'
          '?key=${Uri.encodeQueryComponent(_apiKey)}'
          '&loading=async'
      ..async = true
      ..defer = true
      ..setAttribute('data-zawolf-google-maps', 'true');

    late final StreamSubscription<web.Event> loadSubscription;
    late final StreamSubscription<web.Event> errorSubscription;
    loadSubscription = script.onLoad.listen((_) {
      if (!completer.isCompleted) completer.complete();
      loadSubscription.cancel();
      errorSubscription.cancel();
    });
    errorSubscription = script.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Google Maps failed to load. Check the API key and referrer restrictions.',
          ),
        );
      }
      loadSubscription.cancel();
      errorSubscription.cancel();
    });
    web.document.head?.append(script);
    await completer.future.timeout(const Duration(seconds: 20));
  }
}
