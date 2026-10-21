// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import '../../domain/entities/rich_chat.dart';

class ChatWebPasteListener {
  final void Function(ChatDraftFile file) onImagePasted;
  final bool Function() isEnabled;

  StreamSubscription<html.ClipboardEvent>? _subscription;

  ChatWebPasteListener({
    required this.onImagePasted,
    required this.isEnabled,
  });

  void attach() {
    _subscription?.cancel();
    _subscription = html.document.onPaste.listen(_handlePaste);
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _handlePaste(html.ClipboardEvent event) {
    if (!isEnabled()) return;

    final clipboardData = event.clipboardData;
    if (clipboardData == null) return;

    // 1. Check items (DataTransferItemList)
    final items = clipboardData.items;
    if (items != null) {
      final count = items.length ?? 0;
      for (var i = 0; i < count; i++) {
        final item = items[i];
        final type = item.type ?? '';
        if (type.startsWith('image/')) {
          final file = item.getAsFile();
          if (file != null) {
            event.preventDefault();
            _readFile(file, type);
            return;
          }
        }
      }
    }

    // 2. Fallback to files (FileList)
    final files = clipboardData.files;
    if (files != null && files.isNotEmpty) {
      for (final file in files) {
        if (file.type.startsWith('image/')) {
          event.preventDefault();
          _readFile(file, file.type);
          return;
        }
      }
    }
  }

  void _readFile(html.File file, String mimeType) {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result == null) return;

      Uint8List bytes;
      if (result is Uint8List) {
        bytes = result;
      } else if (result is ByteBuffer) {
        bytes = Uint8List.view(result);
      } else {
        bytes = Uint8List.fromList((result as dynamic) as List<int>);
      }

      if (bytes.isEmpty) return;

      final rawExt = mimeType.split('/').last.toLowerCase();
      final ext = rawExt == 'jpeg' ? 'jpg' : rawExt;
      final fileName = file.name.isNotEmpty
          ? file.name
          : 'pasted_image_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final draftFile = ChatDraftFile(
        fileName: fileName,
        mimeType: mimeType,
        kind: 'image',
        bytes: bytes,
      );

      onImagePasted(draftFile);
    });
  }
}
