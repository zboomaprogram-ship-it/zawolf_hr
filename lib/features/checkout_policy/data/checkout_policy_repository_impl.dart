import '../../../services/attendance_gateway_service.dart';
import '../domain/entities/checkout_policy.dart';
import '../domain/repositories/checkout_policy_repository.dart';

class CheckoutPolicyRepositoryImpl implements CheckoutPolicyRepository {
  CheckoutPolicyRepositoryImpl({AttendanceGatewayService? gateway})
    : _gateway = gateway ?? AttendanceGatewayService();

  final AttendanceGatewayService _gateway;
  CheckoutPolicySnapshot _cached = const CheckoutPolicySnapshot(
    policy: CheckoutPolicy.disabled(),
    canManage: false,
  );

  @override
  Future<CheckoutPolicySnapshot> load() async {
    final data = await _gateway.checkoutPolicy();
    return _cache(data);
  }

  @override
  Future<CheckoutPolicySnapshot> update({
    required bool enabled,
    required int expectedRevision,
    String? reason,
  }) async {
    final data = await _gateway.updateCheckoutPolicy(
      enabled: enabled,
      expectedRevision: expectedRevision,
      reason: reason,
    );
    return _cache(data);
  }

  CheckoutPolicySnapshot _cache(Map<String, dynamic> data) {
    final rawPolicy = data['policy'];
    _cached = CheckoutPolicySnapshot(
      policy: CheckoutPolicy.fromJson(
        rawPolicy is Map<String, dynamic> ? rawPolicy : null,
      ),
      canManage: data['canManage'] == true,
    );
    return _cached;
  }
}
