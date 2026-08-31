import '../entities/diagnostic_event.dart';
import '../entities/diagnostic_report.dart';

abstract interface class DiagnosticsRepository {
  /// Best-effort only: a diagnostics outage must never block an employee flow.
  Future<void> report(DiagnosticEvent event);

  /// Bounded, authorized aggregate reports. Implementations must never return
  /// raw exceptions, employee identity, provider payloads, URLs, or stacks.
  Future<List<DiagnosticReport>> loadReports(DiagnosticReportQuery query);
}
