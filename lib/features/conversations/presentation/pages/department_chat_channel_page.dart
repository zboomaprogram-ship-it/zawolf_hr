import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../domain/entities/conversation.dart';
import '../../domain/entities/governed_attachment.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../../../../utils/binary_file_action.dart';
import '../../../../utils/user_facing_error.dart';

final class DepartmentChatChannelPage extends StatefulWidget {
  const DepartmentChatChannelPage({
    super.key,
    required this.channelId,
    required this.currentUserId,
    required this.repository,
    this.channelName,
    this.availableDepartments = const <String>[],
    this.selectedDepartment,
    this.onDepartmentSelected,
    this.onBack,
  });

  final String channelId;
  final String currentUserId;
  final ConversationRepository repository;
  final String? channelName;
  final List<String> availableDepartments;
  final String? selectedDepartment;
  final ValueChanged<String>? onDepartmentSelected;
  final VoidCallback? onBack;

  @override
  State<DepartmentChatChannelPage> createState() =>
      _DepartmentChatChannelPageState();
}

class _DepartmentChatChannelPageState extends State<DepartmentChatChannelPage> {
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;
  bool _uploading = false;
  double? _horizontalDragStart;
  final List<String> _attachmentResourceIds = <String>[];
  final List<ConversationMessage> _optimisticMessages = <ConversationMessage>[];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    widget.onBack?.call();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _attachmentResourceIds.isEmpty) return;

    final pendingId = 'optimistic-${DateTime.now().microsecondsSinceEpoch}';
    final pendingMessage = ConversationMessage(
      id: pendingId,
      conversationId: widget.channelId,
      senderUserId: widget.currentUserId,
      senderDisplayName: 'أنت',
      body: text.isEmpty ? 'مرفق' : text,
      sentAt: DateTime.now(),
      state: ConversationMessageState.pending,
      attachmentResourceIds: List<String>.from(_attachmentResourceIds),
    );

    final attachmentsToSend = List<String>.from(_attachmentResourceIds);
    _messageController.clear();
    setState(() {
      _attachmentResourceIds.clear();
      _optimisticMessages.add(pendingMessage);
      _sending = true;
    });

    try {
      final message = await widget.repository.sendMessage(
        conversationId: widget.channelId,
        senderUserId: widget.currentUserId,
        body: pendingMessage.body,
        operationId:
            'conversation-message-${DateTime.now().microsecondsSinceEpoch}',
        attachmentResourceIds: attachmentsToSend,
      );
      if (message.state == ConversationMessageState.failed) {
        throw StateError('message send failed');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر إرسال الرسالة.')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m.id == pendingId);
          _sending = false;
        });
      }
    }
  }

  Future<void> _attachFile() async {
    final repository = widget.repository;
    if (repository is! GovernedAttachmentGateway || _uploading) return;
    final gateway = repository as GovernedAttachmentGateway;
    final source = await showModalBottomSheet<_AttachmentSource>(
      context: context,
      builder:
          (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('صورة من المعرض'),
                  onTap:
                      () => Navigator.pop(
                        sheetContext,
                        _AttachmentSource.gallery,
                      ),
                ),
                ListTile(
                  leading: const Icon(Icons.attach_file_rounded),
                  title: const Text('ملف من الجهاز'),
                  onTap:
                      () =>
                          Navigator.pop(sheetContext, _AttachmentSource.files),
                ),
              ],
            ),
          ),
    );
    if (source == null) return;

    String? name;
    String? extension;
    List<int>? bytes;
    if (source == _AttachmentSource.gallery) {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 82,
      );
      name = image?.name;
      extension = name?.split('.').last;
      bytes = await image?.readAsBytes();
    } else {
      final selection = await FilePicker.pickFiles(
        allowMultiple: false,
        withData: true,
      );
      final file = selection?.files.singleOrNull;
      name = file?.name;
      extension = file?.extension;
      bytes = file?.bytes;
    }
    if (name == null || bytes == null || !mounted) return;
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حجم الملف يجب ألا يتجاوز 10 MB.')),
      );
      return;
    }
    setState(() => _uploading = true);
    try {
      final attachment = await gateway.upload(
        conversationId: widget.channelId,
        actorUserId: widget.currentUserId,
        fileName: name,
        mimeType: _mimeTypeFor(extension),
        bytes: bytes,
        operationId: 'chat-file-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (attachment.status != GovernedAttachmentStatus.uploaded) {
        throw StateError('upload_failed');
      }
      if (mounted) {
        setState(() => _attachmentResourceIds.add(attachment.resourceId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إرفاق $name عبر Google Drive.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                error,
                fallback: 'تعذر رفع الملف إلى Google Drive.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _mimeTypeFor(String? extension) => switch (extension?.toLowerCase()) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'txt' => 'text/plain',
    _ => 'application/octet-stream',
  };

  Future<void> _openAttachment(String resourceId) async {
    final repository = widget.repository;
    if (repository is! GovernedAttachmentGateway) return;
    final gateway = repository as GovernedAttachmentGateway;
    try {
      final file = await gateway.download(
        conversationId: widget.channelId,
        actorUserId: widget.currentUserId,
        resourceId: resourceId,
      );
      if (file.mimeType.startsWith('image/')) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder:
              (dialogContext) => Dialog(
                backgroundColor: const Color(0xFF0F172A),
                child: InteractiveViewer(
                  minScale: 0.6,
                  maxScale: 4,
                  child: Image.memory(
                    Uint8List.fromList(file.bytes),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
        );
        return;
      }
      final opened = await viewBinaryFile(
        file.bytes,
        file.fileName,
        file.mimeType,
        preparedView: prepareBinaryView(),
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الملف على هذا الجهاز.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تنزيل المرفق الآن.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.channelName ?? 'جروب المحادثة والتواصل';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF1E293B),
          leading: IconButton(
            tooltip: 'رجوع',
            icon: const Icon(
              Icons.arrow_forward_rounded,
              textDirection: TextDirection.ltr,
            ),
            onPressed: _goBack,
          ),
          title: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF38BDF8),
                radius: 16,
                child: Icon(Icons.tag_rounded, color: Colors.black, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16)),
              ),
              if (widget.availableDepartments.length > 1)
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: widget.selectedDepartment,
                    dropdownColor: const Color(0xFF1E293B),
                    iconEnabledColor: const Color(0xFF38BDF8),
                    style: const TextStyle(color: Colors.white),
                    items: widget.availableDepartments
                        .map(
                          (department) => DropdownMenuItem<String>(
                            value: department,
                            child: Text(department),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null && value != widget.selectedDepartment) {
                        widget.onDepartmentSelected?.call(value);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart:
              (details) => _horizontalDragStart = details.localPosition.dx,
          onHorizontalDragEnd: (details) {
            final start = _horizontalDragStart;
            _horizontalDragStart = null;
            final velocity = details.primaryVelocity ?? 0;
            final width = MediaQuery.sizeOf(context).width;
            final startedAtEdge =
                start != null && (start < 32 || start > width - 32);
            if (startedAtEdge && velocity.abs() >= 450) {
              _goBack();
            }
          },
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ConversationMessage>>(
                  stream: widget.repository.watchMessages(
                    conversationId: widget.channelId,
                    memberUserId: widget.currentUserId,
                  ),
                  builder: (context, snapshot) {
                    final remoteMessages = snapshot.data ?? const [];
                    final Map<String, ConversationMessage> mergedMap = {};
                    for (final m in remoteMessages) {
                      mergedMap[m.id] = m;
                    }
                    for (final m in _optimisticMessages) {
                      if (!mergedMap.containsKey(m.id)) {
                        mergedMap[m.id] = m;
                      }
                    }
                    final messages =
                        mergedMap.values.toList()
                          ..sort((a, b) => a.sentAt.compareTo(b.sentAt));

                    if (snapshot.connectionState == ConnectionState.waiting &&
                        remoteMessages.isEmpty &&
                        _optimisticMessages.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF38BDF8),
                        ),
                      );
                    }

                    if (snapshot.hasError && messages.isEmpty) {
                      return const Center(
                        child: Text(
                          'تعذر تحميل رسائل القسم. أعد فتح الجروب.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }
                    if (messages.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.forum_outlined,
                                size: 48,
                                color: Colors.white38,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'لا توجد رسائل في هذا الجروب بعد.\nابدأ المحادثة مع فريق العمل.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[messages.length - index - 1];
                        return _MessageBubble(
                          senderName:
                              message.senderDisplayName.isNotEmpty
                                  ? message.senderDisplayName
                                  : (message.senderUserId ==
                                          widget.currentUserId
                                      ? 'أنت'
                                      : 'عضو الفريق'),
                          body: message.body,
                          createdAt: message.sentAt.toIso8601String(),
                          isMe: message.senderUserId == widget.currentUserId,
                          attachmentResourceIds: message.attachmentResourceIds,
                          onAttachmentTap: _openAttachment,
                        );
                      },
                    );
                  },
                ),
              ),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          IconButton(
            icon:
                _uploading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(
                      Icons.attach_file_rounded,
                      color: Color(0xFF38BDF8),
                    ),
            tooltip: 'إرفاق ملف Google Drive',
            onPressed: _uploading ? null : _attachFile,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'اكتب رسالتك للروم...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF38BDF8),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon:
                  _sending
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                      : const Icon(
                        Icons.send_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
              onPressed: _sending ? null : _sendMessage,
            ),
          ),
          if (_attachmentResourceIds.isNotEmpty) ...[
            const SizedBox(width: 8),
            Chip(
              avatar: const Icon(Icons.attach_file, size: 16),
              label: Text('${_attachmentResourceIds.length}'),
              onDeleted: () => setState(_attachmentResourceIds.clear),
            ),
          ],
        ],
      ),
    );
  }
}

enum _AttachmentSource { gallery, files }

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.senderName,
    required this.body,
    required this.createdAt,
    required this.isMe,
    required this.attachmentResourceIds,
    required this.onAttachmentTap,
  });

  final String senderName;
  final String body;
  final String createdAt;
  final bool isMe;
  final List<String> attachmentResourceIds;
  final ValueChanged<String> onAttachmentTap;

  @override
  Widget build(BuildContext context) {
    final bg =
        isMe
            ? const Color(0xFF0284C7).withValues(alpha: 0.3)
            : const Color(0xFF334155);
    final border =
        isMe ? const Color(0xFF38BDF8).withValues(alpha: 0.5) : Colors.white12;

    String timeFormatted = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        timeFormatted = DateFormat('hh:mm a').format(dt);
      } catch (_) {}
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight:
                isMe ? const Radius.circular(2) : const Radius.circular(16),
            bottomLeft:
                !isMe ? const Radius.circular(2) : const Radius.circular(16),
          ),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.start : CrossAxisAlignment.start,
          children: [
            if (!isMe && senderName.isNotEmpty) ...[
              Text(
                senderName,
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              body,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            if (attachmentResourceIds.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (
                    var index = 0;
                    index < attachmentResourceIds.length;
                    index++
                  )
                    ActionChip(
                      avatar: const Icon(Icons.attach_file, size: 14),
                      label: Text('فتح المرفق ${index + 1}'),
                      onPressed:
                          () => onAttachmentTap(attachmentResourceIds[index]),
                    ),
                ],
              ),
            ],
            if (timeFormatted.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  timeFormatted,
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
