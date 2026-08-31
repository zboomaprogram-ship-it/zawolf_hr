import '../entities/company_os_operation_receipt.dart';
import '../entities/it_ticket.dart';
import '../repositories/it_operations_repository.dart';

final class AssignItTicket {
  const AssignItTicket(this.repository);
  final ItOperationsRepository repository;
  Future<CompanyOsOperationReceipt> call({
    required String ticketId,
    required String assigneeUid,
    required String operationId,
    required int expectedVersion,
  }) => repository.assignTicket(
    ticketId: ticketId,
    assigneeUid: assigneeUid,
    operationId: operationId,
    expectedVersion: expectedVersion,
  );
}

final class TransitionItTicket {
  const TransitionItTicket(this.repository);
  final ItOperationsRepository repository;
  Future<CompanyOsOperationReceipt> call({
    required String ticketId,
    required ItTicketStatus status,
    required String operationId,
    required int expectedVersion,
    String? resolutionSummary,
  }) => repository.transitionTicket(
    ticketId: ticketId,
    status: status,
    operationId: operationId,
    expectedVersion: expectedVersion,
    resolutionSummary: resolutionSummary,
  );
}
