import 'sales_identity_mapping.dart';
import 'sales_indicator_filter.dart';

enum SalesSourceHealth { healthy, partial, stale, unavailable }

final class SalesIndicatorSnapshot {
  const SalesIndicatorSnapshot({
    required this.snapshotId,
    required this.filterVersion,
    required this.filter,
    required this.sourceHealth,
    required this.generatedAt,
    this.rows = const <SalesIdentityMapping>[],
    this.warningsAr = const <String>[],
  });

  final String snapshotId;
  final String filterVersion;
  final SalesIndicatorFilter filter;
  final SalesSourceHealth sourceHealth;
  final DateTime? generatedAt;
  final List<SalesIdentityMapping> rows;
  final List<String> warningsAr;

  bool get matchesFilter => filterVersion.isNotEmpty;
}
