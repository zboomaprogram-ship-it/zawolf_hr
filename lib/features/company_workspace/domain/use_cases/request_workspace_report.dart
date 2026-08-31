import '../entities/workspace_report_period.dart';
import '../repositories/workspace_reports_repository.dart';

final class RequestWorkspaceActivityReport {
  const RequestWorkspaceActivityReport(this._repository);
  final WorkspaceReportsRepository _repository;

  Future<String> call({
    required WorkspaceReportPeriod period,
    required String scopeId,
  }) => _repository.requestWorkspaceActivityReport(
    period: period,
    scopeId: scopeId,
  );
}

final class RequestHrOperationalReport {
  const RequestHrOperationalReport(this._repository);
  final WorkspaceReportsRepository _repository;

  Future<String> call({
    required WorkspaceReportPeriod period,
    required String reportType,
  }) => _repository.requestHrOperationalReport(
    period: period,
    reportType: reportType,
  );
}
