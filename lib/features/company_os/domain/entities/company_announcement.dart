final class CompanyAnnouncement {
  const CompanyAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.isPinned,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final bool isPinned;
}
