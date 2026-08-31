import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/errors/errors.dart';
import 'company_workspace_remote_data_source.dart';

abstract interface class WorkspaceReportsRemoteDataSource {
  Future<String> request({
    required String path,
    required Map<String, Object?> body,
  });
}

final class HttpWorkspaceReportsRemoteDataSource
    implements WorkspaceReportsRemoteDataSource {
  const HttpWorkspaceReportsRemoteDataSource({
    required http.Client client,
    required WorkspaceSession session,
    required Uri baseUri,
  }) : _client = client,
       _session = session,
       _baseUri = baseUri;

  final http.Client _client;
  final WorkspaceSession _session;
  final Uri _baseUri;

  @override
  Future<String> request({
    required String path,
    required Map<String, Object?> body,
  }) async {
    final token = await _session.refreshedBearerToken();
    if (token == null || token.isEmpty) {
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.fromHttpStatus(
          401,
          writeMayHaveStarted: false,
        ),
      );
    }
    try {
      final response = await _client.post(
        _baseUri.resolve(path),
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
          'authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WorkspaceRemoteFailure(
          WorkspaceUserFacingError.fromHttpStatus(
            response.statusCode,
            writeMayHaveStarted: true,
          ),
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException();
      }
      final resource = decoded['resource'];
      if (resource is Map && resource['id'] is String) {
        return resource['id'] as String;
      }
      throw const FormatException();
    } on WorkspaceRemoteFailure {
      rethrow;
    } on http.ClientException {
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.connectivity(writeMayHaveStarted: true),
      );
    } on FormatException {
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.fromHttpStatus(502, writeMayHaveStarted: true),
      );
    }
  }
}
