import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'company_os_feature_flags.dart';

final class RemoteCompanyOsFeatureFlags extends ChangeNotifier
    implements CompanyOsFeatureFlags {
  RemoteCompanyOsFeatureFlags({
    required http.Client client,
    required Future<String?> Function() tokenProvider,
    required Uri baseUri,
  }) : _client = client,
       _tokenProvider = tokenProvider,
       _baseUri = baseUri;

  final http.Client _client;
  final Future<String?> Function() _tokenProvider;
  final Uri _baseUri;
  Set<CompanyOsFeature> _enabled = const <CompanyOsFeature>{};
  bool _refreshing = false;
  bool _ready = false;

  @override
  bool get isReady => _ready;

  @override
  bool isEnabledFor({
    required CompanyOsFeature feature,
    required String actorId,
  }) =>
      actorId.trim().isNotEmpty &&
      _enabled.contains(feature);

  @override
  Listenable get changes => this;

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final token = await _tokenProvider();
      if (token == null || token.trim().isEmpty) return clear();
      final response = await _client
          .get(
            _baseUri.resolve('/company-os/me'),
            headers: {'authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return clear();
      final decoded = jsonDecode(response.body);
      if (decoded is! Map ||
          decoded['ok'] != true ||
          decoded['flags'] is! Map) {
        return clear();
      }
      final flags = decoded['flags'] as Map;
      final enabled = <CompanyOsFeature>{};
      for (final entry in _serverNames.entries) {
        if (flags[entry.key] == true) enabled.add(entry.value);
      }
      _replace(Set.unmodifiable(enabled));
    } catch (_) {
      clear();
    } finally {
      _refreshing = false;
      _markReady();
    }
  }

  void clear() => _replace(const <CompanyOsFeature>{});

  /// Clears the old account's flags and makes route guards wait for the next
  /// account's server configuration instead of applying stale state.
  void resetForSignedOutUser() {
    final changed = _ready || _enabled.isNotEmpty;
    _ready = false;
    _enabled = const {};
    if (changed) notifyListeners();
  }

  void _markReady() {
    if (_ready) return;
    _ready = true;
    notifyListeners();
  }

  void _replace(Set<CompanyOsFeature> value) {
    if (setEquals(_enabled, value)) return;
    _enabled = value;
    notifyListeners();
  }

  static const _serverNames = <String, CompanyOsFeature>{
    'company_os_portal_v1': CompanyOsFeature.portal,
    'company_os_it_v1': CompanyOsFeature.itOperations,
    'company_os_requests_v1': CompanyOsFeature.requests,
    'company_os_operations_v1': CompanyOsFeature.operations,
    'company_os_organization_v1': CompanyOsFeature.organization,
    'company_os_multi_tree_v1': CompanyOsFeature.multiOrganization,
  };
}
