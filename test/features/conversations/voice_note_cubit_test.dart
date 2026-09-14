import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/conversations/domain/entities/rich_chat.dart';
import 'package:zawolf_hr/features/conversations/domain/repositories/chat_media_gateway.dart';
import 'package:zawolf_hr/features/conversations/presentation/cubit/voice_note_cubit.dart';

class _DelayedRecorder implements ChatRecorder {
  final stopped = Completer<ChatDraftFile?>();
  int stopCalls = 0;

  @override
  Future<bool> start() async => true;

  @override
  Future<ChatDraftFile?> stop() {
    stopCalls++;
    return stopped.future;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  test('concurrent stop requests finalize one voice recording', () async {
    final recorder = _DelayedRecorder();
    final cubit = VoiceNoteCubit(recorder);
    await cubit.start();

    final first = cubit.stop();
    final second = cubit.stop();

    expect(recorder.stopCalls, 1);
    recorder.stopped.complete(
      ChatDraftFile(
        fileName: 'voice.wav',
        mimeType: 'audio/wav',
        kind: 'voice',
        bytes: Uint8List.fromList([1, 2]),
        durationSeconds: 1,
      ),
    );
    await Future.wait([first, second]);

    expect(cubit.state.file?.fileName, 'voice.wav');
    await cubit.close();
  });
}
