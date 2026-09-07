import 'dart:typed_data';
import '../entities/rich_chat.dart';

abstract interface class ChatMediaGateway {
  Future<List<ChatDraftFile>> pickFiles();
  Future<ChatDraftFile?> recordVideo();
  Future<void> save(ChatDraftFile file);
  Future<void> share(ChatDraftFile file, {double? x, double? y});
  Future<bool> copyImage(ChatDraftFile file);
  Future<String> localMediaUrl(ChatDraftFile file);
  Future<void> release(String url);
}

abstract interface class ChatRecorder {
  Future<bool> start();
  Future<ChatDraftFile?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

Uint8List pcmWave(Uint8List pcm, {int sampleRate = 16000}) {
  final result = Uint8List(44 + pcm.length);
  final data = ByteData.sublistView(result);
  void ascii(int offset, String value) =>
      result.setRange(offset, offset + value.length, value.codeUnits);
  ascii(0, 'RIFF');
  data.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, pcm.length, Endian.little);
  result.setRange(44, result.length, pcm);
  return result;
}
