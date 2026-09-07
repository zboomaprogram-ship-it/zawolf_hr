import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../domain/entities/rich_chat.dart';
import 'chat_codec.dart';

class ChatTransport {
  ChatTransport({
    required this.client,
    required this.tokenProvider,
    required this.baseUri,
  });
  final http.Client client;
  final Future<String?> Function() tokenProvider;
  final Uri baseUri;
  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    Uint8List? bytes,
    Map<String, String> headers = const {},
  }) async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw const ChatFailure('session_expired');
    }
    final request = http.Request(
      method,
      baseUri.resolve('/conversations/v2$path'),
    );
    request.headers.addAll({'authorization': 'Bearer $token', ...headers});
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (bytes != null) {
      request.headers['content-type'] = 'application/octet-stream';
      request.bodyBytes = bytes;
    }
    try {
      final response = await http.Response.fromStream(
        await client.send(request),
      ).timeout(const Duration(seconds: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        Map<String, Object?> data = {};
        try {
          data = objectMap(jsonDecode(response.body));
        } catch (_) {}
        throw ChatFailure('${data['code'] ?? 'http_${response.statusCode}'}');
      }
      return response;
    } on ChatFailure {
      rethrow;
    } catch (_) {
      throw const ChatFailure('connection_interrupted');
    }
  }

  Future<Map<String, Object?>> json(
    String method,
    String path, {
    Map<String, Object?>? body,
    Uint8List? bytes,
    Map<String, String> headers = const {},
  }) async {
    final response = await _request(
      method,
      path,
      body: body,
      bytes: bytes,
      headers: headers,
    );
    final data = objectMap(jsonDecode(response.body));
    if (data['ok'] != true) {
      throw ChatFailure('${data['code'] ?? 'invalid_response'}');
    }
    return data;
  }

  Future<ChatDraftFile> download(String path) async {
    final response = await _request('GET', path);
    final name = RegExp(
      r"filename\*=UTF-8''([^;]+)",
    ).firstMatch(response.headers['content-disposition'] ?? '')?.group(1);
    return ChatDraftFile(
      fileName: name == null ? 'attachment' : Uri.decodeComponent(name),
      mimeType: response.headers['content-type'] ?? 'application/octet-stream',
      bytes: response.bodyBytes,
    );
  }
}
