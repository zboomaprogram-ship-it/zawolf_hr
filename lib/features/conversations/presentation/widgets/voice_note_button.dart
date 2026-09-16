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
    this.onSend,
    this.onRecordingChanged,
  });
  final ChatRecorder recorder;
  final ChatMediaGateway gateway;
  final Future<void> Function(ChatDraftFile) onAttach;
  final Future<void> Function(ChatDraftFile)? onSend;
  final void Function(bool isRecording)? onRecordingChanged;

  @override
  State<VoiceNoteButton> createState() => _VoiceNoteButtonState();
}

class _VoiceNoteButtonState extends State<VoiceNoteButton>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final VoiceNoteCubit _cubit = VoiceNoteCubit(widget.recorder);
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _stopAndNotify(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _cubit.close();
    super.dispose();
  }

  void _notifyRecording(bool isRecording) {
    widget.onRecordingChanged?.call(isRecording);
  }

  Future<void> _startRecording() async {
    _notifyRecording(true);
    await _cubit.start();
  }

  Future<void> _cancelRecording() async {
    _notifyRecording(false);
    await _cubit.cancel();
  }

  Future<void> _stopAndNotify(bool stayActive) async {
    if (!stayActive) {
      _notifyRecording(false);
    }
    await _cubit.stop();
  }

  Future<void> _send(ChatDraftFile file) async {
    _notifyRecording(false);
    try {
      if (widget.onSend != null) {
        await widget.onSend!(file);
      } else {
        await widget.onAttach(file);
      }
      _cubit.attached();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إرسال التسجيل الصوتي.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<VoiceNoteCubit, VoiceNoteState>(
    bloc: _cubit,
    listener: (context, state) {
      if (state.error != null) {
        _notifyRecording(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error!)),
        );
      }
    },
    builder: (context, state) {
      if (state.recording) {
        final minutes = state.seconds ~/ 60;
        final seconds = (state.seconds % 60).toString().padLeft(2, '0');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'إلغاء التسجيل',
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: _cancelRecording,
              ),
              const SizedBox(width: 4),
              FadeTransition(
                opacity: _pulseController,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$minutes:$seconds',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'إيقاف للمعاينة',
                icon: const Icon(Icons.stop),
                onPressed: () => _stopAndNotify(true),
              ),
              const SizedBox(width: 4),
              Material(
                color: const Color(0xFF25D366),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  tooltip: 'إرسال',
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: () async {
                    await _cubit.stop();
                    if (_cubit.state.file != null) {
                      await _send(_cubit.state.file!);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      }

      if (state.file != null) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'حذف التسجيل',
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: _cancelRecording,
              ),
              Expanded(
                child: ChatLocalPlayer(
                  file: state.file!,
                  gateway: widget.gateway,
                  isVoice: true,
                ),
              ),
              Material(
                color: const Color(0xFF25D366),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  tooltip: 'إرسال',
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: () => _send(state.file!),
                ),
              ),
            ],
          ),
        );
      }

      return IconButton(
        tooltip: 'رسالة صوتية',
        icon: const Icon(Icons.mic),
        onPressed: _startRecording,
      );
    },
  );
}
