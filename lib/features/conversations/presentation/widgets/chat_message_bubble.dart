import 'package:flutter/material.dart';
import '../../domain/entities/rich_chat.dart';
import 'chat_feedback.dart';
import 'chat_stickers.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.seen,
    required this.attachmentBuilder,
    required this.onActions,
    required this.onRetry,
    this.reply,
  });
  final RichMessage message;
  final RichMessage? reply;
  final bool mine, seen;
  final Widget Function(BuildContext, RichAttachment) attachmentBuilder;
  final VoidCallback onActions, onRetry;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = TimeOfDay.fromDateTime(
      message.sentAt.toLocal(),
    ).format(context);
    final pending = message.syncState == ChatSyncState.pending;
    final failed =
        message.syncState == ChatSyncState.failed ||
        message.syncState == ChatSyncState.conflict;
    final reactions = <String, int>{};
    for (final emoji in message.reactions.values) {
      reactions[emoji] = (reactions[emoji] ?? 0) + 1;
    }
    final bubbleColor =
        mine ? const Color(0xFF80DEEA) : scheme.surfaceContainerLow;
    final textColor = mine ? Colors.black : Colors.white;
    final senderColor = mine ? const Color(0xFF0F3E48) : scheme.primary;
    final metaColor = mine ? const Color(0xFF1E293B) : scheme.onSurfaceVariant;
    final actionIconColor =
        mine ? const Color(0xFF0F3E48) : scheme.onSurfaceVariant;
    final errorColor = mine ? const Color(0xFFB91C1C) : scheme.error;

    return Align(
      alignment:
          mine
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Material(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onLongPress: onActions,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              mine
                                  ? 'أنت'
                                  : (message.senderDisplayName.isEmpty
                                      ? message.senderUserId
                                      : message.senderDisplayName),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: senderColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'خيارات الرسالة',
                            onPressed: onActions,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.more_horiz,
                              size: 20,
                              color: actionIconColor,
                            ),
                          ),
                        ],
                      ),
                      if (message.forwarded)
                        Text(
                          'رسالة معاد توجيهها',
                          style: TextStyle(fontSize: 12, color: metaColor),
                        ),
                      if (message.replyToMessageId != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color:
                                mine
                                    ? Colors.black.withValues(alpha: 0.06)
                                    : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                            border: BorderDirectional(
                              start: BorderSide(color: senderColor, width: 3),
                            ),
                          ),
                          child: Text(
                            reply?.isDeleted == true
                                ? 'تم حذف الرسالة الأصلية'
                                : reply?.body.isNotEmpty == true
                                ? reply!.body
                                : 'رد على رسالة',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: mine ? Colors.black87 : Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      if (message.isDeleted)
                        Text(
                          'تم حذف هذه الرسالة',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: metaColor,
                          ),
                        )
                      else ...[
                        if (message.stickerId != null)
                          Text(
                            chatStickers[message.stickerId] ?? '❔',
                            style: const TextStyle(fontSize: 56),
                          ),
                        if (message.body.isNotEmpty)
                          SelectableText(
                            message.body,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              height: 1.35,
                            ),
                          ),
                        for (final attachment in message.attachments)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: attachmentBuilder(context, attachment),
                          ),
                        if (message.attachmentResourceIds.isNotEmpty &&
                            message.attachments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'جارٍ تحميل بيانات الملفات…',
                              style: TextStyle(color: metaColor),
                            ),
                          ),
                      ],
                      if (pending)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(),
                        ),
                      if (failed)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                chatErrorText(message.errorCode ?? 'failed'),
                                style: TextStyle(
                                  color: errorColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: errorColor,
                              ),
                              onPressed: onRetry,
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      if (reactions.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          children:
                              reactions.entries
                                  .map(
                                    (entry) => Chip(
                                      label: Text(
                                        '${entry.key} ${entry.value}',
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  )
                                  .toList(),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 11,
                              color: metaColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (message.editedAt != null)
                            Text(
                              ' · معدّلة',
                              style: TextStyle(
                                fontSize: 11,
                                color: metaColor,
                              ),
                            ),
                          if (mine) ...[
                            const SizedBox(width: 6),
                            Icon(
                              pending
                                  ? Icons.schedule
                                  : failed
                                  ? Icons.error_outline
                                  : seen
                                  ? Icons.done_all
                                  : Icons.done,
                              size: 16,
                              color: failed ? errorColor : senderColor,
                            ),
                            Text(
                              pending
                                  ? ' قيد الإرسال'
                                  : failed
                                  ? ' تعذر الإرسال'
                                  : seen
                                  ? ' تمت المشاهدة'
                                  : ' أُرسلت',
                              style: TextStyle(
                                fontSize: 11,
                                color: failed ? errorColor : metaColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
