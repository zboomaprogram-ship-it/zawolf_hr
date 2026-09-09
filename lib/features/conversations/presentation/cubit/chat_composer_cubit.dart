import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';

class ChatComposerState {
  const ChatComposerState({
    this.body = '',
    this.files = const [],
    this.reply,
    this.stickerId,
    this.loading = true,
    this.sending = false,
    this.error,
    this.revision = 0,
  });
  final String body;
  final List<ChatDraftFile> files;
  final RichMessage? reply;
  final String? stickerId;
  final bool loading, sending;
  final String? error;
  final int revision;
}

class ChatComposerCubit extends Cubit<ChatComposerState> {
  ChatComposerCubit(this.repository, this.channelId)
    : super(const ChatComposerState()) {
    unawaited(_restore());
  }
  final RichChatRepository repository;
  final String channelId;
  Future<void> _writes = Future.value();
  Timer? _typingStop;
  DateTime? _lastTyping;

  Future<void> _restore() async {
    try {
      final draft = await repository.loadDraft(channelId);
      if (!isClosed) {
        emit(
          ChatComposerState(
            body: draft.body,
            files: draft.files,
            loading: false,
            revision: 1,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) {
        emit(ChatComposerState(loading: false, error: error.toString()));
      }
    }
  }

  void changeBody(String body) {
    if (state.loading || state.sending) return;
    emit(
      ChatComposerState(
        body: body,
        files: state.files,
        reply: state.reply,
        stickerId: state.stickerId,
        loading: false,
        revision: state.revision,
      ),
    );
    _persist();
    final now = DateTime.now();
    if (_lastTyping == null ||
        now.difference(_lastTyping!) >= const Duration(seconds: 3)) {
      _lastTyping = now;
      unawaited(
        repository.typing(channelId, body.isNotEmpty).catchError((_) {}),
      );
    }
    _typingStop?.cancel();
    _typingStop = Timer(const Duration(seconds: 4), stopTyping);
  }

  void stopTyping() {
    _typingStop?.cancel();
    unawaited(repository.typing(channelId, false).catchError((_) {}));
  }

  void replyTo(RichMessage? reply) {
    emit(
      ChatComposerState(
        body: state.body,
        files: state.files,
        reply: reply,
        stickerId: state.stickerId,
        loading: false,
        revision: state.revision,
      ),
    );
  }

  void chooseSticker(String? stickerId) {
    if (state.sending || state.loading) return;
    emit(
      ChatComposerState(
        body: state.body,
        files: state.files,
        reply: state.reply,
        stickerId: stickerId,
        loading: false,
        revision: state.revision + 1,
      ),
    );
  }

  Future<void> addFiles(List<ChatDraftFile> files) async {
    if (state.sending || state.loading) return;
    if (state.files.length + files.length > 10 ||
        files.any(
          (file) => file.bytes.isEmpty || file.bytes.length > 25 * 1024 * 1024,
        )) {
      emit(
        ChatComposerState(
          body: state.body,
          files: state.files,
          reply: state.reply,
          loading: false,
          error: 'attachment_limit',
          revision: state.revision,
        ),
      );
      return;
    }
    emit(
      ChatComposerState(
        body: state.body,
        files: [...state.files, ...files],
        reply: state.reply,
        stickerId: state.stickerId,
        loading: false,
        revision: state.revision,
      ),
    );
    _persist();
    await _writes;
  }

  void removeFile(int index) {
    if (state.sending) return;
    final files = [...state.files]..removeAt(index);
    emit(
      ChatComposerState(
        body: state.body,
        files: files,
        reply: state.reply,
        stickerId: state.stickerId,
        loading: false,
        revision: state.revision,
      ),
    );
    _persist();
  }

  void _persist() {
    final body = state.body;
    final files = state.files;
    _writes = _writes
        .then((_) => repository.saveDraft(channelId, body, files))
        .catchError((Object error) {
          if (!isClosed) {
            emit(
              ChatComposerState(
                body: state.body,
                files: state.files,
                reply: state.reply,
                loading: false,
                error: error.toString(),
                revision: state.revision,
              ),
            );
          }
        });
  }

  Future<void> send() async {
    if (state.sending ||
        state.loading ||
        (state.body.trim().isEmpty &&
            state.files.isEmpty &&
            state.stickerId == null)) {
      return;
    }
    final draft = state;
    emit(
      ChatComposerState(
        body: draft.body,
        files: draft.files,
        reply: draft.reply,
        stickerId: draft.stickerId,
        loading: false,
        sending: true,
        revision: draft.revision,
      ),
    );
    stopTyping();
    try {
      await _writes;
      await repository.send(
        channelId,
        body: draft.body,
        files: draft.files,
        replyToMessageId: draft.reply?.id,
        stickerId: draft.stickerId,
      );
      // send returns only after the durable outbox owns the complete draft.
      if (!isClosed) {
        emit(ChatComposerState(loading: false, revision: draft.revision + 1));
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          ChatComposerState(
            body: draft.body,
            files: draft.files,
            reply: draft.reply,
            stickerId: draft.stickerId,
            loading: false,
            error: error.toString(),
            revision: draft.revision,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    stopTyping();
    await _writes;
    return super.close();
  }
}
