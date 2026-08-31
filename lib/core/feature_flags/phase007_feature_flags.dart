import 'package:flutter/foundation.dart';

/// Vertical slices introduced by Phase 007.
///
/// Each slice is fail-closed. A client may use these flags only to choose an
/// additive experience; authorization is always enforced by the server.
enum Phase007Feature {
  employeeOperations,
  workOutcomes,
  notificationOperations,
  operationalVisibility,
  salesIndicators,
  diagnostics,
  developerTools,
  employeeAssistant,
  conversations,
}

abstract interface class Phase007FeatureFlags {
  bool isEnabledFor({
    required Phase007Feature feature,
    required String actorId,
  });

  Listenable get changes;
}

/// Production-safe default. A missing remote flag must never enable a new
/// operational flow or developer tooling.
final class DisabledPhase007FeatureFlags implements Phase007FeatureFlags {
  const DisabledPhase007FeatureFlags();

  @override
  bool isEnabledFor({
    required Phase007Feature feature,
    required String actorId,
  }) =>
      false;

  @override
  Listenable get changes => const _NoopPhase007FlagsListenable();
}

/// Deterministic pilot override used by tests and an explicitly configured
/// pilot audience. It intentionally contains no employee-code special case.
final class PilotPhase007FeatureFlags implements Phase007FeatureFlags {
  const PilotPhase007FeatureFlags({
    this.enabledForEveryone = const <Phase007Feature>{},
    this.enabledActorIds = const <Phase007Feature, Set<String>>{},
  });

  final Set<Phase007Feature> enabledForEveryone;
  final Map<Phase007Feature, Set<String>> enabledActorIds;

  @override
  bool isEnabledFor({
    required Phase007Feature feature,
    required String actorId,
  }) =>
      enabledForEveryone.contains(feature) ||
      (enabledActorIds[feature]?.contains(actorId) ?? false);

  @override
  Listenable get changes => const _NoopPhase007FlagsListenable();
}

final class _NoopPhase007FlagsListenable implements Listenable {
  const _NoopPhase007FlagsListenable();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
