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
    expect(requestScreen, contains("6 => _buildFieldMissionForm(user, theme)"));
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
    expect(requestScreen, contains("0 => _buildPermissionForm"));
    expect(requestScreen, contains("1 => _buildLeaveForm"));
    expect(requestScreen, contains("2 => _buildAdvanceForm"));
    expect(requestScreen, contains("3 => _buildComplaintForm"));
    expect(requestScreen, contains("4 => _buildResignationForm"));
    expect(requestScreen, contains("5 => _buildAdministrativeRequestForm"));
    expect(requestScreen, contains("6 => _buildFieldMissionForm"));
    expect(requestScreen, contains("_ => _buildAttendanceCorrectionForm"));
  });
}
