import '../../domain/entities/workspace_report_period.dart';
import '../../domain/repositories/workspace_reports_repository.dart';
import '../datasources/workspace_reports_remote_data_source.dart';

final class WorkspaceReportsRepositoryImpl
    implements WorkspaceReportsRepository {
  const WorkspaceReportsRepositoryImpl(this._remote);
  final WorkspaceReportsRemoteDataSource _remote;

  @override
  Future<String> requestHrOperationalReport({
    required WorkspaceReportPeriod period,
    required String reportType,
  }) => _remote.request(
    path: '/company-workspace/v2/reports/hr',
    body: _body(period, {'reportType': reportType}),
  );

  @override
  Future<String> requestWorkspaceActivityReport({
    required WorkspaceReportPeriod period,
    required String scopeId,
  }) => _remote.request(
    path: '/company-workspace/v2/reports/audit',
    body: _body(period, {'scopeId': scopeId}),
  );

  Map<String, Object?> _body(
    WorkspaceReportPeriod period,
    Map<String, Object?> extra,
  ) {
    String date(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    return {
      'startDate': date(period.startsOn),
      'endDate': date(period.endsOn),
      ...extra,
    };
  }
}
