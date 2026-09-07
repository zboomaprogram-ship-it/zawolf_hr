import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:share_plus/share_plus.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/chat_media_gateway.dart';
import 'local_media.dart';

class ChatMediaGatewayImpl implements ChatMediaGateway {
  @override
  Future<List<ChatDraftFile>> pickFiles() async {
    final result = await FilePicker.pickFiles(allowMultiple: true, withData: true);
    final files = result?.files ?? [];
    if (files.length > 10) throw const ChatFailure('too_many_attachments');
    return files.map((f) {
      if (f.bytes == null || f.bytes!.isEmpty || f.size > 25 * 1024 * 1024) throw const ChatFailure('attachment_size');
      final mime = lookupMimeType(f.name, headerBytes: f.bytes!.take(64).toList()) ?? 'application/octet-stream';
      return ChatDraftFile(fileName: f.name, mimeType: mime, bytes: f.bytes!, kind: mime.split('/').first);
    }).toList();
  }
  @override
  Future<ChatDraftFile?> recordVideo() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 5));
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      if (bytes.length > 25 * 1024 * 1024) throw const ChatFailure('attachment_size');
      final name = file.name.isNotEmpty ? file.name : 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final mime = file.mimeType ?? lookupMimeType(name, headerBytes: bytes.take(64).toList()) ?? 'video/mp4';
      return ChatDraftFile(fileName: name, mimeType: mime, bytes: bytes, kind: 'video');
    } catch (e) {
      if (e is ChatFailure) rethrow;
      return null;
    }
  }
  @override
  Future<void> save(ChatDraftFile file) async {
    await FilePicker.saveFile(fileName: file.fileName, bytes: file.bytes);
  }
  @override
  Future<void> share(ChatDraftFile file, {double? x, double? y}) async {
    await SharePlus.instance.share(ShareParams(files: [XFile.fromData(file.bytes, mimeType: file.mimeType, name: file.fileName)],
      fileNameOverrides: [file.fileName], sharePositionOrigin: ui.Rect.fromLTWH(x ?? 1, y ?? 1, 1, 1)));
  }
  @override
  Future<bool> copyImage(ChatDraftFile file) async {
    try {
      final codec = await ui.instantiateImageCodec(file.bytes);
      final frame = await codec.getNextFrame();
      try {
        final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) return false;
        final item = DataWriterItem()..add(Formats.png(png.buffer.asUint8List()));
        await ClipboardWriter.instance.write([item]);
        return true;
      } finally {
        frame.image.dispose();
        codec.dispose();
      }
    } catch (_) {
      return false;
    }
  }
  @override
  Future<String> localMediaUrl(ChatDraftFile file) => createLocalMedia(file.bytes, file.fileName, file.mimeType);
  @override
  Future<void> release(String url) => releaseLocalMedia(url);
}
