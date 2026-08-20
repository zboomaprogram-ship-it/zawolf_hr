import 'failure_category.dart';
import 'recovery_guidance.dart';

/// Whether the caller can prove the final outcome of a write-like operation.
enum OutcomeCertainty { confirmedNotCompleted, unknown }

/// An immutable, provider-neutral description of an unsuccessful operation.
final class AppFailure {
  factory AppFailure({
    required FailureCategory category,
    required RecoveryGuidance recovery,
    required OutcomeCertainty outcomeCertainty,
    String? diagnosticKey,
    Map<String, String> diagnosticContext = const {},
  }) {
    if (outcomeCertainty == OutcomeCertainty.unknown &&
        recovery != RecoveryGuidance.checkStatusBeforeRetry) {
      throw ArgumentError.value(
        recovery,
        'recovery',
        'Unknown outcomes must be checked before retrying.',
      );
    }
    if (!_hasOnlySafeDiagnosticContext(diagnosticContext)) {
      throw ArgumentError.value(
        diagnosticContext.keys,
        'diagnosticContext',
        'Diagnostic context contains a sensitive key.',
      );
    }
    return AppFailure._(
      category: category,
      recovery: recovery,
      outcomeCertainty: outcomeCertainty,
      diagnosticKey: diagnosticKey,
      diagnosticContext: Map.unmodifiable(diagnosticContext),
    );
  }

  const AppFailure._({
    required this.category,
    required this.recovery,
    required this.outcomeCertainty,
    this.diagnosticKey,
    required this.diagnosticContext,
  });

  final FailureCategory category;
  final RecoveryGuidance recovery;
  final OutcomeCertainty outcomeCertainty;
  final String? diagnosticKey;
  final Map<String, String> diagnosticContext;

  bool get canRetrySafely => recovery == RecoveryGuidance.retrySafely;
  bool get requiresStatusCheck =>
      recovery == RecoveryGuidance.checkStatusBeforeRetry;

  static bool _hasOnlySafeDiagnosticContext(Map<String, String> context) {
    const forbiddenTerms = <String>[
      'token',
      'secret',
      'password',
      'credential',
      'authorization',
      'employee',
      'firestore',
      'path',
      'exception',
      'stack',
    ];
    return context.keys.every(
      (key) => !forbiddenTerms.any((term) => key.toLowerCase().contains(term)),
    );
  }
}
