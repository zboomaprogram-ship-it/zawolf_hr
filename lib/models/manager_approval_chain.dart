class ManagerApprovalChain {
  const ManagerApprovalChain._();

  static List<String> orderedIds(
    Iterable<String> managerIds, {
    String? fallbackId,
    String? teamLeaderId,
  }) {
    final ordered = <String>[];
    final seen = <String>{};
    final candidates = <String>[
      if (teamLeaderId != null) teamLeaderId,
      ...managerIds,
    ];
    for (final rawId in candidates) {
      final id = rawId.trim();
      if (id.isNotEmpty && seen.add(id)) ordered.add(id);
    }
    final fallback = fallbackId?.trim() ?? '';
    if (ordered.isEmpty && fallback.isNotEmpty) ordered.add(fallback);
    return ordered;
  }

  static List<String> orderedNames({
    required List<String> orderedIds,
    required List<String> managerIds,
    required List<String> managerNames,
    String? teamLeaderId,
    String? teamLeaderName,
    String? fallbackManagerId,
    String? fallbackManagerName,
  }) {
    return orderedIds.map((id) {
      if (id == teamLeaderId && (teamLeaderName ?? '').trim().isNotEmpty) {
        return teamLeaderName!.trim();
      }
      final index = managerIds.indexOf(id);
      if (index >= 0 && index < managerNames.length) {
        return managerNames[index].trim();
      }
      if (id == fallbackManagerId) return fallbackManagerName?.trim() ?? '';
      return '';
    }).toList();
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

  static bool usesHrFallback({
    required bool isSuperAdmin,
    required List<String> managerIds,
  }) {
    return managerIds.isEmpty;
  }
}
