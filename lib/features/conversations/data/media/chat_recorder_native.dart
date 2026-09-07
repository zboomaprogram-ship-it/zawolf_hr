import 'dart:async';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/chat_media_gateway.dart';

ChatRecorder createPlatformRecorder() => NativeChatRecorder();

class NativeChatRecorder implements ChatRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _subscription;
  final _bytes = BytesBuilder(copy: false);
  Timer? _limit;
  bool _recording = false;
  Object? _error;
  Future<ChatDraftFile?>? _stopping;
  ChatDraftFile? _completed;
  static const maxPcmBytes = 16000 * 2 * 300;

  @override
  Future<bool> start() async {
    if (_recording) return true;
    try {
      if (!await _recorder.hasPermission()) return false;
    } catch (_) {
      return false;
    }
    _bytes.clear();
    _error = null;
    _completed = null;
    _stopping = null;
    try {
      final stream = await _recorder.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1),
      );
      _recording = true;
      _subscription = stream.listen((chunk) {
        final room = maxPcmBytes - _bytes.length;
        if (room > 0) _bytes.add(chunk.length <= room ? chunk : Uint8List.sublistView(chunk, 0, room));
        if (_bytes.length >= maxPcmBytes) unawaited(stop());
      }, onError: (Object e) {
        _error = e;
        unawaited(stop());
      });
      _limit = Timer(const Duration(seconds: 300), () => unawaited(stop()));
      return true;
    } catch (_) {
      try {
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
          path: '',
        );
        _recording = true;
        _limit = Timer(const Duration(seconds: 300), () => unawaited(stop()));
        return true;
      } catch (_) {
        _recording = false;
        return false;
      }
    }
  }

  @override
  Future<ChatDraftFile?> stop() => _stopping ??= _finish();

  Future<ChatDraftFile?> _finish() async {
    if (!_recording) return _completed;
    _recording = false;
    _limit?.cancel();
    final hadSubscription = _subscription != null;
    final path = await _recorder.stop();
    await _subscription?.cancel();
    _subscription = null;
    if (_error != null) throw const ChatFailure('recording_failed');
    if (hadSubscription) {
      final bytes = _bytes.takeBytes();
      if (bytes.length < 2) return null;
      final aligned = Uint8List.sublistView(bytes, 0, bytes.length - bytes.length % 2);
      return _completed = ChatDraftFile(
        fileName: 'voice-${DateTime.now().millisecondsSinceEpoch}.wav',
        mimeType: 'audio/wav',
        kind: 'voice',
        bytes: pcmWave(aligned),
        durationSeconds: aligned.length / 32000,
      );
    } else if (path != null && path.isNotEmpty) {
      final file = XFile(path);
      final bytes = await file.readAsBytes();
      if (bytes.length < 2) return null;
      return _completed = ChatDraftFile(
        fileName: 'voice-${DateTime.now().millisecondsSinceEpoch}.wav',
        mimeType: 'audio/wav',
        kind: 'voice',
        bytes: bytes,
        durationSeconds: bytes.length / 32000,
      );
    }
    return null;
  }

  @override
  Future<void> cancel() async {
    await stop();
    _bytes.clear();
    _completed = null;
  }

  @override
  Future<void> dispose() async {
    _limit?.cancel();
    await _subscription?.cancel();
    await _recorder.dispose();
  }
}
