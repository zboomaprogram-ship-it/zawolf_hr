import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/models/notification_route_policy.dart';
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

  test('administrative and field mission approvals open management', () {
    expect(
      service.routeForType('administrative_request_submitted'),
      '/manager/requests',
    );
    expect(
      service.routeForType('field_mission_pending_ceo'),
      '/manager/requests',
    );
  });

  test('every active approval stage opens the reviewer request queue', () {
    expect(
      service.routeForType('field_mission_approval_turn'),
      '/manager/requests',
    );
    expect(service.routeForType('advance_pending_hr'), '/manager/requests');
    expect(service.routeForType('advance_pending_ceo'), '/manager/requests');
    expect(
      service.routeForType('advance_pending_accounting'),
      '/manager/requests',
    );
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

  test('manager approval notifications preserve the exact request target', () {
    expect(
      NotificationRoutePolicy.dataWithRoute('leave_pending_manager', {
        'requestId': 'leave-42',
      })['route'],
      '/manager/requests?category=leaves&requestId=leave-42',
    );
    expect(
      NotificationRoutePolicy.dataWithRoute(
        'attendance_correction_pending_hr',
        {'requestId': 'correction-42'},
      )['route'],
      '/manager/requests?category=attendance_corrections&requestId=correction-42',
    );
  });
}
