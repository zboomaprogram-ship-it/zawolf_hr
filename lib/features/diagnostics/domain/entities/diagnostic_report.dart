final class DiagnosticReportQuery {
  const DiagnosticReportQuery({
    this.release,
    this.feature,
    this.safeCode,
    this.limit = 100,
  });

  final String? release;
  final String? feature;
  final String? safeCode;
  final int limit;
}

/// Sanitized aggregate returned to authorized operational users.
///
/// It intentionally contains no actor, employee, request, URL, provider
/// exception, or stack trace.
final class DiagnosticReport {
  const DiagnosticReport({
    required this.fingerprint,
    required this.feature,
    required this.safeCode,
    required this.release,
    required this.count,
    required this.lastSeenAt,
    this.metadata = const {},
  });

  final String fingerprint;
  final String feature;
  final String safeCode;
  final String release;
  final int count;
  final DateTime? lastSeenAt;
  final Map<String, String> metadata;

  factory DiagnosticReport.fromSafeMap(Map<String, Object?> value) {
    final rawMetadata = value['metadata'];
    return DiagnosticReport(
      fingerprint: '${value['fingerprint'] ?? ''}',
      feature: '${value['feature'] ?? 'unknown'}',
      safeCode: '${value['safeCode'] ?? 'unexpected'}',
      release: '${value['release'] ?? 'unknown'}',
      count: value['count'] is num
          ? (value['count'] as num).toInt()
          : int.tryParse('${value['count']}') ?? 0,
      lastSeenAt: DateTime.tryParse('${value['lastSeenAt'] ?? ''}')?.toLocal(),
      metadata: rawMetadata is Map
          ? Map.unmodifiable({
              for (final entry in rawMetadata.entries)
                '${entry.key}': '${entry.value}',
            })
          : const {},
    );
  }
}
