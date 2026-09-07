import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';

class ChatActionState {
  const ChatActionState({this.busy = false, this.error});
  final bool busy;
  final String? error;
}

class ChatActionCubit extends Cubit<ChatActionState> {
  ChatActionCubit(this.repository) : super(const ChatActionState());
  final RichChatRepository repository;
  Future<bool> execute(RichMessage message, String action, {String? body, String? emoji, String? destinationId}) async {
    if (state.busy) return false;
    emit(const ChatActionState(busy: true));
    try {
      await repository.action(message.conversationId, message.id, action: action, body: body, emoji: emoji, destinationId: destinationId, expectedRevision: message.revision);
      if (!isClosed) emit(const ChatActionState());
      return true;
    } catch (error) {
      if (!isClosed) emit(ChatActionState(error: error.toString()));
      return false;
    }
  }
}
