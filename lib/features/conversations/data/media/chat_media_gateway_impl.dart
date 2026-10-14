import 'dart:ui' as ui;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/chat_media_gateway.dart';
import 'local_media.dart';

@visibleForTesting
Map<String, Uint8List> optimizeChatImage(Uint8List source) {
  final decoded = img.decodeImage(source);
  if (decoded == null) return {'image': source};
  var full = decoded;
  if (full.width > 1920 || full.height > 1920) {
    full = img.copyResize(
      full,
      width: full.width >= full.height ? 1920 : null,
      height: full.height > full.width ? 1920 : null,
      interpolation: img.Interpolation.linear,
    );
  }
  var quality = 80;
  var encoded = Uint8List.fromList(img.encodeJpg(full, quality: quality));
  while (encoded.length > 800 * 1024 && quality > 50) {
    quality -= 10;
    encoded = Uint8List.fromList(img.encodeJpg(full, quality: quality));
  }
  while (encoded.length > 800 * 1024 && full.width > 960 && full.height > 960) {
    full = img.copyResize(
      full,
      width: (full.width * .8).round(),
      height: (full.height * .8).round(),
      interpolation: img.Interpolation.linear,
    );
    encoded = Uint8List.fromList(img.encodeJpg(full, quality: 60));
  }
  var thumb = img.copyResize(
    decoded,
    width: decoded.width >= decoded.height ? 120 : null,
    height: decoded.height > decoded.width ? 120 : null,
    interpolation: img.Interpolation.linear,
  );
  var thumbQuality = 45;
  var thumbnail = Uint8List.fromList(
    img.encodeJpg(thumb, quality: thumbQuality),
  );
  while (thumbnail.length > 10 * 1024 && thumbQuality > 20) {
    thumbQuality -= 5;
    thumbnail = Uint8List.fromList(img.encodeJpg(thumb, quality: thumbQuality));
  }
  if (thumbnail.length > 10 * 1024) {
    thumb = img.copyResize(
      thumb,
      width: 80,
      interpolation: img.Interpolation.linear,
    );
    thumbnail = Uint8List.fromList(img.encodeJpg(thumb, quality: 25));
  }
  return {'image': encoded, 'thumbnail': thumbnail};
}

Future<ChatDraftFile> _imageDraft(
  String name,
  String mime,
  Uint8List bytes,
) async {
  try {
    final optimized = await compute(optimizeChatImage, bytes);
    final image = optimized['image'] ?? bytes;
    final thumbnail = optimized['thumbnail'];
    final stem = name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    return ChatDraftFile(
      fileName: '$stem.jpg',
      mimeType: 'image/jpeg',
      bytes: image,
      kind: 'image',
      thumbnailBase64:
          thumbnail == null
              ? null
              : 'data:image/jpeg;base64,${base64Encode(thumbnail)}',
    );
  } catch (_) {
    return ChatDraftFile(
      fileName: name,
      mimeType: mime,
      bytes: bytes,
      kind: 'image',
    );
  }
}

// ImagePicker already constrains gallery/camera images to 1280 px at 75%
// quality. Return that result immediately so the selected image appears in the
// composer without waiting for a second isolate decode/encode pass. The more
// expensive optimizer remains useful for unrestricted images chosen through
// the document picker.
ChatDraftFile _pickedImageDraft(String name, String mime, Uint8List bytes) {
  return ChatDraftFile(
    fileName: name,
    mimeType: mime,
    bytes: bytes,
    kind: 'image',
  );
}

class ChatMediaGatewayImpl implements ChatMediaGateway {
  @override
  Future<List<ChatDraftFile>> pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    final files = result?.files ?? [];
    if (files.length > 10) throw const ChatFailure('too_many_attachments');
    final output = <ChatDraftFile>[];
    for (final f in files) {
      if (f.bytes == null || f.bytes!.isEmpty || f.size > 25 * 1024 * 1024) {
        throw const ChatFailure('attachment_size');
      }
      final mime =
          lookupMimeType(f.name, headerBytes: f.bytes!.take(64).toList()) ??
          'application/octet-stream';
      output.add(
        mime.startsWith('image/')
            ? await _imageDraft(f.name, mime, f.bytes!)
            : ChatDraftFile(
              fileName: f.name,
              mimeType: mime,
              bytes: f.bytes!,
              kind: mime.split('/').first,
            ),
      );
    }
    return output;
  }

  @override
  Future<List<ChatDraftFile>> pickImages({bool fromCamera = false}) async {
    final picker = ImagePicker();
    if (fromCamera) {
      final file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (file == null) return [];
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return [];
      if (bytes.length > 25 * 1024 * 1024) {
        throw const ChatFailure('attachment_size');
      }
      final name =
          file.name.isNotEmpty
              ? file.name
              : 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final mime =
          file.mimeType ??
          lookupMimeType(name, headerBytes: bytes.take(64).toList()) ??
          'image/jpeg';
      return [_pickedImageDraft(name, mime, bytes)];
    } else {
      final files = await picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (files.isEmpty) return [];
      if (files.length > 10) throw const ChatFailure('too_many_attachments');
      final result = <ChatDraftFile>[];
      for (final f in files) {
        final bytes = await f.readAsBytes();
        if (bytes.isEmpty || bytes.length > 25 * 1024 * 1024) continue;
        final name =
            f.name.isNotEmpty
                ? f.name
                : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final mime =
            f.mimeType ??
            lookupMimeType(name, headerBytes: bytes.take(64).toList()) ??
            'image/jpeg';
        result.add(_pickedImageDraft(name, mime, bytes));
      }
      return result;
    }
  }

  @override
  Future<ChatDraftFile?> recordVideo() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      if (bytes.length > 25 * 1024 * 1024) {
        throw const ChatFailure('attachment_size');
      }
      final name =
          file.name.isNotEmpty
              ? file.name
              : 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final mime =
          file.mimeType ??
          lookupMimeType(name, headerBytes: bytes.take(64).toList()) ??
          'video/mp4';
      return ChatDraftFile(
        fileName: name,
        mimeType: mime,
        bytes: bytes,
        kind: 'video',
      );
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
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            file.bytes,
            mimeType: file.mimeType,
            name: file.fileName,
          ),
        ],
        fileNameOverrides: [file.fileName],
        sharePositionOrigin: ui.Rect.fromLTWH(x ?? 1, y ?? 1, 1, 1),
      ),
    );
  }

  @override
  Future<bool> copyImage(ChatDraftFile file) async {
    // The prior native image clipboard plug-in required Rust in the iOS
    // release environment and an obsolete Android Gradle configuration. The
    // attachment UI already presents save/share when this returns false.
    return false;
  }

  @override
  Future<String> localMediaUrl(ChatDraftFile file) =>
      createLocalMedia(file.bytes, file.fileName, file.mimeType);
  @override
  Future<void> release(String url) => releaseLocalMedia(url);
}
