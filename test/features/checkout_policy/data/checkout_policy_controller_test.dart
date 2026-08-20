import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/checkout_policy/checkout_policy.dart';
import 'package:zawolf_hr/features/checkout_policy/presentation/checkout_policy_controller.dart';

void main() {
  test(
    'controller reloads the current policy after a revision conflict',
    () async {
      final repository = _FakeRepository(
        loadResult: _snapshot(enabled: false, revision: 4),
        updateError: StateError('conflict'),
      );
      final controller = CheckoutPolicyController(repository);
      await controller.load();

      await expectLater(controller.change(enabled: true), throwsStateError);
      expect(repository.loadCalls, 2);
      expect(controller.state.policy.revision, 4);
      expect(controller.state.policy.enabled, isFalse);
    },
  );
}

CheckoutPolicySnapshot _snapshot({
  required bool enabled,
  required int revision,
}) => CheckoutPolicySnapshot(
  policy: CheckoutPolicy(enabled: enabled, revision: revision),
  canManage: true,
);

class _FakeRepository implements CheckoutPolicyRepository {
  _FakeRepository({required this.loadResult, this.updateError});

  final CheckoutPolicySnapshot loadResult;
  final Object? updateError;
  int loadCalls = 0;

  @override
  Future<CheckoutPolicySnapshot> load() async {
    loadCalls++;
    return loadResult;
  }

  @override
  Future<CheckoutPolicySnapshot> update({
    required bool enabled,
    required int expectedRevision,
    String? reason,
  }) async {
    if (updateError != null) throw updateError!;
    return _snapshot(enabled: enabled, revision: expectedRevision + 1);
  }
}
