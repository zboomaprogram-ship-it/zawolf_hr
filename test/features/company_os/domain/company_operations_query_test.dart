import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/company_operations_query.dart';

void main() {
  test('page size is always bounded', () {
    expect(const CompanyOperationsFilter(limit: 0).safeLimit, 1);
    expect(const CompanyOperationsFilter(limit: 500).safeLimit, 100);
  });

  test('dashboard keeps its server-derived scope', () {
    const dashboard = CompanyOperationsDashboard(
      openTickets: 2,
      assignedAssets: 3,
      expiringLicenses: 1,
      pendingRequests: 4,
      scope: 'department',
    );
    expect(dashboard.scope, 'department');
  });
}
