import '../entities/company_os_operation_receipt.dart';
import '../entities/company_os_page.dart';
import '../entities/employee_portal_summary.dart';
import '../entities/it_ticket.dart';
import '../entities/knowledge_article.dart';

abstract interface class EmployeePortalRepository {
  Future<EmployeePortalSummary> summary();
  Future<CompanyOsPage<ItTicket>> ownTickets({String? cursor, int limit = 25});
  Future<ItTicket> ticket(String ticketId);
  Future<CompanyOsOperationReceipt> addPublicComment({
    required String ticketId,
    required String operationId,
    required String body,
  });
  Future<CompanyOsOperationReceipt> createTicket({
    required String operationId,
    required String subject,
    required String description,
    required String category,
    required ItTicketPriority priority,
  });
  Future<CompanyOsPage<KnowledgeArticle>> knowledge({
    String? query,
    String? cursor,
    int limit = 25,
  });
}
