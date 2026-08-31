import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/company_os/domain/entities/it_ticket.dart';

void main() {
  test('employee ticket is strictly self-scoped', () {
    final ticket = ItTicket(
      id: 'ticket-1',
      requesterUid: 'employee-1',
      subject: 'حاسوب العمل',
      description: 'الجهاز لا يعمل',
      category: 'laptop',
      priority: ItTicketPriority.medium,
      status: ItTicketStatus.newTicket,
      version: 1,
      createdAt: DateTime.utc(2026, 8, 24),
    );
    expect(ticket.canBeSeenBy('employee-1'), isTrue);
    expect(ticket.canBeSeenBy('employee-2'), isFalse);
  });
}
