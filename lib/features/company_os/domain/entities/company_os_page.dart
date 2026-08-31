final class CompanyOsPage<T> {
  const CompanyOsPage({
    required this.items,
    required this.appliedScope,
    this.nextCursor,
    this.appliedFilters = const <String, Object?>{},
  });

  final List<T> items;
  final String appliedScope;
  final String? nextCursor;
  final Map<String, Object?> appliedFilters;
}
