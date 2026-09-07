import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/sync/authenticated_operation_client.dart';
import '../features/conversations/data/chat_transport.dart';
import '../features/conversations/data/conversation_repository_impl.dart';
import '../features/conversations/data/local/chat_database.dart';
import '../features/conversations/data/local/chat_store.dart';
import '../features/conversations/data/rich_chat_repository_impl.dart';
import '../features/conversations/data/media/chat_media_gateway_impl.dart';
import '../features/conversations/data/media/chat_recorder_impl.dart';
import '../features/conversations/domain/entities/rich_chat.dart';
import '../features/conversations/presentation/pages/rich_chat_inbox_page.dart';
import '../features/conversations/presentation/pages/rich_chat_page.dart';
import '../features/conversations/presentation/widgets/rich_attachment_view.dart';
import '../features/conversations/presentation/widgets/voice_note_button.dart';
import '../features/conversations/presentation/widgets/chat_link_preview_view.dart';
import 'conversation_entry.dart';

/// Composition root alone chooses concrete storage, networking and platform adapters.
class RichConversationEntry extends StatefulWidget {
  const RichConversationEntry({super.key, this.department, this.channelId, this.channelName});
  final String? department, channelId, channelName;
  @override
  State<RichConversationEntry> createState() => _RichConversationEntryState();
}
class _RichConversationEntryState extends State<RichConversationEntry> {
  final _client = http.Client();
  final _media = ChatMediaGatewayImpl();
  RichChatRepositoryImpl? _repository;
  StreamSubscription<User?>? _auth;
  late Future<({ChatCapabilities capabilities, RichChannel? channel})> _bootstrap;
  @override
  void initState() {
    super.initState();
    _bootstrap = _load();
    final actor = FirebaseAuth.instance.currentUser?.uid;
    _auth = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user?.uid != actor) { _repository?.setForeground(false); _repository?.dispose(); if (mounted) setState(() { _repository = null; _bootstrap = _load(); }); }
    });
  }
  Future<({ChatCapabilities capabilities, RichChannel? channel})> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('session_expired');
    Future<String?> token() => FirebaseAuth.instance.currentUser?.uid == uid ? FirebaseAuth.instance.currentUser!.getIdToken() : Future.value(null);
    final base = Uri.parse('https://notification.zawolf.ai');
    final transport = ChatTransport(client: _client, tokenProvider: token, baseUri: base);
    // Check capability before opening local database or loading the replacement.
    ChatCapabilities caps;
    try { final result = await transport.json('GET', '/capabilities'); caps = ChatCapabilities(enabled: result['enabled'] == true, canReview: result['canReview'] == true); }
    catch (_) { caps = const ChatCapabilities(enabled: false, canReview: false); }
    if (!caps.enabled) return (capabilities: caps, channel: null);
    final repository = RichChatRepositoryImpl(actorId: uid, transport: transport, store: ChatStore(ChatDatabase(), uid));
    _repository = repository;
    RichChannel? channel;
    if (widget.department != null) {
      final legacy = ConversationRepositoryImpl(operationClient: AuthenticatedOperationClient(client: _client, tokenProvider: token), operationsBaseUri: base);
      final conversation = widget.department == 'manager-channel'
          ? await legacy.openManagerChannel()
          : await () async {
              try {
                final depts = await legacy.listAvailableDepartments();
                final match = depts.where((d) => d.trim().toLowerCase() == widget.department!.trim().toLowerCase());
                final target = match.isNotEmpty ? match.first : (depts.isNotEmpty ? depts.first : widget.department!);
                return await legacy.openDepartmentChannel(target);
              } catch (_) {
                return await legacy.openDepartmentChannel(widget.department!);
              }
            }();
      channel = RichChannel(id: conversation.id, name: widget.channelName ?? conversation.purposeAr, kind: widget.department == 'manager-channel' ? 'manager' : 'department', canPost: true);
    } else if (widget.channelId != null) {
      final history = await repository.history(widget.channelId!);
      channel = RichChannel(id: widget.channelId!, name: widget.channelName ?? 'المحادثة', canPost: history.canPost, hrReadable: true);
    } else {
      final legacy = ConversationRepositoryImpl(operationClient: AuthenticatedOperationClient(client: _client, tokenProvider: token), operationsBaseUri: base);
      unawaited(() async {
        try {
          final depts = await legacy.listAvailableDepartments();
          if (caps.canReview) {
            for (final dept in depts) {
              await legacy.openDepartmentChannel(dept);
            }
            await legacy.openManagerChannel();
          } else {
            for (final dept in depts) {
              try { await legacy.openDepartmentChannel(dept); } catch (_) {}
            }
          }
        } catch (_) {}
      }());
    }
    return (capabilities: caps, channel: channel);
  }
  Widget _page(RichChannel channel, bool canReview) => RichChatPage(
    repository: _repository!, channel: channel, canReview: canReview,
    attachmentBuilder: (_, attachment) => RichAttachmentView(key: ValueKey('${channel.id}:${attachment.resourceId}'), attachment: attachment, gateway: _media, download: () => _repository!.download(channel.id, attachment.resourceId)),
    pickAttachments: (_) => _media.pickFiles(),
    voiceBuilder: _voiceRecordingEnabled
        ? (_, attach) => VoiceNoteButton(recorder: ChatRecorderImpl(), gateway: _media, onAttach: attach)
        : (_, __) => const SizedBox.shrink(),
    linkPreviewBuilder: (_, preview) => ChatLinkPreviewView(preview: preview),
  );
  static const bool _voiceRecordingEnabled = false;
  @override
  void dispose() { _auth?.cancel(); _repository?.dispose(); _client.close(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FutureBuilder<({ChatCapabilities capabilities, RichChannel? channel})>(future: _bootstrap, builder: (_, snapshot) {
    if (snapshot.hasError) return Scaffold(appBar: AppBar(title: const Text('المحادثات')), body: Center(child: FilledButton(onPressed: () => setState(() => _bootstrap = _load()), child: const Text('تعذر فتح المحادثات • إعادة المحاولة'))));
    if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final data = snapshot.data!;
    if (!data.capabilities.enabled) return ConversationEntry(channelId: widget.department ?? 'general', channelName: widget.channelName);
    if (data.channel != null) return _page(data.channel!, data.capabilities.canReview);
    return RichChatInboxPage(repository: _repository!, canReview: data.capabilities.canReview, openChannel: (context, channel) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _page(channel, data.capabilities.canReview))));
  });
}
