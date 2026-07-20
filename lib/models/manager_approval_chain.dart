class ManagerApprovalChain {
  const ManagerApprovalChain._();

  static List<String> orderedIds(
    Iterable<String> managerIds, {
    String? fallbackId,
  }) {
    final ordered = <String>[];
    final seen = <String>{};
    for (final rawId in managerIds) {
      final id = rawId.trim();
      if (id.isNotEmpty && seen.add(id)) ordered.add(id);
    }
    final fallback = fallbackId?.trim() ?? '';
    if (ordered.isEmpty && fallback.isNotEmpty) ordered.add(fallback);
    return ordered;
  }

  static int currentIndex({
    required List<String> managerIds,
    required String currentManagerId,
    int? savedIndex,
  }) {
    if (savedIndex != null &&
        savedIndex >= 0 &&
        savedIndex < managerIds.length &&
        managerIds[savedIndex] == currentManagerId) {
      return savedIndex;
    }
    return managerIds.indexOf(currentManagerId);
  }

  static int nextIndex({
    required List<String> managerIds,
    required String currentManagerId,
    int? savedIndex,
  }) {
    return currentIndex(
          managerIds: managerIds,
          currentManagerId: currentManagerId,
          savedIndex: savedIndex,
        ) +
        1;
  }
}
