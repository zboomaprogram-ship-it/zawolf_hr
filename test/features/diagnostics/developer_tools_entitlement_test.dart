import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/diagnostics/domain/entities/developer_tools_entitlement.dart';

void main() {
  test('an active entitlement permits only its explicit in-app scope', () {
    final entitlement = DeveloperToolsEntitlement(
      employeeUserId: 'employee-1',
      scopes: {DeveloperToolScope.appDiagnostics},
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      grantedByUserId: 'admin-1',
    );

    expect(entitlement.allows(DeveloperToolScope.appDiagnostics), isTrue);
    expect(entitlement.allows(DeveloperToolScope.networkDiagnostics), isFalse);
  });

  test('expired or revoked entitlement is never active', () {
    final expired = DeveloperToolsEntitlement(
      employeeUserId: 'employee-1',
      scopes: {DeveloperToolScope.appDiagnostics},
      expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      grantedByUserId: 'admin-1',
    );
    final revoked = DeveloperToolsEntitlement(
      employeeUserId: 'employee-1',
      scopes: {DeveloperToolScope.appDiagnostics},
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      grantedByUserId: 'admin-1',
      revokedAt: DateTime.now(),
    );

    expect(expired.isActive, isFalse);
    expect(revoked.isActive, isFalse);
  });
}
