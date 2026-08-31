import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'phase007_feature_flags.dart';

/// Server-owned Phase 007 rollout registry.
///
/// Missing sessions, invalid envelopes, network failures, and unknown flag
/// names all fail closed. No enabled state is persisted on the device.
final class RemotePhase007FeatureFlags extends ChangeNotifier
    implements Phase007FeatureFlags {
  RemotePhase007FeatureFlags({
    required http.Client client,
    required Future<String?> Function() tokenProvider,
    required Uri baseUri,
  }) : _client = client,
       _tokenProvider = tokenProvider,
       _baseUri = baseUri;

  final http.Client _client;
  final Future<String?> Function() _tokenProvider;
  final Uri _baseUri;
  Set<Phase007Feature> _enabled = const {};
  bool _refreshing = false;

  @override
  bool isEnabledFor({
    required Phase007Feature feature,
    required String actorId,
  }) => actorId.trim().isNotEmpty && _enabled.contains(feature);

  @override
  Listenable get changes => this;

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final token = await _tokenProvider();
      if (token == null || token.trim().isEmpty) {
        _replace(const {});
        return;
      }
      final response = await _client
          .get(
            _baseUri.resolve('/operations/feature-flags'),
            headers: {'authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        _replace(const {});
        return;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map ||
          decoded['ok'] != true ||
          decoded['enabled'] is! List) {
        _replace(const {});
        return;
      }
      final enabled = <Phase007Feature>{};
      for (final value in decoded['enabled'] as List) {
        final feature = _serverNames['$value'];
        if (feature != null) enabled.add(feature);
      }
      _replace(Set.unmodifiable(enabled));
    } catch (_) {
      _replace(const {});
    } finally {
      _refreshing = false;
    }
  }

  void clear() => _replace(const {});

  void _replace(Set<Phase007Feature> next) {
    if (setEquals(_enabled, next)) return;
    _enabled = next;
    notifyListeners();
  }

  static const _serverNames = <String, Phase007Feature>{
    'employee_operations_v2': Phase007Feature.employeeOperations,
    'work_outcomes_v2': Phase007Feature.workOutcomes,
    'notification_operations_v2': Phase007Feature.notificationOperations,
    'operational_visibility_v2': Phase007Feature.operationalVisibility,
    'sales_indicators_v2': Phase007Feature.salesIndicators,
    'diagnostics_v2': Phase007Feature.diagnostics,
    'developer_tools_v2': Phase007Feature.developerTools,
    'employee_assistant_v2': Phase007Feature.employeeAssistant,
    'conversations_v2': Phase007Feature.conversations,
  };
}
