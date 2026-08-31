import 'app_failure.dart';
import 'failure_category.dart';
import 'recovery_guidance.dart';
import 'user_safe_failure_message.dart';

/// Provider-neutral outcome returned by the Company Workspace gateway.
///
/// Server and client diagnostics may contain a status code, correlation ID, or
/// transport exception. They must be mapped here before presentation consumes
/// them, so employees never see Google, Firebase, HTTP, or stack-trace text.
final class WorkspaceUserFacingError {
  const WorkspaceUserFacingError._();

  static AppFailure fromHttpStatus(
    int? statusCode, {
    required bool writeMayHaveStarted,
  }) {
    final category = switch (statusCode) {
      400 || 422 => FailureCategory.validation,
      401 => FailureCategory.authenticationSession,
      403 => FailureCategory.access,
      404 => FailureCategory.missingData,
      409 => FailureCategory.conflictDuplicate,
      429 => FailureCategory.capacityQuota,
      408 || 502 || 503 || 504 || null => FailureCategory.temporaryService,
      _ => FailureCategory.unexpected,
    };
    final unknownOutcome =
        writeMayHaveStarted &&
        (category == FailureCategory.temporaryService ||
            category == FailureCategory.connectivity ||
            category == FailureCategory.unexpected);
    return AppFailure(
      category: category,
      recovery: unknownOutcome
          ? RecoveryGuidance.checkStatusBeforeRetry
          : _recoveryFor(category),
      outcomeCertainty: unknownOutcome
          ? OutcomeCertainty.unknown
          : OutcomeCertainty.confirmedNotCompleted,
      diagnosticKey: statusCode == null
          ? 'workspace_transport'
          : 'workspace_http',
      diagnosticContext: statusCode == null
          ? const {}
          : {'statusCode': '$statusCode'},
    );
  }

  static AppFailure connectivity({required bool writeMayHaveStarted}) =>
      AppFailure(
        category: FailureCategory.connectivity,
        recovery: writeMayHaveStarted
            ? RecoveryGuidance.checkStatusBeforeRetry
            : RecoveryGuidance.retrySafely,
        outcomeCertainty: writeMayHaveStarted
            ? OutcomeCertainty.unknown
            : OutcomeCertainty.confirmedNotCompleted,
        diagnosticKey: 'workspace_connectivity',
      );

  static UserSafeFailureMessage messageFor(AppFailure failure) =>
      UserSafeFailureMessage.fromFailure(failure);

  static RecoveryGuidance _recoveryFor(FailureCategory category) =>
      switch (category) {
        FailureCategory.validation => RecoveryGuidance.correctInput,
        FailureCategory.authenticationSession => RecoveryGuidance.signInAgain,
        FailureCategory.access || FailureCategory.capacityQuota =>
          RecoveryGuidance.contactResponsibleTeam,
        FailureCategory.conflictDuplicate => RecoveryGuidance.doNotRetry,
        FailureCategory.missingData => RecoveryGuidance.correctInput,
        FailureCategory.temporaryService ||
        FailureCategory.connectivity => RecoveryGuidance.retrySafely,
        FailureCategory.unexpected => RecoveryGuidance.checkStatusBeforeRetry,
      };
}
