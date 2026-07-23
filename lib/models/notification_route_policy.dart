class NotificationRoutePolicy {
  const NotificationRoutePolicy._();

  static String routeForType(String type) {
    final value = type.trim();
    if (value == 'hr_announcement') return '/notifications';
    if (value == 'account_deactivated') return '/account-disabled';
    if (value == 'warning_dismissal_review') return '/hr/employees';
    if (value == 'poll_created') return '/polls';
    if (value == 'attendance_security_review') return '/manager/requests';
    if (value == 'attendance_security_reviewed') {
      return '/employee/dashboard';
    }
    if (value == 'salary_deduction_pending') return '/manager/requests';
    if (value == 'salary_deduction_reviewed') {
      return '/employee/deductions';
    }
    if (value == 'complaint_new') return '/manager/requests';
    if (value.contains('pending_hr') || value.contains('pending_manager')) {
      return '/manager/requests';
    }
    if (value.contains('approved') ||
        value.contains('rejected') ||
        value.contains('reviewed') ||
        value.contains('permission') ||
        value.contains('leave') ||
        value.contains('advance')) {
      return '/employee/requests';
    }
    if (value.contains('task')) return '/employee/tasks';
    if (value.contains('warning') || value.contains('reward')) {
      return '/employee/warnings-rewards';
    }
    if (value.contains('suggestion')) return '/employee/suggestions';
    if (value.contains('kpi') || value.contains('performance')) {
      return '/employee/kpi';
    }
    if (value.contains('payroll') || value.contains('deduction')) {
      return '/employee/deductions';
    }
    if (value.contains('attendance')) return '/employee/dashboard';
    return '/notifications';
  }

  static Map<String, dynamic> dataWithRoute(
    String type,
    Map<String, dynamic>? data,
  ) {
    final payload = <String, dynamic>{...?data};
    final route = payload['route']?.toString().trim() ?? '';
    if (route.isEmpty) payload['route'] = routeForType(type);
    return payload;
  }
}
