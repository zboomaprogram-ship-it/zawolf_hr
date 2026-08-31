import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Uploads legacy employee-request evidence through the governed Drive
/// boundary. Drive ids never reach the employee request document.
final class GovernedDriveAttachmentService {
  GovernedDriveAttachmentService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<GovernedDriveAttachment> upload({
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) async {
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw ArgumentError('حجم الملف غير صالح');
    }
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null || token.isEmpty) throw StateError('انتهت جلسة الدخول');
    final operationId =
        'legacy-request-file-${DateTime.now().microsecondsSinceEpoch}';
    final response = await _client.post(
      Uri.parse(
        'https://notification.zawolf.ai/company-os/requests/attachments',
      ),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
        'x-operation-id': operationId,
      },
      body: jsonEncode({
        'operationId': operationId,
        'displayName': fileName,
        'contentType': contentType,
        'contentsBase64': base64Encode(bytes),
      }),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map ||
        decoded['ok'] != true ||
        decoded['data'] is! Map) {
      throw StateError('تعذر حفظ المرفق في ملفات الشركة');
    }
    final data = Map<String, dynamic>.from(decoded['data'] as Map);
    final id = '${data['id'] ?? ''}'.trim();
    if (id.isEmpty) throw StateError('تعذر حفظ المرفق في ملفات الشركة');
    return GovernedDriveAttachment(
      opaqueUri: 'drive-request://$id',
      displayName: '${data['displayName'] ?? fileName}',
    );
  }
}

final class GovernedDriveAttachment {
  const GovernedDriveAttachment({
    required this.opaqueUri,
    required this.displayName,
  });

  final String opaqueUri;
  final String displayName;
}
