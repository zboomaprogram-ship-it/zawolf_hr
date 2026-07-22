import 'package:flutter_test/flutter_test.dart';
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
}
