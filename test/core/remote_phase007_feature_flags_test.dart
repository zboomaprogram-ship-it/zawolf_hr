import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zawolf_hr/core/feature_flags/phase007_feature_flags.dart';
import 'package:zawolf_hr/core/feature_flags/remote_phase007_feature_flags.dart';

void main() {
  test('accepts only known server flags for an authenticated actor', () async {
    final flags = RemotePhase007FeatureFlags(
      client: MockClient(
        (_) async => http.Response(
          '{"ok":true,"enabled":["diagnostics_v2","unknown_v2"]}',
          200,
        ),
      ),
      tokenProvider: () async => 'token',
      baseUri: Uri.parse('https://example.test'),
    );
    await flags.refresh();
    expect(
      flags.isEnabledFor(
        feature: Phase007Feature.diagnostics,
        actorId: 'actor',
      ),
      isTrue,
    );
    expect(
      flags.isEnabledFor(
        feature: Phase007Feature.salesIndicators,
        actorId: 'actor',
      ),
      isFalse,
    );
  });

  test('network or invalid response clears previously enabled state', () async {
    var valid = true;
    final flags = RemotePhase007FeatureFlags(
      client: MockClient(
        (_) async => valid
            ? http.Response('{"ok":true,"enabled":["diagnostics_v2"]}', 200)
            : http.Response('unavailable', 503),
      ),
      tokenProvider: () async => 'token',
      baseUri: Uri.parse('https://example.test'),
    );
    await flags.refresh();
    valid = false;
    await flags.refresh();
    expect(
      flags.isEnabledFor(
        feature: Phase007Feature.diagnostics,
        actorId: 'actor',
      ),
      isFalse,
    );
  });
}
