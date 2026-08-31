import '../entities/company_asset.dart';
import '../entities/company_os_operation_receipt.dart';
import '../entities/company_os_page.dart';
import '../entities/it_ticket.dart';
import '../entities/software_license.dart';
import '../entities/ticket_private_note.dart';

abstract interface class ItOperationsRepository {
  Future<CompanyOsPage<ItTicket>> tickets({String? cursor, int limit = 25});
  Future<ItTicket> ticket(String id);
  Future<CompanyOsOperationReceipt> assignTicket({
    required String ticketId,
    required String assigneeUid,
    required String operationId,
    required int expectedVersion,
  });
  Future<CompanyOsOperationReceipt> transitionTicket({
    required String ticketId,
    required ItTicketStatus status,
    required String operationId,
    required int expectedVersion,
    String? resolutionSummary,
  });
  Future<void> addPrivateNote({
    required String ticketId,
    required String operationId,
    required String body,
  });
  Future<CompanyOsPage<TicketPrivateNote>> privateNotes(String ticketId);
  Future<CompanyOsPage<CompanyAsset>> assets({String? cursor, int limit = 25});
  Future<CompanyAsset> asset(String id);
  Future<CompanyOsPage<AssetAssignment>> assetHistory(String assetId);
  Future<CompanyOsPage<AssetMaintenance>> assetMaintenance(String assetId);
  Future<CompanyOsOperationReceipt> createAsset({
    required String operationId,
    required String assetCode,
    required String name,
    required String type,
  });
  Future<CompanyOsOperationReceipt> assignAsset({
    required String assetId,
    required String employeeUid,
    required String operationId,
    required int expectedVersion,
    String condition = '',
  });
  Future<CompanyOsOperationReceipt> returnAsset({
    required String assetId,
    required String operationId,
    required int expectedVersion,
    String reason = '',
    String condition = '',
  });
  Future<CompanyOsOperationReceipt> openAssetMaintenance({
    required String assetId,
    required String operationId,
    required int expectedVersion,
    required String problem,
    num cost = 0,
    String currency = 'EGP',
    String? costRequestId,
  });
  Future<CompanyOsOperationReceipt> retireAsset({
    required String assetId,
    required String operationId,
    required int expectedVersion,
  });
  Future<CompanyOsPage<SoftwareLicense>> licenses({
    String? cursor,
    int limit = 25,
  });
  Future<SoftwareLicense> license(String id);
  Future<CompanyOsPage<SoftwareAssignment>> licenseAssignments(
    String licenseId,
  );
  Future<CompanyOsOperationReceipt> createLicense({
    required String operationId,
    required String name,
    required String vendor,
    required int totalSeats,
  });
  Future<CompanyOsOperationReceipt> assignLicenseSeat({
    required String licenseId,
    required String employeeUid,
    required String operationId,
    required int expectedVersion,
  });
  Future<CompanyOsOperationReceipt> revokeLicenseSeat({
    required String licenseId,
    required String employeeUid,
    required String operationId,
    required int expectedVersion,
  });
  Future<CompanyOsOperationReceipt> renewLicense({
    required String licenseId,
    required String operationId,
    required int expectedVersion,
    required DateTime renewalAt,
    int? totalSeats,
  });
}
