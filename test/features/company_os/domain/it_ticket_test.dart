import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/it_ticket.dart';

void main() {
  ItTicket ticket(ItTicketStatus status) => ItTicket(
    id: 't1',
    requesterUid: 'u1',
    subject: 's',
    description: 'd',
    category: 'other',
    priority: ItTicketPriority.medium,
    status: status,
    version: 1,
    createdAt: DateTime(2026),
  );

  test('ticket lifecycle accepts only explicit transitions', () {
    expect(
      ticket(ItTicketStatus.newTicket).canTransitionTo(ItTicketStatus.assigned),
      isTrue,
    );
    expect(
      ticket(ItTicketStatus.newTicket).canTransitionTo(ItTicketStatus.resolved),
      isFalse,
    );
    expect(
      ticket(ItTicketStatus.closed).canTransitionTo(ItTicketStatus.inProgress),
      isTrue,
    );
  });
}
