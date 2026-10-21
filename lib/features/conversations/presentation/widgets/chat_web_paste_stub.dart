import '../../domain/entities/rich_chat.dart';

class ChatWebPasteListener {
  final void Function(ChatDraftFile file) onImagePasted;
  final bool Function() isEnabled;

  ChatWebPasteListener({
    required this.onImagePasted,
    required this.isEnabled,
  });

  void attach() {}
  void dispose() {}
}
