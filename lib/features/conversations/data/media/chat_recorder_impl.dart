import 'dart:async';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/chat_media_gateway.dart';
import 'chat_recorder_platform.dart';

class ChatRecorderImpl implements ChatRecorder {
  ChatRecorderImpl({ChatRecorder? delegate}) : _delegate = delegate ?? createPlatformRecorder();
  final ChatRecorder _delegate;

  @override
  Future<bool> start() => _delegate.start();

  @override
  Future<ChatDraftFile?> stop() => _delegate.stop();

  @override
  Future<void> cancel() => _delegate.cancel();

  @override
  Future<void> dispose() => _delegate.dispose();
}
