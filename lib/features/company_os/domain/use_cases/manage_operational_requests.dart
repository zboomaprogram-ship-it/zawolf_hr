import '../entities/company_os_operation_receipt.dart';
import '../repositories/operational_request_repository.dart';

final class SubmitOperationalRequest {
  const SubmitOperationalRequest(this.repository);
  final OperationalRequestRepository repository;
  Future<CompanyOsOperationReceipt> call({
    required String operationId,
    required String requestType,
    required String businessReason,
    required DateTime executionDate,
    num? amount,
    String? currency,
  }) => repository.create(
    operationId: operationId,
    requestType: requestType,
    businessReason: businessReason,
    executionDate: executionDate,
    amount: amount,
    currency: currency,
  );
}

final class DecideOperationalRequest {
  const DecideOperationalRequest(this.repository);
  final OperationalRequestRepository repository;
  Future<CompanyOsOperationReceipt> call({
    required String requestId,
    required String operationId,
    required int expectedVersion,
    required bool approved,
    required String reason,
  }) => repository.decide(
    requestId: requestId,
    operationId: operationId,
    expectedVersion: expectedVersion,
    approved: approved,
    reason: reason,
  );
}
