import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';

class ChatTimelineState {
  const ChatTimelineState({
    this.snapshot = const RichChatSnapshot(),
    this.loading = false,
    this.paging = false,
    this.error,
  });
  final RichChatSnapshot snapshot;
  final bool loading, paging;
  final String? error;
}

class ChatTimelineCubit extends Cubit<ChatTimelineState> {
  ChatTimelineCubit(this.repository, this.channelId)
    : super(const ChatTimelineState(loading: true)) {
    _subscription = repository
        .watchChannel(channelId)
        .listen(
          (snapshot) {
            if (!isClosed) {
              emit(
                ChatTimelineState(
                  snapshot: snapshot,
                  loading: false,
                  error: snapshot.errorCode,
                ),
              );
            }
          },
          onError: (Object error) {
            if (!isClosed) {
              emit(
                ChatTimelineState(
                  snapshot: state.snapshot,
                  loading: false,
                  error: error.toString(),
                ),
              );
            }
          },
        );
  }
  final RichChatRepository repository;
  final String channelId;
  StreamSubscription<RichChatSnapshot>? _subscription;
  String? _lastSeen;
  bool _markingRead = false;

  Future<void> loadOlder() async {
    if (state.paging) return;
    emit(
      ChatTimelineState(snapshot: state.snapshot, paging: true, loading: false),
    );
    try {
      final snapshot = await repository.history(
        channelId,
        before: state.snapshot.nextCursor,
      );
      if (!isClosed) {
        emit(ChatTimelineState(snapshot: snapshot, loading: false));
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          ChatTimelineState(
            snapshot: state.snapshot,
            loading: false,
            error: error.toString(),
          ),
        );
      }
    }
  }

  Future<void> visibleMessage(
    RichMessage message, {
    required bool active,
    required bool member,
  }) async {
    if (!active ||
        !member ||
        _markingRead ||
        message.syncState != ChatSyncState.synced ||
        message.id == _lastSeen) {
      return;
    }
    _markingRead = true;
    try {
      await repository.markRead(channelId, message.id);
      _lastSeen = message.id;
    } catch (_) {
      // A later rendered frame can retry; reading never blocks the conversation.
    } finally {
      _markingRead = false;
    }
  }

  Future<void> retry(String operationId) async {
    try {
      await repository.retry(channelId, operationId);
    } catch (error) {
      if (!isClosed) {
        emit(
          ChatTimelineState(
            snapshot: state.snapshot,
            loading: false,
            error: error.toString(),
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
