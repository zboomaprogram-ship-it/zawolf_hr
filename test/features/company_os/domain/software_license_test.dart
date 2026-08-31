import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/software_license.dart';

void main() {
  test('seat capacity is derived without allowing over allocation', () {
    const license = SoftwareLicense(
      id: 'l1',
      name: 'Suite',
      vendor: 'Vendor',
      totalSeats: 3,
      usedSeats: 3,
      status: 'active',
      version: 1,
    );
    expect(license.availableSeats, 0);
    expect(license.canAssignSeat, isFalse);
  });

  test('revoked assignment is no longer active', () {
    final assignment = SoftwareAssignment(
      id: 's1',
      licenseId: 'l1',
      employeeUid: 'u1',
      assignedBy: 'it1',
      assignedAt: DateTime(2026),
      revokedAt: DateTime(2026, 2),
    );
    expect(assignment.active, isFalse);
  });
}
