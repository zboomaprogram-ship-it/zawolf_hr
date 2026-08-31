import '../entities/workspace_report_period.dart';

abstract interface class WorkspaceReportsRepository {
  Future<String> requestWorkspaceActivityReport({
    required WorkspaceReportPeriod period,
    required String scopeId,
  });

  Future<String> requestHrOperationalReport({
    required WorkspaceReportPeriod period,
    required String reportType,
  });
}
