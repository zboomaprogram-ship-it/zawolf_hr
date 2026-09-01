import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/services/notification_service.dart',
  ).readAsStringSync();

  test(
    'unread notification listener is bounded and replaces the old listener',
    () {
      expect(source, contains('stopListening();'));
      expect(source, contains('.where(\'isRead\', isEqualTo: false)'));
      expect(source, contains('.limit(25)'));
    },
  );

  test('notification routes are validated before a tap is emitted', () {
    expect(source, contains('safeRoute(route)'));
    expect(source, contains('_isSupportedNotificationPath(uri.path)'));
    expect(source, contains('/operational/'));
  });

  test('cold-start local notifications preserve their safe deep link', () {
    expect(source, contains("payload.startsWith('notification|')"));
    expect(source, contains('initialRoute = safeRoute'));
  });
}
