import 'company_os_attachment_reference.dart';

enum ItTicketPriority { low, medium, high, critical }

enum ItTicketStatus {
  newTicket,
  assigned,
  inProgress,
  waitingForEmployee,
  resolved,
  closed,
}

final class ItTicket {
  const ItTicket({
    required this.id,
    required this.requesterUid,
    required this.subject,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.version,
    required this.createdAt,
    this.assignedItUid,
    this.slaDueAt,
    this.resolvedAt,
    this.resolutionSummary,
    this.attachments = const [],
  });

  final String id;
  final String requesterUid;
  final String subject;
  final String description;
  final String category;
  final ItTicketPriority priority;
  final ItTicketStatus status;
  final int version;
  final DateTime createdAt;
  final String? assignedItUid;
  final DateTime? slaDueAt;
  final DateTime? resolvedAt;
  final String? resolutionSummary;
  final List<CompanyOsAttachmentReference> attachments;

  bool canBeSeenBy(String employeeUid) => requesterUid == employeeUid;

  bool get isOverdue =>
      slaDueAt != null &&
      resolvedAt == null &&
      DateTime.now().isAfter(slaDueAt!);

  bool canTransitionTo(ItTicketStatus next) => switch (status) {
    ItTicketStatus.newTicket => next == ItTicketStatus.assigned,
    ItTicketStatus.assigned => next == ItTicketStatus.inProgress,
    ItTicketStatus.inProgress =>
      next == ItTicketStatus.waitingForEmployee ||
          next == ItTicketStatus.resolved,
    ItTicketStatus.waitingForEmployee =>
      next == ItTicketStatus.inProgress || next == ItTicketStatus.resolved,
    ItTicketStatus.resolved => next == ItTicketStatus.closed,
    ItTicketStatus.closed => next == ItTicketStatus.inProgress,
  };
}

final class TicketPublicComment {
  const TicketPublicComment({
    required this.id,
    required this.ticketId,
    required this.authorUid,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String ticketId;
  final String authorUid;
  final String body;
  final DateTime createdAt;
}

final class TicketActivity {
  const TicketActivity({
    required this.id,
    required this.ticketId,
    required this.safeAction,
    required this.createdAt,
  });

  final String id;
  final String ticketId;
  final String safeAction;
  final DateTime createdAt;
}
