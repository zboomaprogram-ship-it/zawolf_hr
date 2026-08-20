/// In-memory, aggregate-only counters for the guarded reliability pilot.
///
/// Deliberately contains no employee identifier, request payload, or provider
/// diagnostic. A host application can sample these counts for a short pilot
/// window without adding a listener or a new persistence dependency.
class CheckInPilotMetrics {
  int saved = 0;
  int pendingSync = 0;
  int requiresStatusCheck = 0;
  int safeFailure = 0;

  Map<String, int> snapshot() => <String, int>{
    'saved': saved,
    'pendingSync': pendingSync,
    'requiresStatusCheck': requiresStatusCheck,
    'safeFailure': safeFailure,
  };
}
