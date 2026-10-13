import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/conversations/domain/entities/rich_chat.dart';
import 'package:zawolf_hr/features/conversations/domain/repositories/rich_chat_repository.dart';
import 'package:zawolf_hr/features/conversations/presentation/cubit/chat_composer_cubit.dart';

class _Repository implements RichChatRepository {
  int saves = 0;
  String savedBody = '';
  List<ChatDraftFile> savedFiles = const [];

  @override
  String get actorId => 'employee';

  @override
  Future<({String body, List<ChatDraftFile> files, String? replyToMessageId})>
  loadDraft(String channelId) async => (
    body: '',
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
    saves++;
    savedBody = body;
    savedFiles = files;
  }

  @override
  Future<void> typing(String channelId, bool typing) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('typing is immediate while draft persistence is debounced', () async {
    final repository = _Repository();
    final cubit = ChatComposerCubit(repository, 'channel');
    await Future<void>.delayed(Duration.zero);

    for (var i = 0; i < 50; i++) {
      cubit.changeBody('message $i');
    }
    expect(cubit.state.body, 'message 49');
    expect(repository.saves, 0);

    await Future<void>.delayed(const Duration(milliseconds: 950));
    expect(repository.saves, 1);
    expect(repository.savedBody, 'message 49');
    await cubit.close();
  });

  test(
    'adding a file persists immediately and later typing reuses it',
    () async {
      final repository = _Repository();
      final cubit = ChatComposerCubit(repository, 'channel');
      await Future<void>.delayed(Duration.zero);
      final file = ChatDraftFile(
        fileName: 'a.txt',
        mimeType: 'text/plain',
        bytes: Uint8List.fromList([1, 2]),
      );

      await cubit.addFiles([file]);
      expect(repository.saves, 1);
      cubit.changeBody('body');
      await Future<void>.delayed(const Duration(milliseconds: 950));

      expect(repository.saves, 2);
      expect(repository.savedFiles.single, same(file));
      await cubit.close();
    },
  );
}
