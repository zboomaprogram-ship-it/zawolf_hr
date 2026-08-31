import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/errors/errors.dart';
import 'company_workspace_remote_data_source.dart';

abstract interface class WorkspaceAccessAdminRemoteDataSource {
  Future<List<Map<String, Object?>>> listGrants(String resourceId);
  Future<String> createGrant(Map<String, Object?> grant);
  Future<void> revokeGrant(String grantId);
  Future<Map<String, Object?>> importCompanySource();
  Future<Map<String, Object?>> loadPilotConfiguration();
  Future<void> savePilotConfiguration(Map<String, Object?> configuration);
}

final class HttpWorkspaceAccessAdminRemoteDataSource
    implements WorkspaceAccessAdminRemoteDataSource {
  HttpWorkspaceAccessAdminRemoteDataSource({
    required http.Client client,
    required WorkspaceSession session,
    required Uri baseUri,
  }) : _client = client,
       _session = session,
       _baseUri = baseUri;

  final http.Client _client;
  final WorkspaceSession _session;
  final Uri _baseUri;

  Future<Map<String, String>> _headers() async {
    final token = await _session.refreshedBearerToken();
    if (token == null || token.isEmpty) {
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.fromHttpStatus(
          401,
          writeMayHaveStarted: false,
        ),
      );
    }
    return {'authorization': 'Bearer $token', 'accept': 'application/json'};
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final headers = await _headers();
    final request = http.Request(method, _baseUri.resolve(path))
      ..headers.addAll({
        ...headers,
        if (body != null) 'content-type': 'application/json',
      })
      ..body = body == null ? '' : jsonEncode(body);
    try {
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WorkspaceRemoteFailure(
          WorkspaceUserFacingError.fromHttpStatus(
            response.statusCode,
            writeMayHaveStarted: method != 'GET',
          ),
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException();
      return Map<String, Object?>.from(decoded);
    } on WorkspaceRemoteFailure {
      rethrow;
    } on Exception {
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.connectivity(
          writeMayHaveStarted: method != 'GET',
        ),
      );
    }
  }

  @override
  Future<List<Map<String, Object?>>> listGrants(String resourceId) async {
    final result = await _request(
      'GET',
      '/company-workspace/v2/access/grants?resourceId=$resourceId',
    );
    final grants = result['grants'];
    if (grants is! List) return const [];
    return grants
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList();
  }

  @override
  Future<String> createGrant(Map<String, Object?> grant) async =>
      ((await _request(
                'POST',
                '/company-workspace/v2/access/grants',
                body: grant,
              ))['grantId'] ??
              '')
          .toString();

  @override
  Future<void> revokeGrant(String grantId) async {
    await _request('DELETE', '/company-workspace/v2/access/grants/$grantId');
  }

  @override
  Future<Map<String, Object?>> importCompanySource() =>
      _request('POST', '/company-workspace/v2/access/import');

  @override
  Future<Map<String, Object?>> loadPilotConfiguration() =>
      _request('GET', '/company-workspace/v2/pilot');

  @override
  Future<void> savePilotConfiguration(
    Map<String, Object?> configuration,
  ) async {
    await _request('PUT', '/company-workspace/v2/pilot', body: configuration);
  }
}
