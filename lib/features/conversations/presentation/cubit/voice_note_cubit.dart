import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/chat_media_gateway.dart';

class VoiceNoteState {
  const VoiceNoteState({
    this.recording = false,
    this.busy = false,
    this.seconds = 0,
    this.file,
    this.error,
  });
  final bool recording, busy;
  final int seconds;
  final ChatDraftFile? file;
  final String? error;
}

class VoiceNoteCubit extends Cubit<VoiceNoteState> {
  VoiceNoteCubit(this.recorder) : super(const VoiceNoteState());
  final ChatRecorder recorder;
  Timer? _timer;
  Future<void> start() async {
    if (state.busy || state.recording) return;
    emit(const VoiceNoteState(busy: true));
    try {
      if (!await recorder.start()) {
        emit(
          const VoiceNoteState(
            error: 'اسمح باستخدام الميكروفون لتسجيل رسالة صوتية.',
          ),
        );
        return;
      }
      if (isClosed) return;
      emit(const VoiceNoteState(recording: true));
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (isClosed) return;
        final seconds = state.seconds + 1;
        emit(VoiceNoteState(recording: true, seconds: seconds));
        if (seconds >= 300) unawaited(stop());
      });
    } catch (_) {
      if (!isClosed) {
        emit(
          const VoiceNoteState(
            error: 'تعذر بدء التسجيل. تحقق من إذن الميكروفون في المتصفح.',
          ),
        );
      }
    }
  }

  Future<void> stop() async {
    if (!state.recording) return;
    _timer?.cancel();
    emit(VoiceNoteState(busy: true, seconds: state.seconds));
    try {
      final file = await recorder.stop();
      if (!isClosed) emit(VoiceNoteState(file: file));
    } catch (_) {
      if (!isClosed) {
        emit(const VoiceNoteState(error: 'تعذر حفظ التسجيل. أعد المحاولة.'));
      }
    }
  }

  Future<void> cancel() async {
    _timer?.cancel();
    await recorder.cancel();
    if (!isClosed) emit(const VoiceNoteState());
  }

  void attached() => emit(const VoiceNoteState());
  @override
  Future<void> close() async {
    _timer?.cancel();
    await recorder.dispose();
    return super.close();
  }
}
