enum GovernedAttachmentStatus { pending, uploaded, failed, deleted }

final class GovernedAttachmentFile {
  const GovernedAttachmentFile({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final List<int> bytes;
  final String fileName;
  final String mimeType;
}

final class GovernedAttachment {
  const GovernedAttachment({
    required this.resourceId,
    required this.mimeType,
    required this.sizeBytes,
    required this.status,
  });

  final String resourceId;
  final String mimeType;
  final int sizeBytes;
  final GovernedAttachmentStatus status;

  bool get hasOpaqueReference =>
      resourceId.isNotEmpty &&
      !resourceId.startsWith('http://') &&
      !resourceId.startsWith('https://');
}
