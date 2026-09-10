import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';

List<RichChannel> _ordered(Iterable<RichChannel> source) {
  final channels = source.toList();
  channels.sort((a, b) {
    final byActivity = (b.latestActivityAt ??
            DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(
          a.latestActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
    return byActivity != 0 ? byActivity : b.id.compareTo(a.id);
  });
  return channels;
}

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
    {
      _subscription = repository
          .watchInbox(section: section)
          .listen(
            (page) {
              if (!isClosed) {
                emit(
                  ChatInboxState(
                    channels: _ordered(page.items),
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
      final channels = _ordered(
        {
          ...{for (final channel in previous) channel.id: channel},
          ...{for (final channel in page.items) channel.id: channel},
        }.values,
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
