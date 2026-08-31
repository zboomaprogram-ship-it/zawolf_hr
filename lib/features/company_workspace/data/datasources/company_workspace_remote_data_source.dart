import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/errors/errors.dart';
import '../models/workspace_operation_dto.dart';

abstract interface class WorkspaceSession {
  /// Must force refresh where the identity provider supports it.
  Future<String?> refreshedBearerToken();
}

abstract interface class CompanyWorkspaceRemoteDataSource {
  Future<WorkspaceOperationReceiptDto> submitOperation(
    WorkspaceOperationDto operation,
  );
}

final class HttpCompanyWorkspaceRemoteDataSource
    implements CompanyWorkspaceRemoteDataSource {
  HttpCompanyWorkspaceRemoteDataSource({
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
  Future<WorkspaceOperationReceiptDto> submitOperation(
    WorkspaceOperationDto operation,
  ) async {
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
          .post(
            _baseUri.resolve('/company-workspace/v2/operations'),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
              'accept': 'application/json',
              // The server uses this as its idempotency key and correlation ID.
              'x-workspace-operation-id': operation.operationId,
            },
            body: jsonEncode(operation.toJson()),
          )
          .timeout(const Duration(seconds: 20));
      final status = response.statusCode;
      if (status < 200 || status >= 300) {
        throw WorkspaceRemoteFailure(
          WorkspaceUserFacingError.fromHttpStatus(
            status,
            writeMayHaveStarted: true,
          ),
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw WorkspaceRemoteFailure(
          WorkspaceUserFacingError.fromHttpStatus(
            502,
            writeMayHaveStarted: true,
          ),
        );
      }
      return WorkspaceOperationReceiptDto.fromJson(
        Map<String, Object?>.from(decoded),
      );
    } on WorkspaceRemoteFailure {
      rethrow;
    } on TimeoutException {
      throw WorkspaceRemoteFailure(
        WorkspaceUserFacingError.connectivity(writeMayHaveStarted: true),
      );
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

/// Only structured, presentation-safe failures cross the data boundary.
final class WorkspaceRemoteFailure implements Exception {
  const WorkspaceRemoteFailure(this.failure);

  final AppFailure failure;
}
