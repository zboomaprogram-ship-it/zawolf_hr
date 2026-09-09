import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';

class ChatSearchState {
  const ChatSearchState({
    this.query = '',
    this.messages = const [],
    this.loading = false,
    this.offline = false,
    this.complete = true,
    this.cursor,
    this.error,
  });
  final String query;
  final List<RichMessage> messages;
  final bool loading, offline, complete;
  final String? cursor, error;
}

class ChatSearchCubit extends Cubit<ChatSearchState> {
  ChatSearchCubit(this.repository, this.channelId)
    : super(const ChatSearchState());
  final RichChatRepository repository;
  final String channelId;
  int _generation = 0;
  Future<void> search(String query, {bool more = false}) async {
    if (query.trim().isEmpty || (more && state.loading)) return;
    final generation = ++_generation;
    final previous = more ? state.messages : <RichMessage>[];
    final cursor = more ? state.cursor : null;
    emit(ChatSearchState(query: query, messages: previous, loading: true));
    try {
      final page = await repository.search(channelId, query, cursor: cursor);
      if (!isClosed && generation == _generation) {
        emit(
          ChatSearchState(
            query: query,
            messages: [...previous, ...page.items],
            offline: page.offline,
            complete: page.complete,
            cursor: page.nextCursor,
          ),
        );
      }
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(
          ChatSearchState(
            query: query,
            messages: previous,
            error: error.toString(),
            cursor: cursor,
          ),
        );
      }
    }
  }
}
