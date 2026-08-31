import '../entities/company_os_operation_receipt.dart';
import '../entities/it_ticket.dart';
import '../repositories/employee_portal_repository.dart';

final class SubmitItTicket {
  const SubmitItTicket(this._repository);

  final EmployeePortalRepository _repository;

  Future<CompanyOsOperationReceipt> call({
    required String operationId,
    required String subject,
    required String description,
    required String category,
    required ItTicketPriority priority,
  }) {
    if (subject.trim().length < 3 || description.trim().length < 5) {
      throw ArgumentError('بيانات التذكرة غير مكتملة.');
    }
    return _repository.createTicket(
      operationId: operationId,
      subject: subject.trim(),
      description: description.trim(),
      category: category,
      priority: priority,
    );
  }
}
