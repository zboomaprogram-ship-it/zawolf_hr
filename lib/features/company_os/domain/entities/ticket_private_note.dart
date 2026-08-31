final class TicketPrivateNote {
  const TicketPrivateNote({
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
