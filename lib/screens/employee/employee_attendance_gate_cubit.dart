import 'dart:async';
import 'dart:developer' as developer;

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

  AttendanceGateState copyWith({
    AttendancePolicyConfig? policyConfig,
    DateTime? checkoutAllowedFrom,
    bool? checkoutEnabled,
  }) {
    return AttendanceGateState(
      policyConfig: policyConfig ?? this.policyConfig,
      checkoutAllowedFrom: checkoutAllowedFrom ?? this.checkoutAllowedFrom,
      checkoutEnabled: checkoutEnabled ?? this.checkoutEnabled,
    );
  }
}

/// Owns loading of the attendance policy gate for one employee screen.
/// One responsibility: resolve policy config, checkout allowance, and the
/// checkout-policy switch. Presentation decides how to render them.
class EmployeeAttendanceGateCubit extends Cubit<AttendanceGateState> {
  EmployeeAttendanceGateCubit({
    AttendanceService? attendanceService,
    AttendanceGatewayService? gatewayService,
  }) : _attendanceService = attendanceService ?? AttendanceService(),
       _gatewayService = gatewayService ?? AttendanceGatewayService(),
       super(const AttendanceGateState());

  final AttendanceService _attendanceService;
  final AttendanceGatewayService _gatewayService;
  StreamSubscription<DateTime>? _checkoutAllowanceSubscription;
  String? _watchScope;
  int _loadGeneration = 0;

  Future<void> watch(UserModel user) async {
    final now = DateTime.now();
    final scope = '${user.uid}:${now.year}-${now.month}-${now.day}';
    if (_watchScope == scope) return;
    _watchScope = scope;
    await _checkoutAllowanceSubscription?.cancel();
    _checkoutAllowanceSubscription = _attendanceService
        .watchCheckoutAllowedFromForDisplay(user, now: now)
        .listen(
          (allowedFrom) {
            if (!isClosed && _watchScope == scope) {
              emit(state.copyWith(checkoutAllowedFrom: allowedFrom));
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_watchScope == scope) _watchScope = null;
            developer.log(
              'Attendance checkout permission watch failed',
              name: 'EmployeeAttendanceGateCubit',
              error: error,
              stackTrace: stackTrace,
            );
          },
        );
  }

  Future<void> load(UserModel user) async {
    final generation = ++_loadGeneration;
    try {
      final results = await Future.wait([
        _attendanceService.policyConfigForDisplay(),
        _attendanceService.checkoutAllowedFromForDisplay(user),
        _gatewayService.checkoutPolicy(),
      ]);
      if (isClosed || generation != _loadGeneration) return;
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
    } catch (error, stackTrace) {
      // Preserve the last confirmed state during a temporary refresh failure.
      // The initial state remains fail-closed until the first successful load.
      developer.log(
        'Attendance gate refresh failed',
        name: 'EmployeeAttendanceGateCubit',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> close() async {
    await _checkoutAllowanceSubscription?.cancel();
    return super.close();
  }
}
