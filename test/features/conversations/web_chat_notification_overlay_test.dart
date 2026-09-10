import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/conversations/domain/in_app_notification_alert.dart';
import 'package:zawolf_hr/features/conversations/presentation/widgets/web_chat_notification_overlay.dart';
import 'package:zawolf_hr/theme/theme.dart';

class _Alerts implements InAppNotificationAlerts {
  final _controller = StreamController<InAppNotificationAlert>.broadcast();
  InAppNotificationAlert? opened;

  @override
  Stream<InAppNotificationAlert> get alerts => _controller.stream;

  @override
  Future<void> open(InAppNotificationAlert notification) async {
    opened = notification;
  }

  void dispose() => _controller.close();
}

void main() {
  testWidgets('opens an in-app chat alert through the injected authority', (
    tester,
  ) async {
    final alerts = _Alerts();
    addTearDown(alerts.dispose);
    final notification = InAppNotificationAlert(
      id: 'chat-alert-1',
      title: 'فريق البيانات',
      body: 'رسالة جديدة',
      type: 'conversation',
      route: '/conversations/channel/company%3Ageneral',
      timestamp: DateTime(2026, 9, 10),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ZaWolfTheme.darkTheme,
        home: WebChatNotificationOverlay(
          notifications: alerts,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    alerts._controller.add(notification);
    await tester.pump();
    expect(find.text('فريق البيانات'), findsOneWidget);
    expect(find.text('رسالة جديدة'), findsOneWidget);

    await tester.tap(find.text('عرض الرد'));
    await tester.pump();
    expect(alerts.opened, notification);
  });
}
