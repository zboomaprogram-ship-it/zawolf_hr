import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:share_plus/share_plus.dart';
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
  Future<List<ChatDraftFile>> pickImages({bool fromCamera = false}) async {
    final picker = ImagePicker();
    if (fromCamera) {
      final file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (file == null) return [];
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return [];
      if (bytes.length > 25 * 1024 * 1024) throw const ChatFailure('attachment_size');
      final name = file.name.isNotEmpty ? file.name : 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final mime = file.mimeType ?? lookupMimeType(name, headerBytes: bytes.take(64).toList()) ?? 'image/jpeg';
      return [ChatDraftFile(fileName: name, mimeType: mime, bytes: bytes, kind: 'image')];
    } else {
      final files = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (files.isEmpty) return [];
      if (files.length > 10) throw const ChatFailure('too_many_attachments');
      final result = <ChatDraftFile>[];
      for (final f in files) {
        final bytes = await f.readAsBytes();
        if (bytes.isEmpty || bytes.length > 25 * 1024 * 1024) continue;
        final name = f.name.isNotEmpty ? f.name : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final mime = f.mimeType ?? lookupMimeType(name, headerBytes: bytes.take(64).toList()) ?? 'image/jpeg';
        result.add(ChatDraftFile(fileName: name, mimeType: mime, bytes: bytes, kind: 'image'));
      }
      return result;
    }
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
    // The prior native image clipboard plug-in required Rust in the iOS
    // release environment and an obsolete Android Gradle configuration. The
    // attachment UI already presents save/share when this returns false.
    return false;
  }
  @override
  Future<String> localMediaUrl(ChatDraftFile file) => createLocalMedia(file.bytes, file.fileName, file.mimeType);
  @override
  Future<void> release(String url) => releaseLocalMedia(url);
}
