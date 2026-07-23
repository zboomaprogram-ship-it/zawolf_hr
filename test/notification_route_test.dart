import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/services/notification_service.dart';

void main() {
  final service = NotificationService.instance;

  test('announcements and polls open valid shared routes', () {
    expect(service.routeForType('hr_announcement'), '/notifications');
    expect(service.routeForType('poll_created'), '/polls');
  });

  test('deduction decisions open the employee deduction history', () {
    expect(
      service.routeForType('salary_deduction_reviewed'),
      '/employee/deductions',
    );
  });

  test('account and resignation notifications have actionable routes', () {
    expect(service.routeForType('account_deactivated'), '/account-disabled');
    expect(
      service.routeForType('resignation_pending_manager'),
      '/manager/requests',
    );
    expect(service.routeForType('resignation_reviewed'), '/employee/requests');
  });

  test('unknown notification types stay in the notification inbox', () {
    expect(service.routeForType('unknown_notification'), '/notifications');
  });

  test('unknown push routes fall back to a valid route for the type', () {
    expect(
      service.safeRoute('/route-that-does-not-exist', type: 'hr_announcement'),
      '/notifications',
    );
    expect(
      service.safeRoute('/route-that-does-not-exist', type: 'poll_created'),
      '/polls',
    );
  });

  test('known routes preserve query parameters', () {
    expect(
      service.safeRoute('/notifications?notificationId=123'),
      '/notifications?notificationId=123',
    );
  });
}
