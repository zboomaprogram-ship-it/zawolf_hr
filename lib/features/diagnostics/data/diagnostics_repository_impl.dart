import '../../../core/sync/authenticated_operation_client.dart';
import '../domain/entities/diagnostic_event.dart';
import '../domain/entities/diagnostic_report.dart';
import '../domain/repositories/diagnostics_repository.dart';

final class DiagnosticsRepositoryImpl implements DiagnosticsRepository {
  DiagnosticsRepositoryImpl({
    required AuthenticatedOperationClient operationClient,
    required Uri operationsBaseUri,
  }) : _client = operationClient,
       _baseUri = operationsBaseUri;

  final AuthenticatedOperationClient _client;
  final Uri _baseUri;

  @override
  Future<void> report(DiagnosticEvent event) async {
    try {
      await _client.post(
        _baseUri.resolve('/operations/diagnostics'),
        operationId: 'diagnostic-${DateTime.now().microsecondsSinceEpoch}',
        body: event.toSafeMap(),
      );
    } catch (_) {
      // Diagnostics are deliberately best-effort and never block user work.
    }
  }

  @override
  Future<List<DiagnosticReport>> loadReports(
    DiagnosticReportQuery query,
  ) async {
    final response = await _client.get(
      _baseUri
          .resolve('/operations/diagnostics')
          .replace(
            queryParameters: {
              'limit': '${query.limit.clamp(1, 100)}',
              if (query.release?.trim().isNotEmpty == true)
                'release': query.release!.trim(),
              if (query.feature?.trim().isNotEmpty == true)
                'feature': query.feature!.trim(),
              if (query.safeCode?.trim().isNotEmpty == true)
                'safeCode': query.safeCode!.trim(),
            },
          ),
    );
    if (!response.ok) throw DiagnosticsReportFailure(response.safeCode);
    return (response.data['reports'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (value) =>
              DiagnosticReport.fromSafeMap(Map<String, Object?>.from(value)),
        )
        .toList(growable: false);
  }
}

final class DiagnosticsReportFailure implements Exception {
  const DiagnosticsReportFailure(this.safeCode);
  final String safeCode;
}
