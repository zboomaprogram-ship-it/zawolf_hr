import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/errors/workspace_user_facing_error.dart';
import '../../domain/entities/workspace_capability.dart';
import '../../domain/entities/workspace_resource.dart';
import 'company_workspace_remote_data_source.dart';

abstract interface class WorkspaceResourceRemoteDataSource {
  Future<WorkspaceResourcePage> listAccessible({
    required String? parentId,
    String? pageToken,
  });

  Future<WorkspaceDownloadedFile> download(String resourceId);
}

final class HttpWorkspaceResourceRemoteDataSource
    implements WorkspaceResourceRemoteDataSource {
  HttpWorkspaceResourceRemoteDataSource({
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
  Future<WorkspaceResourcePage> listAccessible({
    required String? parentId,
    String? pageToken,
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
    final query = <String, String>{
      if (parentId != null) 'parentId': parentId,
      if (pageToken != null) 'pageToken': pageToken,
    };
    try {
      final response = await _client
          .get(
            _baseUri
                .resolve('/company-workspace/v2/resources')
                .replace(queryParameters: query),
            headers: {
              'authorization': 'Bearer $token',
              'accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WorkspaceRemoteFailure(
          WorkspaceUserFacingError.fromHttpStatus(
            response.statusCode,
            writeMayHaveStarted: false,
          ),
        );
      }
      final body = jsonDecode(response.body);
      if (body is! Map || body['resources'] is! List) {
        throw const FormatException('Invalid workspace resource page');
      }
      return WorkspaceResourcePage(
        resources: (body['resources'] as List)
            .whereType<Map>()
            .map((item) => _resource(Map<String, Object?>.from(item)))
            .toList(growable: false),
        nextPageToken: body['nextPageToken'] as String?,
      );
    } on WorkspaceRemoteFailure {
      rethrow;
    } on TimeoutException {
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.fromHttpStatus(
          503,
          writeMayHaveStarted: false,
        ),
      );
    } on http.ClientException {
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.fromHttpStatus(
          503,
          writeMayHaveStarted: false,
        ),
      );
    } on FormatException {
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.fromHttpStatus(
          503,
          writeMayHaveStarted: false,
        ),
      );
    }
  }

  @override
  Future<WorkspaceDownloadedFile> download(String resourceId) async {
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
      final response = await _client
          .get(
            _baseUri.resolve(
              '/company-workspace/v2/resources/${Uri.encodeComponent(resourceId)}/content',
            ),
            headers: {'authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WorkspaceRemoteFailure(
          WorkspaceUserFacingError.fromHttpStatus(
            response.statusCode,
            writeMayHaveStarted: false,
          ),
        );
      }
      final disposition = response.headers['content-disposition'] ?? '';
      final match = RegExp(r'filename="?([^";]+)').firstMatch(disposition);
      final fileName = match?.group(1)?.trim();
      return WorkspaceDownloadedFile(
        bytes: response.bodyBytes,
        fileName: (fileName == null || fileName.isEmpty)
            ? 'company-file'
            : fileName,
        mimeType:
            response.headers['content-type'] ?? 'application/octet-stream',
      );
    } on WorkspaceRemoteFailure {
      rethrow;
    } on TimeoutException {
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.fromHttpStatus(
          503,
          writeMayHaveStarted: false,
        ),
      );
    } on http.ClientException {
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.fromHttpStatus(
          503,
          writeMayHaveStarted: false,
        ),
      );
    }
  }

  WorkspaceResource _resource(Map<String, Object?> json) => WorkspaceResource(
    id: _string(json, 'id'),
    name: _string(json, 'name'),
    type: WorkspaceResourceType.values.byName(_string(json, 'type')),
    parentId: json['parentId'] as String?,
    version: _string(json, 'version'),
    capabilities: (json['capabilities'] as List? ?? const [])
        .whereType<String>()
        .map(WorkspaceCapability.values.byName)
        .toSet(),
  );

  String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw const FormatException('Missing field');
    }
    return value;
  }
}
