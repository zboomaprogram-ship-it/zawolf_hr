import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';

class ChatInfoState {
  const ChatInfoState({
    this.loading = true,
    this.members = const [],
    this.attachments = const [],
    this.memberCount = 0,
    this.notificationsEnabled = true,
    this.error,
  });
  final bool loading;
  final List<ChatUser> members;
  final List<RichAttachment> attachments;
  final int memberCount;
  final bool notificationsEnabled;
  final String? error;
}

class ChatInfoCubit extends Cubit<ChatInfoState> {
  ChatInfoCubit(this._repository, this._channelId)
    : super(const ChatInfoState()) {
    load();
  }

  final RichChatRepository _repository;
  final String _channelId;
  List<ChatUser> _allMembers = const [];

  Future<void> load() async {
    emit(const ChatInfoState());
    try {
      final result = await Future.wait([
        _repository.members(_channelId),
        _repository.history(_channelId),
        _repository.channelNotificationsEnabled(_channelId),
      ]);
      final members = result[0] as ChatPage<ChatUser>;
      _allMembers = members.items;
      final history = result[1] as RichChatSnapshot;
      final notificationsEnabled = result[2] as bool;
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
            memberCount: members.items.length,
            notificationsEnabled: notificationsEnabled,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) {
        emit(ChatInfoState(loading: false, error: error.toString()));
      }
    }
  }

  void searchMembers(String query) {
    if (isClosed) return;
    final normalized = query.trim().toLowerCase();
    final visible =
        normalized.isEmpty
            ? _allMembers
            : _allMembers
                .where(
                  (member) => '${member.name} ${member.department}'
                      .toLowerCase()
                      .contains(normalized),
                )
                .toList();
    emit(
      ChatInfoState(
        loading: false,
        members: visible,
        attachments: state.attachments,
        memberCount: _allMembers.length,
        notificationsEnabled: state.notificationsEnabled,
      ),
    );
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prior = state;
    emit(
      ChatInfoState(
        loading: false,
        members: prior.members,
        attachments: prior.attachments,
        memberCount: prior.memberCount,
        notificationsEnabled: enabled,
      ),
    );
    try {
      await _repository.setChannelNotificationsEnabled(_channelId, enabled);
    } catch (error) {
      if (!isClosed) {
        emit(
          ChatInfoState(
            loading: false,
            members: prior.members,
            attachments: prior.attachments,
            memberCount: prior.memberCount,
            notificationsEnabled: prior.notificationsEnabled,
            error: error.toString(),
          ),
        );
      }
    }
  }
}
