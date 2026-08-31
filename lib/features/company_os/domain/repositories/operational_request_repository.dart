import '../entities/company_os_operation_receipt.dart';
import '../entities/company_os_page.dart';
import '../entities/company_os_attachment_reference.dart';
import '../entities/unified_operational_request.dart';

abstract interface class OperationalRequestRepository {
  Future<CompanyOsPage<UnifiedOperationalRequest>> requests({
    String? cursor,
    int limit = 25,
  });
  Future<UnifiedOperationalRequest> request(String id);
  Future<CompanyOsOperationReceipt> create({
    required String operationId,
    required String requestType,
    required String businessReason,
    required DateTime executionDate,
    num? amount,
    String? currency,
    List<CompanyOsAttachmentReference> attachments = const [],
  });
  Future<CompanyOsOperationReceipt> decide({
    required String requestId,
    required String operationId,
    required int expectedVersion,
    required bool approved,
    required String reason,
  });
  Future<CompanyOsOperationReceipt> completePayment({
    required String requestId,
    required String operationId,
    required int expectedVersion,
    required String reference,
  });
  Future<CompanyOsOperationReceipt> completeClosure({
    required String requestId,
    required String operationId,
    required int expectedVersion,
    required String note,
    bool accessProvisioning = false,
  });
}
