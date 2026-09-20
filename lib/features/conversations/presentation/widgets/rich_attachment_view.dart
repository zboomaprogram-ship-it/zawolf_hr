import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../theme/theme.dart';
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
    this.isMine = false,
  });
  final RichAttachment attachment;
  final Future<ChatDraftFile> Function() download;
  final ChatMediaGateway gateway;
  final bool isMine;
  @override
  State<RichAttachmentView> createState() => _RichAttachmentViewState();
}

class _RichAttachmentViewState extends State<RichAttachmentView> {
  late final ChatMediaCubit _cubit = ChatMediaCubit(widget.download);
  bool get _available => widget.attachment.resourceId.trim().isNotEmpty;
  @override
  void initState() {
    super.initState();
    if (_available &&
        (widget.attachment.mimeType.startsWith('image/') ||
            widget.attachment.kind == 'voice')) {
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

  Widget _actions(ChatDraftFile file) {
    final iconColor =
        widget.isMine
            ? Colors.white
            : Theme.of(context).colorScheme.onSurfaceVariant;
    return Wrap(
      children: [
        IconButton(
          tooltip: 'حفظ المرفق',
          icon: Icon(Icons.download, color: iconColor),
          onPressed: () => _action(() => widget.gateway.save(file)),
        ),
        IconButton(
          tooltip: 'مشاركة',
          icon: Icon(Icons.share, color: iconColor),
          onPressed: () => _action(() => widget.gateway.share(file)),
        ),
      ],
    );
  }

  Widget _content(ChatDraftFile file) {
    final isVoice =
        widget.attachment.kind == 'voice' || file.mimeType.startsWith('audio/');
    if (file.mimeType.startsWith('image/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Image.memory(
              file.bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder:
                  (_, _, _) => const Text('تعذر عرض الصورة. يمكنك حفظها.'),
            ),
          ),
        ),
      );
    }
    if (file.mimeType.startsWith('audio/') ||
        file.mimeType.startsWith('video/')) {
      return ChatLocalPlayer(
        file: file,
        gateway: widget.gateway,
        video: file.mimeType.startsWith('video/'),
        isMine: widget.isMine,
        isVoice: isVoice,
      );
    }

    final cardBg =
        widget.isMine
            ? Colors.black.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.surfaceContainerHighest;
    final cardBorder =
        widget.isMine
            ? Border.all(color: Colors.black.withValues(alpha: 0.12))
            : null;
    final titleStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 13,
    );
    final subtitleStyle = TextStyle(
      color: ZaWolfColors.textSecondary,
      fontSize: 11,
    );

    if (file.mimeType == 'application/pdf') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              widget.isMine
                  ? Colors.black.withValues(alpha: 0.08)
                  : ZaWolfColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border:
              widget.isMine
                  ? Border.all(color: Colors.black.withValues(alpha: 0.15))
                  : Border.all(
                    color: ZaWolfColors.error.withValues(alpha: 0.3),
                  ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.picture_as_pdf,
              color: ZaWolfColors.error,
              size: 36,
            ),
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
                    style: titleStyle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(file.bytes.length / 1024).toStringAsFixed(1)} KB',
                    style: subtitleStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (file.mimeType == 'text/plain') {
      return Container(
        height: 160,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
          border: cardBorder,
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            utf8.decode(file.bytes.take(100000).toList(), allowMalformed: true),
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      );
    }
    final mime = file.mimeType;
    final spreadsheet =
        mime.contains('spreadsheet') ||
        mime.contains('excel') ||
        file.fileName.toLowerCase().endsWith('.xlsx');
    final document =
        mime.contains('wordprocessingml') ||
        mime.contains('msword') ||
        file.fileName.toLowerCase().endsWith('.docx');
    final archive =
        mime.contains('zip') || file.fileName.toLowerCase().endsWith('.zip');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: cardBorder,
      ),
      child: Row(
        children: [
          Icon(
            spreadsheet
                ? Icons.table_chart_outlined
                : document
                ? Icons.description_outlined
                : archive
                ? Icons.folder_zip_outlined
                : Icons.insert_drive_file_outlined,
            size: 36,
            color: widget.isMine ? const Color(0xFF166C8C) : null,
          ),
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
                  style: titleStyle,
                ),
                Text(
                  spreadsheet
                      ? 'جدول بيانات'
                      : document
                      ? 'مستند'
                      : archive
                      ? 'ملف مضغوط'
                      : 'ملف',
                  style: subtitleStyle,
                ),
                const Text('احفظ أو شارك لفتحه في التطبيق المناسب.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVoice =
        widget.attachment.kind == 'voice' ||
        widget.attachment.mimeType.startsWith('audio/');
    final isImage = widget.attachment.mimeType.startsWith('image/');
    final isMine = widget.isMine;
    final primaryTextColor = isMine ? const Color(0xFF0F172A) : Colors.white;
    final secondaryTextColor =
        isMine ? const Color(0xFF334155) : ZaWolfColors.textSecondary;

    return BlocBuilder<ChatMediaCubit, ChatMediaState>(
      bloc: _cubit,
      builder:
          (_, state) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isVoice && !isImage) ...[
                Text(
                  widget.attachment.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${(widget.attachment.sizeBytes / 1024).toStringAsFixed(0)} KB',
                  style: TextStyle(color: secondaryTextColor, fontSize: 11),
                ),
              ],
              if (state.loading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: LinearProgressIndicator(
                    color:
                        isMine
                            ? const Color(0xFF166C8C)
                            : ZaWolfColors.primaryCyan,
                    backgroundColor:
                        isMine
                            ? Colors.black.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              if (state.error != null)
                Text(
                  state.error!,
                  style: TextStyle(
                    color: isMine ? const Color(0xFF991B1B) : Colors.redAccent,
                    fontSize: 12,
                  ),
                ),
              if (!_available)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'جارٍ رفع المرفق…',
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
                )
              else if (state.file != null) ...[
                _content(state.file!),
                if (!isVoice && !isImage) _actions(state.file!),
              ] else if (!state.loading)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor:
                        isMine
                            ? const Color(0xFF0F172A)
                            : ZaWolfColors.primaryCyan,
                  ),
                  onPressed: _cubit.load,
                  icon: const Icon(Icons.download),
                  label: Text(
                    state.error == null
                        ? (isVoice
                            ? 'تشغيل الرسالة الصوتية'
                            : 'تحميل ومعاينة المرفق')
                        : 'إعادة المحاولة',
                  ),
                ),
            ],
          ),
    );
  }
}
