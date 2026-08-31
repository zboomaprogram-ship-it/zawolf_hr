import '../domain/entities/checkout_policy.dart';
import '../domain/repositories/checkout_policy_repository.dart';

class CheckoutPolicyController {
  CheckoutPolicyController(this._repository);

  final CheckoutPolicyRepository _repository;
  CheckoutPolicySnapshot _state = const CheckoutPolicySnapshot(
    policy: CheckoutPolicy.disabled(),
    canManage: false,
  );

  CheckoutPolicySnapshot get state => _state;

  Future<CheckoutPolicySnapshot> load() async {
    _state = await _repository.load();
    return _state;
  }

  Future<CheckoutPolicySnapshot> change({
    required bool enabled,
    String? reason,
    int? autoCheckoutReturnGraceMinutes,
    String? companyBreakStartTime,
    String? companyBreakEndTime,
  }) async {
    try {
      _state = await _repository.update(
        enabled: enabled,
        expectedRevision: _state.policy.revision,
        reason: reason,
        autoCheckoutReturnGraceMinutes: autoCheckoutReturnGraceMinutes,
        companyBreakStartTime: companyBreakStartTime,
        companyBreakEndTime: companyBreakEndTime,
      );
      return _state;
    } catch (_) {
      // Reload once after a conflict or a stale dashboard view. The caller
      // still receives the failure and can ask the HR user to confirm again.
      await load();
      rethrow;
    }
  }
}
