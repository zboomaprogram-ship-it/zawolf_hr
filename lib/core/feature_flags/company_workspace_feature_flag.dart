import 'package:flutter/foundation.dart';

/// The Company Workspace V2 switch is intentionally injectable and fail-closed.
///
/// It defaults to off so a deployment can never replace the live Workspace
/// route accidentally. A remote configuration adapter may supply an explicit
/// pilot audience, but a missing or failed adapter must preserve this default.
abstract interface class CompanyWorkspaceFeatureFlag {
  bool isEnabledFor({required String actorId});

  /// Notifies the router when the server safely changes pilot audience.
  Listenable get changes;
}

final class DisabledCompanyWorkspaceFeatureFlag
    implements CompanyWorkspaceFeatureFlag {
  const DisabledCompanyWorkspaceFeatureFlag();

  @override
  bool isEnabledFor({required String actorId}) => false;

  @override
  Listenable get changes => const _NoopWorkspaceFlagListenable();
}

/// A deterministic, testable pilot flag. The caller supplies IDs from a
/// trusted server/configuration source; no employee code is hard-coded here.
final class PilotCompanyWorkspaceFeatureFlag
    implements CompanyWorkspaceFeatureFlag {
  const PilotCompanyWorkspaceFeatureFlag({
    required this.enabledActorIds,
    this.enabledForEveryone = false,
  });

  final Set<String> enabledActorIds;
  final bool enabledForEveryone;

  @override
  bool isEnabledFor({required String actorId}) =>
      enabledForEveryone || enabledActorIds.contains(actorId);

  @override
  Listenable get changes => const _NoopWorkspaceFlagListenable();
}

final class _NoopWorkspaceFlagListenable implements Listenable {
  const _NoopWorkspaceFlagListenable();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
