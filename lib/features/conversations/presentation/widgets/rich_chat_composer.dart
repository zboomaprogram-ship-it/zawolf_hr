import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../cubit/chat_composer_cubit.dart';
import 'chat_feedback.dart';
import 'chat_stickers.dart';

class RichChatComposer extends StatefulWidget {
  const RichChatComposer({
    super.key,
    required this.cubit,
    required this.pickAttachments,
    required this.voiceBuilder,
  });
  final ChatComposerCubit cubit;
  final Future<List<ChatDraftFile>> Function(BuildContext) pickAttachments;
  final Widget Function(BuildContext, Future<void> Function(ChatDraftFile))
  voiceBuilder;
  @override
  State<RichChatComposer> createState() => _RichChatComposerState();
}

class _RichChatComposerState extends State<RichChatComposer> {
  late final TextEditingController _text;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.cubit.state.body);
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ChatComposerCubit, ChatComposerState>(
    bloc: widget.cubit,
    listenWhen: (a, b) => a.revision != b.revision,
    listener: (context, state) {
      _text.text = state.body;
    },
    builder:
        (context, state) => SafeArea(
          top: false,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.error != null)
                    ChatFeedback(text: chatErrorText(state.error!)),
                  if (state.reply != null)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.reply),
                      title: Text('رد على ${state.reply!.senderDisplayName}'),
                      subtitle: Text(
                        state.reply!.body.isEmpty ? 'ملف' : state.reply!.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: 'إلغاء الرد',
                        onPressed:
                            state.sending
                                ? null
                                : () => widget.cubit.replyTo(null),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  if (state.files.isNotEmpty)
                    SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (var i = 0; i < state.files.length; i++)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 6),
                              child: InputChip(
                                label: Text(state.files[i].fileName),
                                onDeleted:
                                    state.sending
                                        ? null
                                        : () => widget.cubit.removeFile(i),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (state.stickerId != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: InputChip(
                        label: Text(
                          chatStickers[state.stickerId] ?? state.stickerId!,
                        ),
                        onDeleted:
                            state.sending
                                ? null
                                : () => widget.cubit.chooseSticker(null),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'إرفاق صور أو فيديو أو ملف',
                        onPressed:
                            state.loading || state.sending
                                ? null
                                : () async {
                                  try {
                                    final files = await widget.pickAttachments(
                                      context,
                                    );
                                    if (mounted)
                                      await widget.cubit.addFiles(files);
                                  } catch (error) {
                                    if (context.mounted)
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            chatErrorText(error.toString()),
                                          ),
                                        ),
                                      );
                                  }
                                },
                        icon: const Icon(Icons.attach_file),
                      ),
                      IconButton(
                        tooltip: 'ملصقات',
                        onPressed:
                            state.loading || state.sending
                                ? null
                                : () async {
                                  final selected =
                                      await showModalBottomSheet<String>(
                                        context: context,
                                        builder:
                                            (context) => SafeArea(
                                              child: Wrap(
                                                children: [
                                                  for (final entry
                                                      in chatStickers.entries)
                                                    IconButton(
                                                      tooltip: entry.key,
                                                      iconSize: 34,
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            context,
                                                            entry.key,
                                                          ),
                                                      icon: Text(entry.value),
                                                    ),
                                                ],
                                              ),
                                            ),
                                      );
                                  if (selected != null)
                                    widget.cubit.chooseSticker(selected);
                                },
                        icon: const Icon(Icons.emoji_emotions_outlined),
                      ),
                      Expanded(
                        child: TextField(
                          key: const Key('chat-composer'),
                          controller: _text,
                          enabled: !state.loading && !state.sending,
                          onChanged: widget.cubit.changeBody,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: 4000,
                          decoration: const InputDecoration(
                            hintText: 'اكتب رسالة…',
                            counterText: '',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      if (!state.loading && !state.sending)
                        widget.voiceBuilder(
                          context,
                          (file) => widget.cubit.addFiles([file]),
                        ),
                      IconButton(
                        key: const Key('chat-send'),
                        tooltip: 'إرسال',
                        onPressed:
                            state.loading ||
                                    state.sending ||
                                    (state.body.trim().isEmpty &&
                                        state.files.isEmpty &&
                                        state.stickerId == null)
                                ? null
                                : widget.cubit.send,
                        icon:
                            state.sending
                                ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
  );
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }
}
