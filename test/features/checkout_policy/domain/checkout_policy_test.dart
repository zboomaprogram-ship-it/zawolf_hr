import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/checkout_policy/checkout_policy.dart';

void main() {
  test('missing and malformed checkout policy is disabled by default', () {
    expect(const CheckoutPolicy.disabled().enabled, isFalse);
    expect(CheckoutPolicy.fromJson(null).enabled, isFalse);
    expect(
      CheckoutPolicy.fromJson(<String, dynamic>{
        'enabled': 'true',
        'revision': -1,
      }).enabled,
      isFalse,
    );
    expect(
      CheckoutPolicy.fromJson(<String, dynamic>{
        'enabled': true,
        'revision': -1,
      }).revision,
      0,
    );
  });

  test('policy retains a valid revision and ISO effective-time snapshot', () {
    final policy = CheckoutPolicy.fromJson(<String, dynamic>{
      'enabled': true,
      'revision': 7,
      'effectiveAt': '2026-08-20T10:15:00.000Z',
      'reason': 'استثناء تشغيلي',
    });

    expect(policy.enabled, isTrue);
    expect(policy.revision, 7);
    expect(policy.effectiveAt, DateTime.utc(2026, 8, 20, 10, 15));
    expect(policy.reason, 'استثناء تشغيلي');
  });
}
