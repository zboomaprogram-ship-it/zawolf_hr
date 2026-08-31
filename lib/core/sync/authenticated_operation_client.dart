import 'dart:convert';

import 'package:http/http.dart' as http;

/// A small authenticated client for idempotent Hostinger operations.
///
/// Callers own their Firebase session provider, so this shared client does not
/// depend on Firebase and can be tested with a fake token provider.
final class AuthenticatedOperationClient {
  AuthenticatedOperationClient({
    required http.Client client,
    required Future<String?> Function() tokenProvider,
  }) : _client = client,
       _tokenProvider = tokenProvider;

  final http.Client _client;
  final Future<String?> Function() _tokenProvider;

  Future<AuthenticatedOperationResponse> post(
    Uri uri, {
    required String operationId,
    Map<String, Object?> body = const {},
  }) async {
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'must not be empty',
      );
    }
    final token = await _tokenProvider();
    if (token == null || token.trim().isEmpty) {
      return const AuthenticatedOperationResponse(
        statusCode: 401,
        ok: false,
        safeCode: 'session_expired',
      );
    }
    try {
      final response = await _client.post(
        uri,
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $token',
          'x-operation-id': operationId.trim(),
        },
        body: jsonEncode({...body, 'operationId': operationId.trim()}),
      );
      final decoded = _safeJson(response.body);
      return AuthenticatedOperationResponse(
        statusCode: response.statusCode,
        ok:
            decoded['ok'] == true &&
            response.statusCode >= 200 &&
            response.statusCode < 300,
        safeCode: _safeCode(decoded['code'] ?? decoded['safeCode']),
        data: decoded,
      );
    } on http.ClientException {
      return const AuthenticatedOperationResponse(
        statusCode: 0,
        ok: false,
        safeCode: 'connection_interrupted',
      );
    }
  }

  Future<AuthenticatedOperationResponse> get(Uri uri) =>
      _send(method: 'GET', uri: uri);

  Future<AuthenticatedOperationResponse> delete(Uri uri) =>
      _send(method: 'DELETE', uri: uri);

  Future<AuthenticatedBinaryResponse> download(Uri uri) async {
    final token = await _tokenProvider();
    if (token == null || token.trim().isEmpty) {
      return const AuthenticatedBinaryResponse(
        statusCode: 401,
        bytes: <int>[],
        fileName: 'download',
        mimeType: 'application/octet-stream',
      );
    }
    try {
      final response = await _client.get(
        uri,
        headers: {'authorization': 'Bearer $token'},
      );
      final disposition = response.headers['content-disposition'] ?? '';
      final encodedName = RegExp(
        r"filename\*=UTF-8''([^;]+)",
      ).firstMatch(disposition)?.group(1);
      return AuthenticatedBinaryResponse(
        statusCode: response.statusCode,
        bytes: response.bodyBytes,
        fileName: encodedName == null
            ? 'download'
            : Uri.decodeComponent(encodedName),
        mimeType:
            response.headers['content-type'] ?? 'application/octet-stream',
      );
    } on http.ClientException {
      return const AuthenticatedBinaryResponse(
        statusCode: 0,
        bytes: <int>[],
        fileName: 'download',
        mimeType: 'application/octet-stream',
      );
    }
  }

  Future<AuthenticatedOperationResponse> _send({
    required String method,
    required Uri uri,
  }) async {
    final token = await _tokenProvider();
    if (token == null || token.trim().isEmpty) {
      return const AuthenticatedOperationResponse(
        statusCode: 401,
        ok: false,
        safeCode: 'session_expired',
      );
    }
    try {
      final request = http.Request(method, uri)
        ..headers.addAll({'authorization': 'Bearer $token'});
      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);
      final decoded = _safeJson(response.body);
      return AuthenticatedOperationResponse(
        statusCode: response.statusCode,
        ok:
            decoded['ok'] == true &&
            response.statusCode >= 200 &&
            response.statusCode < 300,
        safeCode: _safeCode(decoded['code'] ?? decoded['safeCode']),
        data: decoded,
      );
    } on http.ClientException {
      return const AuthenticatedOperationResponse(
        statusCode: 0,
        ok: false,
        safeCode: 'connection_interrupted',
      );
    }
  }

  static Map<String, Object?> _safeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic>
          ? Map<String, Object?>.from(decoded)
          : const {};
    } catch (_) {
      return const {};
    }
  }

  static String _safeCode(Object? value) {
    final code = (value?.toString() ?? 'unexpected').toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_-]'),
      '_',
    );
    return code.isEmpty
        ? 'unexpected'
        : code.substring(0, code.length > 64 ? 64 : code.length);
  }
}

final class AuthenticatedBinaryResponse {
  const AuthenticatedBinaryResponse({
    required this.statusCode,
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final int statusCode;
  final List<int> bytes;
  final String fileName;
  final String mimeType;

  bool get ok => statusCode >= 200 && statusCode < 300 && bytes.isNotEmpty;
}

final class AuthenticatedOperationResponse {
  const AuthenticatedOperationResponse({
    required this.statusCode,
    required this.ok,
    required this.safeCode,
    this.data = const {},
  });

  final int statusCode;
  final bool ok;
  final String safeCode;
  final Map<String, Object?> data;
}
