import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';

class ChatRequestsState {
  const ChatRequestsState({this.requests = const [], this.loading = true, this.cursor, this.error});
  final List<ChannelRequest> requests;
  final bool loading;
  final String? cursor, error;
}
class ChatRequestsCubit extends Cubit<ChatRequestsState> {
  ChatRequestsCubit(this.repository) : super(const ChatRequestsState());
  final RichChatRepository repository;
  Future<void> load({bool more = false}) async {
    final previous = more ? state.requests : <ChannelRequest>[];
    final cursor = more ? state.cursor : null;
    emit(ChatRequestsState(requests: state.requests));
    try {
      final page = await repository.requests(cursor: cursor);
      if (!isClosed) emit(ChatRequestsState(requests: [...previous, ...page.items], loading: false, cursor: page.nextCursor));
    } catch (error) { if (!isClosed) emit(ChatRequestsState(requests: previous, loading: false, error: error.toString(), cursor: cursor)); }
  }
}

class ChatRequestFormState {
  const ChatRequestFormState({required this.members, this.busy = false, this.error});
  final List<String> members;
  final bool busy;
  final String? error;
}
class ChatRequestFormCubit extends Cubit<ChatRequestFormState> {
  ChatRequestFormCubit(this.repository, List<String> members) : super(ChatRequestFormState(members: members));
  final RichChatRepository repository;
  void members(List<String> members) { if (!state.busy) emit(ChatRequestFormState(members: members)); }
  Future<ChannelRequest?> submit({required String name, required String reason, ChannelRequest? request, String decision = 'approved', String? rejectionReason, bool canReview = false}) async {
    if (state.busy) return null;
    if ((request == null || decision == 'approved') && (state.members.length < 2 || state.members.length > 100)) {
      emit(ChatRequestFormState(members: state.members, error: 'validation_failed'));
      return null;
    }
    emit(ChatRequestFormState(members: state.members, busy: true));
    try {
      final ChannelRequest result;
      if (request == null) {
        final created = await repository.createRequest(name: name.trim(), reason: reason.trim(), memberUserIds: state.members);
        if (canReview) {
          result = await repository.reviewRequest(created.id, decision: 'approved', expectedRevision: created.revision, name: name.trim(), memberUserIds: state.members);
        } else {
          result = created;
        }
      } else {
        result = await repository.reviewRequest(request.id, decision: decision, expectedRevision: request.revision, name: name.trim(), memberUserIds: state.members, reason: rejectionReason);
      }
      if (!isClosed) emit(ChatRequestFormState(members: state.members));
      return result;
    } catch (error) {
      if (!isClosed) emit(ChatRequestFormState(members: state.members, error: error.toString()));
      return null;
    }
  }
}
