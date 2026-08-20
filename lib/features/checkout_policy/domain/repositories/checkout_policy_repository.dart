import '../entities/checkout_policy.dart';

abstract interface class CheckoutPolicyRepository {
  Future<CheckoutPolicySnapshot> load();

  Future<CheckoutPolicySnapshot> update({
    required bool enabled,
    required int expectedRevision,
    String? reason,
  });
}
