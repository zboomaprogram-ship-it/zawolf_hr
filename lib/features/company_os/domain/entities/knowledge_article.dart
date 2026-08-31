final class KnowledgeArticle {
  const KnowledgeArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.content,
    required this.revision,
  });

  final String id;
  final String title;
  final String category;
  final String content;
  final int revision;
}
