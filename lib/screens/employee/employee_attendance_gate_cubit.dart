import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/attendance_policy.dart';
import '../../models/user_model.dart';
import '../../services/attendance_gateway_service.dart';
import '../../services/attendance_service.dart';

/// Immutable snapshot of the employee attendance gate configuration.
class AttendanceGateState {
  const AttendanceGateState({
    this.policyConfig = const AttendancePolicyConfig(),
    this.checkoutAllowedFrom,
    this.checkoutEnabled = false,
  });

  final AttendancePolicyConfig policyConfig;
  final DateTime? checkoutAllowedFrom;
  final bool checkoutEnabled;
}

/// Owns loading of the attendance policy gate for one employee screen.
/// One responsibility: resolve policy config, checkout allowance, and the
/// checkout-policy switch. Presentation decides how to render them.
class EmployeeAttendanceGateCubit extends Cubit<AttendanceGateState> {
  EmployeeAttendanceGateCubit() : super(const AttendanceGateState());

  Future<void> load(UserModel user) async {
    final service = AttendanceService();
    try {
      final results = await Future.wait([
        service.policyConfigForDisplay(),
        service.checkoutAllowedFromForDisplay(user),
        AttendanceGatewayService().checkoutPolicy(),
      ]);
      final policyResponse = results[2] as Map<String, dynamic>;
      final checkoutPolicy = policyResponse['policy'];
      emit(
        AttendanceGateState(
          policyConfig: results[0] as AttendancePolicyConfig,
          checkoutAllowedFrom: results[1] as DateTime,
          checkoutEnabled:
              checkoutPolicy is Map && checkoutPolicy['enabled'] == true,
        ),
      );
    } catch (_) {
      // Fails closed: default policy, no checkout override, checkout hidden.
      emit(const AttendanceGateState());
    }
  }
}
