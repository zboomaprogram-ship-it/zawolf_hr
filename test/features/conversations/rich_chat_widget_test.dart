import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/conversations/domain/entities/rich_chat.dart';
import 'package:zawolf_hr/features/conversations/domain/repositories/rich_chat_repository.dart';
import 'package:zawolf_hr/features/conversations/presentation/pages/rich_chat_page.dart';

class FakeRichChatRepository implements RichChatRepository {
  final snapshots = StreamController<RichChatSnapshot>.broadcast();
  final seen = <String>[];
  String draft = '';
  bool failSend = false;
  int sends = 0;
  final channelMembers = const [
    ChatUser(
      id: 'colleague',
      name: 'زميلة الاختبار',
      department: 'Data Analytics',
    ),
  ];
  @override
  String get actorId => 'me';
  @override
  Stream<RichChatSnapshot> watchChannel(String channelId) => snapshots.stream;
  @override
  Future<({String body, List<ChatDraftFile> files, String? replyToMessageId})>
  loadDraft(String channelId) async => (
    body: draft,
    files: <ChatDraftFile>[],
    replyToMessageId: null,
  );
  @override
  Future<void> saveDraft(
    String channelId,
    String body,
    List<ChatDraftFile> files, {
    String? replyToMessageId,
  }) async {
    draft = body;
  }

  @override
  Future<void> send(
    String channelId, {
    required String body,
    List<ChatDraftFile> files = const [],
    String? replyToMessageId,
  }) async {
    sends++;
    if (failSend) throw const ChatFailure('storage_full');
  }

  @override
  Future<void> markRead(String channelId, String messageId) async {
    seen.add(messageId);
  }

  @override
  Future<void> typing(String channelId, bool typing) async {}
  @override
  Future<ChatPage<ChatUser>> members(String channelId) async =>
      ChatPage(channelMembers);
  @override
  void setForeground(bool foreground) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'failed durable enqueue keeps composer text and exposes retryable error',
    (tester) async {
      final repository = FakeRichChatRepository()..failSend = true;
      await tester.pumpWidget(
        MaterialApp(
          home: RichChatPage(
            repository: repository,
            channel: const RichChannel(
              id: 'c',
              name: 'فريق العمل',
              canPost: true,
            ),
            canReview: false,
            attachmentBuilder: (_, attachment) => Text(attachment.fileName),
            pickAttachments: (_) async => [],
            voiceBuilder: (_, callback) => const SizedBox.shrink(),
          ),
        ),
      );
      repository.snapshots.add(const RichChatSnapshot(canPost: true));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('chat-composer')),
        'رسالة محفوظة',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      expect(repository.sends, 1);
      expect(find.text('رسالة محفوظة'), findsOneWidget);
      expect(find.textContaining('المساحة'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      await repository.snapshots.close();
    },
  );

  testWidgets('a foreground visible received message is marked seen', (
    tester,
  ) async {
    final repository = FakeRichChatRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: RichChatPage(
          repository: repository,
          channel: const RichChannel(id: 'c', name: 'القناة', canPost: true),
          canReview: false,
          attachmentBuilder: (_, attachment) => Text(attachment.fileName),
          pickAttachments: (_) async => [],
          voiceBuilder: (_, callback) => const SizedBox.shrink(),
        ),
      ),
    );
    repository.snapshots.add(
      RichChatSnapshot(
        canPost: true,
        messages: [
          RichMessage(
            id: 'm',
            conversationId: 'c',
            senderUserId: 'other',
            body: 'أهلاً',
            sentAt: DateTime.now(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.seen, contains('m'));
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.snapshots.close();
  });

  testWidgets(
    'department channel info displays all department employees instead of 0 members',
    (tester) async {
      final repository = FakeRichChatRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: RichChatPage(
            repository: repository,
            channel: const RichChannel(
              id: 'c',
              name: 'قناة قسم HR',
              kind: 'department',
              memberUserIds: [],
              canPost: true,
            ),
            canReview: true,
            attachmentBuilder: (_, attachment) => Text(attachment.fileName),
            pickAttachments: (_) async => [],
            voiceBuilder: (_, callback) => const SizedBox.shrink(),
          ),
        ),
      );
      repository.snapshots.add(const RichChatSnapshot(canPost: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('معلومات الجروب'));
      await tester.pumpAndSettle();
      expect(find.textContaining('جميع موظفي القسم'), findsOneWidget);
      expect(find.textContaining('0 عضو'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await repository.snapshots.close();
    },
  );

  testWidgets(
    'members button uses a compatible people icon and lists authorized members',
    (tester) async {
      final repository = FakeRichChatRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: RichChatPage(
            repository: repository,
            channel: const RichChannel(
              id: 'c',
              name: 'قناة القسم',
              kind: 'department',
              canPost: true,
            ),
            canReview: false,
            attachmentBuilder: (_, attachment) => Text(attachment.fileName),
            pickAttachments: (_) async => [],
            voiceBuilder: (_, callback) => const SizedBox.shrink(),
          ),
        ),
      );
      repository.snapshots.add(const RichChatSnapshot(canPost: true));
      await tester.pumpAndSettle();
      expect(find.byTooltip('أعضاء الجروب'), findsOneWidget);
      await tester.tap(find.byTooltip('أعضاء الجروب'));
      await tester.pumpAndSettle();
      expect(find.text('زميلة الاختبار'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await repository.snapshots.close();
    },
  );

  testWidgets(
    'composer has attachment and voice options without camera video record button',
    (tester) async {
      final repository = FakeRichChatRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: RichChatPage(
            repository: repository,
            channel: const RichChannel(id: 'c', name: 'القناة', canPost: true),
            canReview: false,
            attachmentBuilder: (_, attachment) => Text(attachment.fileName),
            pickAttachments: (_) async => [],
            voiceBuilder: (_, callback) => const Text('voice-button'),
          ),
        ),
      );
      repository.snapshots.add(const RichChatSnapshot(canPost: true));
      await tester.pumpAndSettle();
      expect(find.byTooltip('إرفاق صور أو فيديو أو ملف'), findsOneWidget);
      expect(find.text('voice-button'), findsOneWidget);
      expect(find.byTooltip('تسجيل فيديو بالكاميرا'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await repository.snapshots.close();
    },
  );
}
