import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/sync/authenticated_operation_client.dart';
import '../features/diagnostics/data/diagnostics_repository_impl.dart';
import '../features/diagnostics/domain/entities/diagnostic_event.dart';
import '../features/diagnostics/domain/entities/diagnostic_report.dart';
import '../features/diagnostics/domain/repositories/diagnostics_repository.dart';

/// App-lifetime, best-effort diagnostics boundary.
///
/// Callers can only provide allowlisted aggregate labels. The repository and
/// server sanitize again before persistence.
final class SafeDiagnosticsService implements DiagnosticsRepository {
  SafeDiagnosticsService._()
    : _delegate = DiagnosticsRepositoryImpl(
        operationClient: AuthenticatedOperationClient(
          client: http.Client(),
          tokenProvider: () async =>
              FirebaseAuth.instance.currentUser?.getIdToken(),
        ),
        operationsBaseUri: Uri.parse('https://notification.zawolf.ai'),
      );

  static final SafeDiagnosticsService instance = SafeDiagnosticsService._();
  static const _release = String.fromEnvironment(
    'APP_RELEASE',
    defaultValue: 'unknown',
  );

  final DiagnosticsRepository _delegate;

  Future<void> capture({
    required String feature,
    required String safeCode,
    required String operation,
    String surface = 'app',
    String state = '',
  }) => report(
    DiagnosticEvent.create(
      feature: feature,
      safeCode: safeCode,
      release: _release,
      occurredAt: DateTime.now(),
      metadata: {
        'surface': surface,
        'operation': operation,
        if (state.isNotEmpty) 'state': state,
      },
    ),
  );

  @override
  Future<void> report(DiagnosticEvent event) => _delegate.report(event);

  @override
  Future<List<DiagnosticReport>> loadReports(DiagnosticReportQuery query) =>
      _delegate.loadReports(query);
}
