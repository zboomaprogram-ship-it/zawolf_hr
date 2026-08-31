import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_workspace/domain/entities/workspace_report_period.dart';
import 'package:zawolf_hr/features/company_workspace/domain/repositories/workspace_reports_repository.dart';
import 'package:zawolf_hr/features/company_workspace/domain/use_cases/request_workspace_report.dart';

void main() {
  test('report use cases preserve the requested period and scope', () async {
    final repository = _ReportsRepository();
    final period = WorkspaceReportPeriod(
      type: WorkspaceReportPeriodType.monthly,
      startsOn: DateTime(2026, 8, 1),
      endsOn: DateTime(2026, 8, 31),
    );
    await RequestWorkspaceActivityReport(repository)(
      period: period,
      scopeId: 'company',
    );
    await RequestHrOperationalReport(repository)(
      period: period,
      reportType: 'attendance',
    );
    expect(repository.activityScope, 'company');
    expect(repository.hrType, 'attendance');
  });
}

final class _ReportsRepository implements WorkspaceReportsRepository {
  String? activityScope;
  String? hrType;

  @override
  Future<String> requestHrOperationalReport({
    required WorkspaceReportPeriod period,
    required String reportType,
  }) async {
    hrType = reportType;
    return 'hr';
  }

  @override
  Future<String> requestWorkspaceActivityReport({
    required WorkspaceReportPeriod period,
    required String scopeId,
  }) async {
    activityScope = scopeId;
    return 'activity';
  }
}
