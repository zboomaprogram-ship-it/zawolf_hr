import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/chat_media_gateway.dart';
import '../cubit/chat_media_cubit.dart';
import 'chat_local_player.dart';

class RichAttachmentView extends StatefulWidget {
  const RichAttachmentView({
    super.key,
    required this.attachment,
    required this.download,
    required this.gateway,
  });
  final RichAttachment attachment;
  final Future<ChatDraftFile> Function() download;
  final ChatMediaGateway gateway;
  @override
  State<RichAttachmentView> createState() => _RichAttachmentViewState();
}

class _RichAttachmentViewState extends State<RichAttachmentView> {
  late final ChatMediaCubit _cubit = ChatMediaCubit(widget.download);
  bool get _available => widget.attachment.resourceId.trim().isNotEmpty;
  @override
  void initState() {
    super.initState();
    if (_available && widget.attachment.mimeType.startsWith('image/')) {
      _cubit.load();
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _action(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تنفيذ الإجراء. جرّب الحفظ أو المشاركة.'),
          ),
        );
      }
    }
  }

  Widget _actions(ChatDraftFile file) => Wrap(
    children: [
      IconButton(
        tooltip: 'حفظ المرفق',
        icon: const Icon(Icons.download),
        onPressed: () => _action(() => widget.gateway.save(file)),
      ),
      IconButton(
        tooltip: 'مشاركة',
        icon: const Icon(Icons.share),
        onPressed: () => _action(() => widget.gateway.share(file)),
      ),
      if (file.mimeType.startsWith('image/'))
        IconButton(
          tooltip: 'نسخ الصورة',
          icon: const Icon(Icons.copy),
          onPressed:
              () => _action(() async {
                final copied = await widget.gateway.copyImage(file);
                if (!copied) throw StateError('clipboard_unavailable');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ الصورة.')),
                  );
                }
              }),
        ),
    ],
  );
  Widget _content(ChatDraftFile file) {
    if (file.mimeType.startsWith('image/')) {
      return InkWell(
        onTap:
            () => showDialog<void>(
              context: context,
              builder:
                  (_) => Dialog.fullscreen(
                    child: Scaffold(
                      appBar: AppBar(
                        title: Text(file.fileName),
                        actions: [_actions(file)],
                      ),
                      body: Center(
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 8,
                          child: Image.memory(
                            file.bytes,
                            fit: BoxFit.contain,
                            errorBuilder:
                                (_, _, _) => const Text('الصورة غير مدعومة'),
                          ),
                        ),
                      ),
                    ),
                  ),
            ),
        child: Image.memory(
          file.bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder:
              (_, _, _) => const Text('تعذر عرض الصورة. يمكنك حفظها.'),
        ),
      );
    }
    if (file.mimeType.startsWith('audio/') ||
        file.mimeType.startsWith('video/')) {
      return ChatLocalPlayer(
        file: file,
        gateway: widget.gateway,
        video: file.mimeType.startsWith('video/'),
      );
    }
    if (file.mimeType == 'application/pdf') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withAlpha(60)),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    file.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(file.bytes.length / 1024).toStringAsFixed(1)} KB',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (file.mimeType == 'text/plain') {
      return SizedBox(
        height: 180,
        child: SingleChildScrollView(
          child: SelectableText(
            utf8.decode(file.bytes.take(100000).toList(), allowMalformed: true),
          ),
        ),
      );
    }
    return const Text(
      'استخدم الحفظ أو المشاركة لفتح الملف في التطبيق المناسب.',
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ChatMediaCubit, ChatMediaState>(
    bloc: _cubit,
    builder:
        (_, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.attachment.fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${(widget.attachment.sizeBytes / 1024).toStringAsFixed(0)} KB',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (state.loading) const LinearProgressIndicator(),
            if (state.error != null) Text(state.error!),
            if (!_available)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('جارٍ رفع المرفق…'),
              )
            else if (state.file != null) ...[
              _content(state.file!),
              _actions(state.file!),
            ] else if (!state.loading)
              TextButton.icon(
                onPressed: _cubit.load,
                icon: const Icon(Icons.download),
                label: Text(
                  state.error == null
                      ? 'تحميل ومعاينة المرفق'
                      : 'إعادة المحاولة',
                ),
              ),
          ],
        ),
  );
}
