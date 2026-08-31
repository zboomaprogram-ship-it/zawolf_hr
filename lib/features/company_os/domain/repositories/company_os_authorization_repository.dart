import '../entities/operational_role_grant.dart';

enum CompanyOsCapability {
  viewPortal,
  submitTicket,
  manageTickets,
  manageAssets,
  manageSoftware,
  reviewFinance,
  manageRequests,
  viewOperations,
}

abstract interface class CompanyOsAuthorizationRepository {
  Future<List<OperationalRoleGrant>> grantsFor(String employeeUid);

  Future<bool> isAllowed({
    required String employeeUid,
    required CompanyOsCapability capability,
    String? targetEmployeeUid,
    String? targetDepartmentId,
  });
}
