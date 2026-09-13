import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/web_attendance_access/domain/entities/web_attendance_access_grant.dart';

void main() {
  test('permanent grant reports permanent and active state', () {
    const grant = WebAttendanceAccessGrant(employeeId: 'u1', employeeName: 'Employee', employeeCode: 'EMP-1', scope: 'permanent', status: 'active', revision: 1);
    expect(grant.permanent, isTrue);
    expect(grant.active, isTrue);
  });
}
