import '../../domain/entities/company_os_attachment_reference.dart';
import '../../domain/repositories/company_os_attachment_repository.dart';

typedef LegacyAttachmentUploader =
    Future<CompanyOsAttachmentReference> Function({
      required String ownerUid,
      required String displayName,
      required String contentType,
      required List<int> bytes,
    });
typedef LegacyAttachmentDownloader = Future<List<int>> Function(String id);

/// Optional adapter around the existing attachment flow. Company OS remains
/// usable when this adapter is not registered and does not import Phase 006.
final class LegacyCompanyOsAttachmentRepository
    implements CompanyOsAttachmentRepository {
  LegacyCompanyOsAttachmentRepository({
    required LegacyAttachmentUploader uploadAttachment,
    required LegacyAttachmentDownloader downloadAttachment,
  }) : _uploadAttachment = uploadAttachment,
       _downloadAttachment = downloadAttachment;

  final LegacyAttachmentUploader _uploadAttachment;
  final LegacyAttachmentDownloader _downloadAttachment;

  @override
  Future<List<int>> download(String attachmentId) =>
      _downloadAttachment(attachmentId);

  @override
  Future<CompanyOsAttachmentReference> upload({
    required String ownerUid,
    required String displayName,
    required String contentType,
    required List<int> bytes,
  }) => _uploadAttachment(
    ownerUid: ownerUid,
    displayName: displayName,
    contentType: contentType,
    bytes: bytes,
  );
}
