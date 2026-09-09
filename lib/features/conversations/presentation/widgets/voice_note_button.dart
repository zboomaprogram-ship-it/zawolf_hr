import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/chat_media_gateway.dart';
import '../cubit/voice_note_cubit.dart';
import 'chat_local_player.dart';

class VoiceNoteButton extends StatefulWidget {
  const VoiceNoteButton({
    super.key,
    required this.recorder,
    required this.gateway,
    required this.onAttach,
  });
  final ChatRecorder recorder;
  final ChatMediaGateway gateway;
  final Future<void> Function(ChatDraftFile) onAttach;
  @override
  State<VoiceNoteButton> createState() => _VoiceNoteButtonState();
}

class _VoiceNoteButtonState extends State<VoiceNoteButton>
    with WidgetsBindingObserver {
  late final VoiceNoteCubit _cubit = VoiceNoteCubit(widget.recorder);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _cubit.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'رسالة صوتية',
    icon: const Icon(Icons.mic),
    onPressed:
        () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder:
              (_) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: BlocBuilder<VoiceNoteCubit, VoiceNoteState>(
                    bloc: _cubit,
                    builder:
                        (context, state) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('رسالة صوتية • حتى 5 دقائق'),
                            if (state.error != null) Text(state.error!),
                            if (state.busy) const LinearProgressIndicator(),
                            if (state.recording)
                              Text(
                                '${state.seconds ~/ 60}:${(state.seconds % 60).toString().padLeft(2, '0')}',
                              ),
                            if (state.file != null)
                              ChatLocalPlayer(
                                file: state.file!,
                                gateway: widget.gateway,
                              ),
                            Wrap(
                              children: [
                                if (state.file == null)
                                  TextButton.icon(
                                    onPressed:
                                        state.busy
                                            ? null
                                            : state.recording
                                            ? _cubit.stop
                                            : _cubit.start,
                                    icon: Icon(
                                      state.recording ? Icons.stop : Icons.mic,
                                    ),
                                    label: Text(
                                      state.recording ? 'إيقاف' : 'تسجيل',
                                    ),
                                  ),
                                if (state.file != null)
                                  TextButton.icon(
                                    onPressed: () async {
                                      try {
                                        await widget.onAttach(state.file!);
                                        _cubit.attached();
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      } catch (_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'تعذر حفظ التسجيل في المسودة.',
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.attach_file),
                                    label: const Text('إرفاق التسجيل'),
                                  ),
                                TextButton(
                                  onPressed: () async {
                                    await _cubit.cancel();
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  child: const Text('إلغاء'),
                                ),
                              ],
                            ),
                          ],
                        ),
                  ),
                ),
              ),
        ).whenComplete(() => _cubit.stop()),
  );
}
