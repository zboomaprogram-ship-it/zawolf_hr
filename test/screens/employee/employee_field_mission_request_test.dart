import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final requestScreen =
      File('lib/screens/employee/employee_requests.dart').readAsStringSync();
  final adminService =
      File(
        'lib/services/administrative_request_service.dart',
      ).readAsStringSync();

  test('Field Mission is exposed as a separate request container', () {
    // Check that 'مهمة ميدانية' is present in request type selector
    expect(requestScreen, contains("label: 'مهمة ميدانية'"));
    expect(requestScreen, contains("'field_mission' => _buildFieldMissionForm(user, theme)"));
    expect(
      requestScreen,
      contains("_buildFieldMissionForm(UserModel user, ThemeData theme)"),
    );
    expect(requestScreen, contains("_submitFieldMissionDirect(user)"));
    expect(requestScreen, contains("_fieldMissionReasonController"));
    expect(requestScreen, contains("_formKeyFieldMission"));
  });

  test('Field Mission uses the protected server-owned approval route', () {
    expect(
      adminService,
      contains('_routingGateway.createEmployeeFieldMission('),
    );
    expect(
      requestScreen,
      contains('value != AdministrativeRequestCategory.fieldMission'),
    );
  });

  test('All primary request types are properly mapped in request centre', () {
    expect(requestScreen, contains("'permission' => _buildPermissionForm"));
    expect(requestScreen, contains("'leave' => _buildLeaveForm"));
    expect(requestScreen, contains("'advance' => _buildAdvanceForm"));
    expect(requestScreen, contains("'complaint' => _buildComplaintForm"));
    expect(requestScreen, contains("'resignation' => _buildResignationForm"));
    expect(requestScreen, contains("'administrative' => _buildAdministrativeRequestForm"));
    expect(requestScreen, contains("'field_mission' => _buildFieldMissionForm"));
    expect(requestScreen, contains("'attendance_correction' => _buildAttendanceCorrectionForm"));
  });
}
