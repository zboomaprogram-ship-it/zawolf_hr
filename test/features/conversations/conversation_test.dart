import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/conversations/domain/entities/conversation.dart';
import 'package:zawolf_hr/features/conversations/domain/entities/governed_attachment.dart';

void main() {
  test(
    'conversation membership is explicit and role claims are not inferred',
    () {
      const conversation = Conversation(
        id: 'conversation-1',
        memberUserIds: {'employee-1', 'manager-1'},
        purposeAr: 'متابعة العمل',
        state: ConversationState.active,
      );

      expect(conversation.includes('employee-1'), isTrue);
      expect(conversation.includes('employee-2'), isFalse);
    },
  );

  test('governed attachments expose opaque references only', () {
    const safe = GovernedAttachment(
      resourceId: 'chat-resource-1',
      mimeType: 'application/pdf',
      sizeBytes: 120,
      status: GovernedAttachmentStatus.uploaded,
    );
    const unsafe = GovernedAttachment(
      resourceId: 'https://drive.google.com/file/secret',
      mimeType: 'application/pdf',
      sizeBytes: 120,
      status: GovernedAttachmentStatus.uploaded,
    );

    expect(safe.hasOpaqueReference, isTrue);
    expect(unsafe.hasOpaqueReference, isFalse);
  });
}
