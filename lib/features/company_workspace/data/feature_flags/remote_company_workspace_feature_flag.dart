import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/feature_flags/company_workspace_feature_flag.dart';
import '../datasources/company_workspace_remote_data_source.dart';

/// Fail-closed remote switch. A timeout, unauthenticated session, or malformed
/// response can never turn Workspace V2 on.
final class RemoteCompanyWorkspaceFeatureFlag extends ChangeNotifier
    implements CompanyWorkspaceFeatureFlag {
  RemoteCompanyWorkspaceFeatureFlag({
    required http.Client client,
    required WorkspaceSession session,
    required Uri baseUri,
  }) : _client = client,
       _session = session,
       _baseUri = baseUri;

  final http.Client _client;
  final WorkspaceSession _session;
  final Uri _baseUri;
  bool _enabled = false;

  @override
  Listenable get changes => this;

  @override
  bool isEnabledFor({required String actorId}) =>
      _enabled && actorId.isNotEmpty;

  Future<void> refresh() async {
    try {
      final token = await _session.refreshedBearerToken();
      if (token == null || token.isEmpty) return _setEnabled(false);
      final response = await _client
          .get(
            _baseUri.resolve('/company-workspace/v2/pilot'),
            headers: {
              'authorization': 'Bearer $token',
              'accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 12));
      final decoded = jsonDecode(response.body);
      _setEnabled(
        response.statusCode == 200 &&
            decoded is Map &&
            decoded['enabled'] == true,
      );
    } on Object {
      _setEnabled(false);
    }
  }

  void _setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
  }
}
