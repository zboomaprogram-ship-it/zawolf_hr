import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';

class ChatInfoState {
  const ChatInfoState({
    this.loading = true,
    this.members = const [],
    this.error,
  });
  final bool loading;
  final List<ChatUser> members;
  final String? error;
}

class ChatInfoCubit extends Cubit<ChatInfoState> {
  ChatInfoCubit(this._repository, this._channelId)
    : super(const ChatInfoState()) {
    load();
  }

  final RichChatRepository _repository;
  final String _channelId;

  Future<void> load() async {
    emit(const ChatInfoState());
    try {
      final page = await _repository.members(_channelId);
      if (!isClosed) {
        emit(ChatInfoState(loading: false, members: page.items));
      }
    } catch (error) {
      if (!isClosed) {
        emit(ChatInfoState(loading: false, error: error.toString()));
      }
    }
  }
}
