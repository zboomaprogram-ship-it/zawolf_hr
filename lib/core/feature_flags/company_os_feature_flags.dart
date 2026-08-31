import 'package:flutter/foundation.dart';

enum CompanyOsFeature {
  portal('company_os_portal_v1'),
  itOperations('company_os_it_v1'),
  requests('company_os_requests_v1'),
  operations('company_os_operations_v1'),
  organization('company_os_organization_v1'),
  multiOrganization('company_os_multi_tree_v1');

  const CompanyOsFeature(this.serverName);

  final String serverName;
}

abstract interface class CompanyOsFeatureFlags {
  /// True after the current signed-in user's remote configuration was resolved.
  ///
  /// Routes use this to avoid redirecting a valid deep link to a dashboard
  /// before the first `/company-os/me` request has completed.
  bool get isReady;

  bool isEnabledFor({
    required CompanyOsFeature feature,
    required String actorId,
  });

  Listenable get changes;
}

/// Production-safe fallback used whenever remote configuration is absent,
/// invalid, or unavailable.
final class DisabledCompanyOsFeatureFlags implements CompanyOsFeatureFlags {
  const DisabledCompanyOsFeatureFlags();

  @override
  bool get isReady => true;

  @override
  bool isEnabledFor({
    required CompanyOsFeature feature,
    required String actorId,
  }) => false;

  @override
  Listenable get changes => const _NoopCompanyOsListenable();
}

/// Deterministic test/pilot override. IDs must come from a trusted server
/// configuration; employee codes are deliberately unsupported here.
final class PilotCompanyOsFeatureFlags implements CompanyOsFeatureFlags {
  const PilotCompanyOsFeatureFlags({
    this.enabledForEveryone = const <CompanyOsFeature>{},
    this.enabledActorIds = const <CompanyOsFeature, Set<String>>{},
  });

  final Set<CompanyOsFeature> enabledForEveryone;
  final Map<CompanyOsFeature, Set<String>> enabledActorIds;

  @override
  bool get isReady => true;

  @override
  bool isEnabledFor({
    required CompanyOsFeature feature,
    required String actorId,
  }) {
    final normalizedActorId = actorId.trim();
    if (normalizedActorId.isEmpty) return false;
    return enabledForEveryone.contains(feature) ||
        (enabledActorIds[feature]?.contains(normalizedActorId) ?? false);
  }

  @override
  Listenable get changes => const _NoopCompanyOsListenable();
}

final class _NoopCompanyOsListenable implements Listenable {
  const _NoopCompanyOsListenable();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
