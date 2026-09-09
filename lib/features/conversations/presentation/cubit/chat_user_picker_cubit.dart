import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';

class ChatUserPickerState {
  const ChatUserPickerState({
    this.users = const [],
    this.selected = const {},
    this.query = '',
    this.loading = false,
    this.cursor,
    this.error,
  });
  final List<ChatUser> users;
  final Set<String> selected;
  final String query;
  final bool loading;
  final String? cursor, error;
}

class ChatUserPickerCubit extends Cubit<ChatUserPickerState> {
  ChatUserPickerCubit(
    this.repository,
    Set<String> selected, {
    this.locked = const {},
  }) : super(ChatUserPickerState(selected: {...selected, ...locked}));
  final RichChatRepository repository;
  final Set<String> locked;
  int _generation = 0;
  Future<void> load({String query = '', bool more = false}) async {
    if (more && state.loading) return;
    final generation = ++_generation;
    final users = more ? state.users : <ChatUser>[];
    final cursor = more ? state.cursor : null;
    emit(
      ChatUserPickerState(
        users: users,
        selected: state.selected,
        query: query,
        loading: true,
      ),
    );
    try {
      final page = await repository.users(query: query, cursor: cursor);
      if (!isClosed && generation == _generation) {
        emit(
          ChatUserPickerState(
            users: [...users, ...page.items],
            selected: state.selected,
            query: query,
            cursor: page.nextCursor,
          ),
        );
      }
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(
          ChatUserPickerState(
            users: users,
            selected: state.selected,
            query: query,
            error: error.toString(),
          ),
        );
      }
    }
  }

  void toggle(String id) {
    if (locked.contains(id)) return;
    final selected = {...state.selected};
    if (!selected.remove(id) && selected.length < 100) selected.add(id);
    emit(
      ChatUserPickerState(
        users: state.users,
        selected: selected,
        query: state.query,
        cursor: state.cursor,
        loading: state.loading,
      ),
    );
  }

  void remove(String id) {
    if (state.selected.contains(id)) toggle(id);
  }
}
