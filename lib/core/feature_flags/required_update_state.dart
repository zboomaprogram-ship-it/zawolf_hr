import '../../services/app_security_policy_service.dart';

/// Explicit, recoverable states for the mandatory-update gate.
enum RequiredUpdateViewState {
  policyUnavailable,
  updateAvailable,
  unsupportedRelease,
}

RequiredUpdateViewState requiredUpdateViewState(AppSecurityStatus status) {
  if (!status.policyVerified) {
    return RequiredUpdateViewState.policyUnavailable;
  }
  if (status.policy.storeUrlForCurrentPlatform().trim().isEmpty) {
    return RequiredUpdateViewState.unsupportedRelease;
  }
  return RequiredUpdateViewState.updateAvailable;
}
