/// A sanitized, aggregate-friendly operational event.
///
/// This model deliberately has no employee identity, request content, provider
/// exception, token, URL, or stack trace. Those values must never leave the
/// device through diagnostics.
final class DiagnosticEvent {
  factory DiagnosticEvent.create({
    required String feature,
    required String safeCode,
    required String release,
    required DateTime occurredAt,
    Map<String, String> metadata = const {},
  }) {
    final normalizedFeature = _safeIdentifier(feature, fallback: 'unknown');
    final normalizedCode = _safeIdentifier(safeCode, fallback: 'unexpected');
    final normalizedRelease = release.trim().replaceAll(
      RegExp(r'[^A-Za-z0-9._+-]'),
      '',
    );
    return DiagnosticEvent._(
      feature: normalizedFeature,
      safeCode: normalizedCode,
      release: normalizedRelease.isEmpty ? 'unknown' : normalizedRelease,
      occurredAt: occurredAt.toUtc(),
      metadata: Map.unmodifiable(_safeMetadata(metadata)),
    );
  }

  const DiagnosticEvent._({
    required this.feature,
    required this.safeCode,
    required this.release,
    required this.occurredAt,
    required this.metadata,
  });

  final String feature;
  final String safeCode;
  final String release;
  final DateTime occurredAt;
  final Map<String, String> metadata;

  Map<String, Object> toSafeMap() => {
    'feature': feature,
    'safeCode': safeCode,
    'release': release,
    'occurredAt': occurredAt.toIso8601String(),
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  static String _safeIdentifier(String value, {required String fallback}) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return normalized.isEmpty
        ? fallback
        : normalized.substring(
            0,
            normalized.length > 64 ? 64 : normalized.length,
          );
  }

  static Map<String, String> _safeMetadata(Map<String, String> source) {
    const allowedKeys = {'surface', 'platform', 'operation', 'state'};
    return {
      for (final entry in source.entries)
        if (allowedKeys.contains(entry.key) &&
            !RegExp(
              r'(token|secret|password|credential|email|uid|path|url)',
              caseSensitive: false,
            ).hasMatch(entry.value))
          entry.key: entry.value.substring(
            0,
            entry.value.length > 80 ? 80 : entry.value.length,
          ),
    };
  }
}
