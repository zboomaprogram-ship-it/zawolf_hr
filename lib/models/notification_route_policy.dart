class NotificationRoutePolicy {
  const NotificationRoutePolicy._();

  static String routeForType(String type) {
    final value = type.trim();
    if (value.contains('conversation') || value.contains('chat')) {
      return '/conversations';
    }
    if (value == 'meeting_request') return '/meeting/approvals';
    if (value == 'custom_request') return '/approver/custom-requests';
    if (value == 'advance_pending_hr' ||
        value == 'advance_pending_ceo' ||
        value == 'advance_pending_accounting' ||
        value.contains('approval_turn')) {
      return '/manager/requests';
    }
    if (value == 'field_mission_approval_turn') return '/manager/requests';
    if (value == 'field_mission_under_review' ||
        value == 'field_mission_approved' ||
        value == 'field_mission_rejected') {
      return '/employee/requests';
    }
    if (value.startsWith('company_os_request_pending_')) {
      return '/manager/requests';
    }
    if (value.startsWith('company_os_request_')) return '/employee/requests';
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
    if (value == 'administrative_request_submitted' ||
        value == 'field_mission_pending_ceo') {
      return '/manager/requests';
    }
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
    if (route.isEmpty) {
      final channelId = payload['channelId']?.toString().trim() ?? '';
      if (channelId.isNotEmpty &&
          (type.contains('conversation') ||
              type.contains('chat') ||
              type == 'message')) {
        payload['route'] =
            '/conversations/channel/${Uri.encodeComponent(channelId)}';
        return payload;
      }
      final administrativeId =
          payload['administrativeRequestId']?.toString().trim() ?? '';
      final requestId = payload['requestId']?.toString().trim() ?? '';
      if (administrativeId.isNotEmpty &&
          (type.contains('administrative') || type.contains('field_mission'))) {
        // Preserve the request identifier for the next navigation increment;
        // the category parameter already prevents the old first-tab fallback.
        payload['route'] =
            '/manager/requests?category=administrative&requestId=${Uri.encodeComponent(administrativeId)}';
      } else if (requestId.isNotEmpty &&
          (type.contains('approved') ||
              type.contains('rejected') ||
              type.contains('reviewed') ||
              type.startsWith('field_mission_') ||
              type.startsWith('company_os_request_'))) {
        payload['route'] =
            '/employee/requests?requestId=${Uri.encodeComponent(requestId)}';
      } else {
        final category = _managerCategoryForType(type);
        payload['route'] =
            category != null && requestId.isNotEmpty
                ? '/manager/requests?category=$category&requestId=${Uri.encodeComponent(requestId)}'
                : routeForType(type);
      }
    }
    return payload;
  }

  static String? _managerCategoryForType(String type) {
    final value = type.trim().toLowerCase();
    if (value.contains('leave')) return 'leaves';
    if (value.contains('permission')) return 'permissions';
    if (value.contains('advance')) return 'advances';
    if (value.contains('meeting')) return 'meetings';
    if (value.contains('company_os') || value.contains('expense')) {
      return 'company_os';
    }
    if (value.contains('custom')) {
      return 'custom';
    }
    if (value.contains('deduction')) {
      return 'salary_deductions';
    }
    if (value.contains('attendance_correction')) {
      return 'attendance_corrections';
    }
    if (value.contains('security')) {
      return 'security';
    }
    if (value.contains('complaint')) {
      return 'complaints';
    }
    if (value.contains('resignation')) {
      return 'resignations';
    }
    return null;
  }
}
