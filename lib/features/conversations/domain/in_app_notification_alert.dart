/// Presentation-safe notification data for an already-authorized app alert.
class InAppNotificationAlert {
  final String id;
  final String title;
  final String body;
  final String type;
  final String route;
  final DateTime timestamp;
  final bool isRead;

  const InAppNotificationAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.route,
    required this.timestamp,
    this.isRead = false,
  });

  bool get isChatMessage =>
      type == 'conversation' ||
      route.startsWith('/conversations') ||
      route.contains('channel');
}

/// The presentation boundary for receiving and opening in-app alerts.
abstract interface class InAppNotificationAlerts {
  Stream<InAppNotificationAlert> get alerts;

  Future<void> open(InAppNotificationAlert notification);
}
