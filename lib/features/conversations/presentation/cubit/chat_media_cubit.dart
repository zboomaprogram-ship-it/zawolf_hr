import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';

class ChatMediaState {
  const ChatMediaState({this.file, this.loading = false, this.error});
  final ChatDraftFile? file;
  final bool loading;
  final String? error;
}

class ChatMediaCubit extends Cubit<ChatMediaState> {
  ChatMediaCubit(this.download) : super(const ChatMediaState());
  final Future<ChatDraftFile> Function() download;
  Future<void> load() async {
    if (state.loading || state.file != null) return;
    emit(const ChatMediaState(loading: true));
    try {
      final file = await download();
      if (!isClosed) emit(ChatMediaState(file: file));
    } catch (_) {
      if (!isClosed) {
        emit(const ChatMediaState(error: 'تعذر تحميل المرفق. أعد المحاولة.'));
      }
    }
  }
}
