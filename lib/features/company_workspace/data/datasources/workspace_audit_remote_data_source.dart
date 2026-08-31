import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/errors/errors.dart';
import '../models/workspace_audit_event_dto.dart';
import 'company_workspace_remote_data_source.dart';

abstract interface class WorkspaceAuditRemoteDataSource {
  Future<List<WorkspaceAuditEventDto>> listEvents({
    required DateTime startsOn,
    required DateTime endsOn,
    required int limit,
  });
}

final class HttpWorkspaceAuditRemoteDataSource
    implements WorkspaceAuditRemoteDataSource {
  const HttpWorkspaceAuditRemoteDataSource({
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
  Future<List<WorkspaceAuditEventDto>> listEvents({
    required DateTime startsOn,
    required DateTime endsOn,
    required int limit,
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
    String date(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    try {
      final uri = _baseUri
          .resolve('/company-workspace/v2/audit')
          .replace(
            queryParameters: {
              'startDate': date(startsOn),
              'endDate': date(endsOn),
              'limit': limit.clamp(1, 200).toString(),
            },
          );
      final response = await _client.get(
        uri,
        headers: {
          'accept': 'application/json',
          'authorization': 'Bearer $token',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WorkspaceRemoteFailure(
          WorkspaceUserFacingError.fromHttpStatus(
            response.statusCode,
            writeMayHaveStarted: false,
          ),
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['events'] is! List) {
        throw const FormatException();
      }
      return (decoded['events'] as List)
          .whereType<Map>()
          .map(
            (event) => WorkspaceAuditEventDto.fromJson(
              Map<String, Object?>.from(event),
            ),
          )
          .toList(growable: false);
    } on WorkspaceRemoteFailure {
      rethrow;
    } on http.ClientException {
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.connectivity(writeMayHaveStarted: false),
      );
    } on FormatException {
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.fromHttpStatus(
          502,
          writeMayHaveStarted: false,
        ),
      );
    }
  }
}
