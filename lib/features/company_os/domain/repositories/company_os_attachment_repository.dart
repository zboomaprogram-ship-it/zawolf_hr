import '../entities/company_os_attachment_reference.dart';

abstract interface class CompanyOsAttachmentRepository {
  Future<CompanyOsAttachmentReference> upload({
    required String ownerUid,
    required String displayName,
    required String contentType,
    required List<int> bytes,
  });

  Future<List<int>> download(String attachmentId);
}
