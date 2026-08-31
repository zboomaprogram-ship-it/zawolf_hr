import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../domain/entities/conversation.dart';
import '../../domain/entities/governed_attachment.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../../../../utils/binary_file_action.dart';

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
  });

  final String channelId;
  final String currentUserId;
  final ConversationRepository repository;
  final String? channelName;
  final List<String> availableDepartments;
  final String? selectedDepartment;
  final ValueChanged<String>? onDepartmentSelected;

  @override
  State<DepartmentChatChannelPage> createState() =>
      _DepartmentChatChannelPageState();
}

class _DepartmentChatChannelPageState extends State<DepartmentChatChannelPage> {
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;
  bool _uploading = false;
  final List<String> _attachmentResourceIds = <String>[];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _attachmentResourceIds.isEmpty) return;

    setState(() => _sending = true);
    try {
      final message = await widget.repository.sendMessage(
        conversationId: widget.channelId,
        senderUserId: widget.currentUserId,
        body: text.isEmpty ? 'مرفق' : text,
        operationId:
            'conversation-message-${DateTime.now().microsecondsSinceEpoch}',
        attachmentResourceIds: List<String>.from(_attachmentResourceIds),
      );
      if (message.state == ConversationMessageState.failed) {
        throw StateError('message send failed');
      }

      _messageController.clear();
      setState(() => _attachmentResourceIds.clear());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر إرسال الرسالة.')));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _attachFile() async {
    final repository = widget.repository;
    if (repository is! GovernedAttachmentGateway || _uploading) return;
    final gateway = repository as GovernedAttachmentGateway;
    final selection = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: true,
    );
    final file = selection?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) return;
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
        fileName: file.name,
        mimeType: _mimeTypeFor(file.extension),
        bytes: bytes,
        operationId: 'chat-file-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (attachment.status != GovernedAttachmentStatus.uploaded) {
        throw StateError('upload_failed');
      }
      if (mounted) {
        setState(() => _attachmentResourceIds.add(attachment.resourceId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إرفاق ${file.name} عبر Google Drive.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر رفع الملف إلى Google Drive.')),
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

  Future<void> _downloadAttachment(String resourceId) async {
    final repository = widget.repository;
    if (repository is! GovernedAttachmentGateway) return;
    final gateway = repository as GovernedAttachmentGateway;
    final preparedView = prepareBinaryView();
    try {
      final file = await gateway.download(
        conversationId: widget.channelId,
        actorUserId: widget.currentUserId,
        resourceId: resourceId,
      );
      final opened = await viewBinaryFile(
        file.bytes,
        file.fileName,
        file.mimeType,
        preparedView: preparedView,
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
    final title = widget.channelName ?? 'قناة المحادثة والتواصل';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
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
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<ConversationMessage>>(
                stream: widget.repository.watchMessages(
                  conversationId: widget.channelId,
                  memberUserId: widget.currentUserId,
                ),
                builder: (context, snapshot) {
                  final messages = snapshot.data ?? const [];
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'تعذر تحميل رسائل القسم. أعد فتح القناة.',
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
                              'لا توجد رسائل في هذه القناة بعد.\nابدأ المحادثة مع فريق العمل.',
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
                        senderName: message.senderDisplayName,
                        body: message.body,
                        createdAt: message.sentAt.toIso8601String(),
                        isMe: message.senderUserId == widget.currentUserId,
                        attachmentResourceIds: message.attachmentResourceIds,
                        onAttachmentTap: _downloadAttachment,
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
            icon: _uploading
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
              icon: _sending
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
    final bg = isMe
        ? const Color(0xFF0284C7).withValues(alpha: 0.3)
        : const Color(0xFF334155);
    final border = isMe
        ? const Color(0xFF38BDF8).withValues(alpha: 0.5)
        : Colors.white12;

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
            bottomRight: isMe
                ? const Radius.circular(2)
                : const Radius.circular(16),
            bottomLeft: !isMe
                ? const Radius.circular(2)
                : const Radius.circular(16),
          ),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.start,
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
                      onPressed: () =>
                          onAttachmentTap(attachmentResourceIds[index]),
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
