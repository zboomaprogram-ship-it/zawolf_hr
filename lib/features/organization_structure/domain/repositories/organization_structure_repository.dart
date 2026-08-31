import '../../../company_os/domain/entities/company_os_operation_receipt.dart';
import '../entities/organization_change_set.dart';
import '../entities/organization_membership.dart';
import '../entities/organization_snapshot.dart';

abstract interface class OrganizationStructureRepository {
  Future<OrganizationSnapshot> loadHierarchy({bool includeArchived = false});
  Future<List<OrganizationMembership>> searchEmployees(String query);
  Future<OrganizationImpactPreview> preview(OrganizationChangeSet change);
  Future<CompanyOsOperationReceipt> apply(OrganizationChangeSet change);
  Future<CompanyOsOperationReceipt?> operationStatus(String operationId);
}
