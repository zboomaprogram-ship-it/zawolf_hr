import '../domain/early_leave_checkout_eligibility.dart';

enum EarlyLeaveCheckoutViewStatus {
  initial,
  loading,
  ready,
  unavailable,
  error,
}

final class EarlyLeaveCheckoutState {
  const EarlyLeaveCheckoutState({
    this.status = EarlyLeaveCheckoutViewStatus.initial,
    this.eligibility,
    this.message,
  });

  final EarlyLeaveCheckoutViewStatus status;
  final EarlyLeaveCheckoutEligibility? eligibility;
  final String? message;

  EarlyLeaveCheckoutState copyWith({
    EarlyLeaveCheckoutViewStatus? status,
    EarlyLeaveCheckoutEligibility? eligibility,
    String? message,
    bool clearEligibility = false,
  }) => EarlyLeaveCheckoutState(
    status: status ?? this.status,
    eligibility: clearEligibility ? null : eligibility ?? this.eligibility,
    message: message,
  );
}
