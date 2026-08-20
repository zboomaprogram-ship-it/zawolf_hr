import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:zawolf_hr/models/request_approval_policy.dart';

void main() {
  test('manager approval remains final by default', () {
    final policy = RequestApprovalPolicy.fromMap(null);

    expect(policy.requireHrAfterManagerApproval, isFalse);
    expect(policy.finalManagerApprovalStatus, 'approved');
  });

  test('enabled policy routes final manager approval to HR', () {
    final policy = RequestApprovalPolicy.fromMap({
      'requireHrAfterManagerApproval': true,
    });

    expect(policy.requireHrAfterManagerApproval, isTrue);
    expect(policy.finalManagerApprovalStatus, 'pending_hr');
  });

  test('early leave approval remains in the normal approval path', () {
    final source = File(
      'lib/services/permission_service.dart',
    ).readAsStringSync();

    expect(source, contains('reconcileApprovedPermission(perm)'));
    expect(source, contains('PermissionTypePolicy.earlyLeave'));
    expect(source, contains('checkoutPolicyDecisionPoint'));

    final directHrSource = File(
      'lib/services/hr_direct_request_service.dart',
    ).readAsStringSync();
    expect(directHrSource, contains('checkoutPolicyDecisionPoint'));
    expect(directHrSource, contains('PermissionTypePolicy.earlyLeave'));
  });
}
