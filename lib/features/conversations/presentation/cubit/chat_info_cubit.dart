import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';

class ChatInfoState {
  const ChatInfoState({
    this.loading = true,
    this.members = const [],
    this.attachments = const [],
    this.error,
  });
  final bool loading;
  final List<ChatUser> members;
  final List<RichAttachment> attachments;
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
      final result = await Future.wait([
        _repository.members(_channelId),
        _repository.history(_channelId),
      ]);
      final members = result[0] as ChatPage<ChatUser>;
      final history = result[1] as RichChatSnapshot;
      final attachments =
          <String, RichAttachment>{
            for (final message in history.messages)
              for (final attachment in message.attachments)
                attachment.resourceId: attachment,
          }.values.toList();
      if (!isClosed) {
        emit(
          ChatInfoState(
            loading: false,
            members: members.items,
            attachments: attachments,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) {
        emit(ChatInfoState(loading: false, error: error.toString()));
      }
    }
  }
}
