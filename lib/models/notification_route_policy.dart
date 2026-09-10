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
    final channelId = payload['channelId']?.toString().trim() ?? '';

    if (channelId.isNotEmpty &&
        (type.contains('conversation') ||
            type.contains('chat') ||
            type == 'message')) {
      payload['route'] =
          '/conversations/channel/${Uri.encodeComponent(channelId)}';
      return payload;
    }

    final requestId = _extractRequestId(payload);
    final category = _categoryForPayload(type, payload);

    final isGenericRoute = route.isEmpty ||
        route == '/employee/requests' ||
        route == '/manager/requests' ||
        route == '/hr/requests';

    if (isGenericRoute) {
      final isEmployeeType = type.contains('approved') ||
          type.contains('rejected') ||
          type.contains('reviewed') ||
          type.startsWith('field_mission_under_review') ||
          type.startsWith('field_mission_approved') ||
          type.startsWith('field_mission_rejected') ||
          type.startsWith('company_os_request_');

      if (isEmployeeType) {
        final buffer = StringBuffer('/employee/requests?view=history');
        if (category != null) {
          buffer.write('&category=$category');
        }
        if (requestId.isNotEmpty) {
          buffer.write('&requestId=${Uri.encodeComponent(requestId)}');
        }
        payload['route'] = buffer.toString();
      } else {
        final cat = category ?? _managerCategoryForType(type);
        if (cat != null && requestId.isNotEmpty) {
          payload['route'] =
              '/manager/requests?category=$cat&requestId=${Uri.encodeComponent(requestId)}';
        } else if (cat != null) {
          payload['route'] = '/manager/requests?category=$cat';
        } else {
          payload['route'] = routeForType(type);
        }
      }
    }
    return payload;
  }

  static String _extractRequestId(Map<String, dynamic> payload) {
    const keys = [
      'requestId',
      'leaveId',
      'permissionId',
      'advanceId',
      'meetingId',
      'complaintId',
      'resignationId',
      'administrativeRequestId',
      'fieldMissionId',
      'attendanceCorrectionId',
      'correctionId',
      'salaryDeductionId',
      'deductionId',
      'taskId',
      'resourceId',
      'targetId',
    ];
    for (final key in keys) {
      final value = payload[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String? _categoryForPayload(String type, Map<String, dynamic> payload) {
    final rawCategory = (payload['category'] ??
            payload['collection'] ??
            payload['requestCollection'] ??
            payload['sourceType'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (rawCategory != null && rawCategory.isNotEmpty) {
      final mapped = _normalizeCategory(rawCategory);
      if (mapped != null) return mapped;
    }
    return _managerCategoryForType(type);
  }

  static String? _normalizeCategory(String val) {
    if (val.contains('leave')) return 'leaves';
    if (val.contains('permission')) return 'permissions';
    if (val.contains('advance')) return 'advances';
    if (val.contains('meeting')) return 'meetings';
    if (val.contains('company_os') || val.contains('expense')) return 'company_os';
    if (val.contains('custom')) return 'custom';
    if (val.contains('deduction')) return 'salary_deductions';
    if (val.contains('attendance_correction') || val.contains('correction')) {
      return 'attendance_corrections';
    }
    if (val.contains('security')) return 'security';
    if (val.contains('complaint')) return 'complaints';
    if (val.contains('resignation')) return 'resignations';
    if (val.contains('administrative') || val.contains('mission')) {
      return 'administrative';
    }
    return null;
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
    if (value.contains('administrative') || value.contains('mission')) {
      return 'administrative';
    }
    return null;
  }
}
