import '../entities/company_operations_query.dart';
import '../entities/company_os_page.dart';
import '../entities/operational_audit_event.dart';

abstract interface class CompanyOsOperationsRepository {
  Future<CompanyOperationsDashboard> dashboard(CompanyOperationsFilter filter);
  Future<CompanyOperationsSearchPage> search(CompanyOperationsFilter filter);
  Future<CompanyOsPage<Map<String, Object?>>> report(
    String reportType,
    CompanyOperationsFilter filter,
  );
  Future<CompanyOsPage<OperationalAuditEvent>> audit(
    CompanyOperationsFilter filter,
  );
  Future<String> export(String reportType, CompanyOperationsFilter filter);
}
