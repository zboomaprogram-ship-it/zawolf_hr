import 'dart:convert';

import '../../domain/entities/company_os_attachment_reference.dart';
import '../../domain/repositories/company_os_attachment_repository.dart';
import '../remote/company_os_api_client.dart';

/// Uploads request evidence through the governed Company OS gateway.  Drive
/// identifiers never reach the app; the gateway returns only an opaque id.
final class DriveCompanyOsAttachmentRepository
    implements CompanyOsAttachmentRepository {
  DriveCompanyOsAttachmentRepository(this._api);

  final CompanyOsApiClient _api;

  @override
  Future<CompanyOsAttachmentReference> upload({
    required String ownerUid,
    required String displayName,
    required String contentType,
    required List<int> bytes,
  }) async {
    final response = await _api.postObject(
      '/requests/attachments',
      operationId:
          'request-attachment-${DateTime.now().microsecondsSinceEpoch}',
      payload: {
        'displayName': displayName,
        'contentType': contentType,
        'contentsBase64': base64Encode(bytes),
      },
    );
    final raw = response['data'];
    if (raw is! Map) throw StateError('Unexpected attachment response');
    final item = Map<String, Object?>.from(raw);
    final id = '${item['id'] ?? ''}'.trim();
    if (id.isEmpty) throw StateError('Missing attachment id');
    return CompanyOsAttachmentReference(
      id: id,
      displayName: '${item['displayName'] ?? displayName}',
      contentType: '${item['contentType'] ?? contentType}',
      sizeBytes: item['sizeBytes'] is int
          ? item['sizeBytes'] as int
          : int.tryParse('${item['sizeBytes']}') ?? bytes.length,
    );
  }

  @override
  Future<List<int>> download(String attachmentId) {
    throw UnsupportedError('Request attachment download is not available yet.');
  }
}
