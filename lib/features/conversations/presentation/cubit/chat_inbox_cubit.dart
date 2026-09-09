import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';

class ChatInboxState {
  const ChatInboxState({
    this.channels = const [],
    this.loading = true,
    this.offline = false,
    this.cursor,
    this.error,
  });
  final List<RichChannel> channels;
  final bool loading, offline;
  final String? cursor, error;
}

class ChatInboxCubit extends Cubit<ChatInboxState> {
  ChatInboxCubit(this.repository, {this.section})
    : super(const ChatInboxState()) {
    if (section == null) {
      _subscription = repository.watchInbox().listen(
        (page) {
          if (!isClosed) {
            emit(
              ChatInboxState(
                channels: page.items,
                loading: false,
                offline: page.offline,
                cursor: page.nextCursor,
              ),
            );
          }
        },
        onError: (Object error) {
          if (!isClosed) {
            emit(
              ChatInboxState(
                channels: state.channels,
                loading: false,
                error: error.toString(),
              ),
            );
          }
        },
      );
    }
    load();
  }
  final RichChatRepository repository;
  final String? section;
  StreamSubscription<ChatPage<RichChannel>>? _subscription;
  Future<void> load({bool more = false}) async {
    final previous = more ? state.channels : <RichChannel>[];
    final cursor = more ? state.cursor : null;
    emit(ChatInboxState(channels: state.channels, cursor: state.cursor));
    try {
      final page = await repository.channels(cursor: cursor, section: section);
      final channels =
          {
              ...{for (final channel in previous) channel.id: channel},
              ...{for (final channel in page.items) channel.id: channel},
            }.values.toList()
            ..sort(
              (a, b) =>
                  (b.latestActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                      .compareTo(
                        a.latestActivityAt ??
                            DateTime.fromMillisecondsSinceEpoch(0),
                      ),
            );
      if (!isClosed) {
        emit(
          ChatInboxState(
            channels: channels,
            loading: false,
            offline: page.offline,
            cursor: page.nextCursor,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          ChatInboxState(
            channels: previous,
            loading: false,
            error: error.toString(),
            cursor: cursor,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
