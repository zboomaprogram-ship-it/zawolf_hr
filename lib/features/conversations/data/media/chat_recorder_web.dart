import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/chat_media_gateway.dart';

ChatRecorder createPlatformRecorder() => WebChatRecorder();

class WebChatRecorder implements ChatRecorder {
  web.MediaStream? _stream;
  web.MediaRecorder? _recorder;
  final List<web.Blob> _chunks = [];
  Timer? _limit;
  bool _recording = false;
  Completer<void>? _stopCompleter;
  DateTime? _startTime;
  ChatDraftFile? _completed;

  @override
  Future<bool> start() async {
    if (_recording) return true;
    _completed = null;
    _chunks.clear();
    _stopCompleter = null;

    try {
      final mediaDevices = web.window.navigator.mediaDevices;
      final stream = await mediaDevices.getUserMedia(
        web.MediaStreamConstraints(audio: true.toJS),
      ).toDart;
      _stream = stream;

      String mimeType = 'audio/webm;codecs=opus';
      if (!web.MediaRecorder.isTypeSupported(mimeType)) {
        mimeType = 'audio/webm';
        if (!web.MediaRecorder.isTypeSupported(mimeType)) {
          mimeType = 'audio/mp4';
          if (!web.MediaRecorder.isTypeSupported(mimeType)) {
            mimeType = '';
          }
        }
      }

      final recorder = mimeType.isNotEmpty
          ? web.MediaRecorder(stream, web.MediaRecorderOptions(mimeType: mimeType))
          : web.MediaRecorder(stream);
      _recorder = recorder;

      recorder.ondataavailable = ((web.BlobEvent event) {
        if (event.data.size > 0) {
          _chunks.add(event.data);
        }
      }).toJS;

      recorder.onstop = ((web.Event _) {
        if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
          _stopCompleter!.complete();
        }
      }).toJS;

      recorder.onerror = ((web.Event _) {
        if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
          _stopCompleter!.complete();
        }
      }).toJS;

      recorder.start(250);
      _recording = true;
      _startTime = DateTime.now();
      _limit = Timer(const Duration(seconds: 300), () => unawaited(stop()));
      return true;
    } catch (_) {
      _recording = false;
      _cleanupStream();
      return false;
    }
  }

  @override
  Future<ChatDraftFile?> stop() async {
    if (!_recording && _completed != null) return _completed;
    if (!_recording || _recorder == null) return null;

    _recording = false;
    _limit?.cancel();

    final completer = Completer<void>();
    _stopCompleter = completer;

    if (_recorder!.state != 'inactive') {
      try {
        _recorder!.requestData();
      } catch (_) {}
      try {
        _recorder!.stop();
      } catch (_) {}
    } else {
      completer.complete();
    }

    try {
      await completer.future.timeout(const Duration(seconds: 2));
    } catch (_) {}

    _cleanupStream();

    if (_chunks.isEmpty) return null;

    try {
      final recordedMime = _recorder!.mimeType.isNotEmpty
          ? _recorder!.mimeType
          : 'audio/webm';
      final parts = <web.BlobPart>[for (final c in _chunks) c].toJS;
      final combinedBlob = web.Blob(parts, web.BlobPropertyBag(type: recordedMime));
      final buffer = await combinedBlob.arrayBuffer().toDart;
      final bytes = buffer.toDart.asUint8List();

      if (bytes.length < 2) return null;

      final elapsed = _startTime != null
          ? DateTime.now().difference(_startTime!).inMilliseconds / 1000.0
          : 0.0;
      final cleanMime = recordedMime.split(';').first.trim();
      final ext = cleanMime.contains('mp4')
          ? 'mp4'
          : (cleanMime.contains('ogg') ? 'ogg' : 'webm');

      return _completed = ChatDraftFile(
        fileName: 'voice-${DateTime.now().millisecondsSinceEpoch}.$ext',
        mimeType: cleanMime,
        kind: 'voice',
        bytes: bytes,
        durationSeconds: elapsed > 0 ? elapsed : 1.0,
      );
    } catch (_) {
      return null;
    }
  }

  void _cleanupStream() {
    if (_stream != null) {
      try {
        final tracks = _stream!.getTracks().toDart;
        for (final track in tracks) {
          track.stop();
        }
      } catch (_) {}
      _stream = null;
    }
  }

  @override
  Future<void> cancel() async {
    _recording = false;
    _limit?.cancel();
    if (_recorder != null && _recorder!.state != 'inactive') {
      try {
        _recorder!.stop();
      } catch (_) {}
    }
    _cleanupStream();
    _chunks.clear();
    _completed = null;
  }

  @override
  Future<void> dispose() async {
    await cancel();
  }
}
