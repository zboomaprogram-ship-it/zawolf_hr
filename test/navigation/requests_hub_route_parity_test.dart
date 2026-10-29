import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Requests Hub Route Parity Tests (Task C020)', () {
    final routerSource = File('lib/navigation/router.dart').readAsStringSync();

    test('router registers unified requests hub route at /requests', () {
      expect(
        routerSource.contains("path: '/requests'"),
        isTrue,
        reason: 'Unified Requests Hub should be registered at /requests',
      );
    });

    test('router registers direct detail route at /requests/:collection/:requestId', () {
      expect(
        routerSource.contains("path: '/requests/:collection/:requestId'"),
        isTrue,
        reason: 'Unified Requests detail should be registered at /requests/:collection/:requestId',
      );
    });

    test('legacy requests routes remain intact alongside unified hub', () {
      const legacyPaths = [
        '/employee/requests',
        '/team-leader/requests',
        '/manager/requests',
        '/hr/requests',
      ];
      for (final path in legacyPaths) {
        expect(
          routerSource.contains("path: '$path'"),
          isTrue,
          reason: 'Legacy path $path must not be deleted during strangler migration',
        );
      }
    });
  });
}
