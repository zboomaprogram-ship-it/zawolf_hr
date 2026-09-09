import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/rich_chat.dart';

class ChatLinkPreviewView extends StatelessWidget {
  const ChatLinkPreviewView({super.key, required this.preview});
  final ChatLinkPreview preview;
  static Future<void> open(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.link),
      title: Text(preview.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(Uri.tryParse(preview.url)?.host ?? '', maxLines: 1),
      onTap: () => open(preview.url),
    ),
  );
}
