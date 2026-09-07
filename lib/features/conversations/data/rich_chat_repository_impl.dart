import 'dart:async';
import 'dart:typed_data';
import '../domain/entities/rich_chat.dart';
import '../domain/repositories/rich_chat_repository.dart';
import '../domain/usecases/message_delivery.dart';
import 'chat_codec.dart';
import 'chat_transport.dart';
import 'local/chat_store.dart';

class RichChatRepositoryImpl implements RichChatRepository {
  RichChatRepositoryImpl({
    required this.actorId,
    required this.transport,
    required this.store,
  });
  @override
  final String actorId;
  final ChatTransport transport;
  final ChatStore store;
  final Map<String, Future<void>> _sending = {};
  final Map<String, StreamController<RichChatSnapshot>> _channels = {};
  final Map<String, Timer> _timers = {};
  final Set<String> _polling = {};
  final Map<String, int> _failures = {};
  final Map<String, DateTime> _typed = {};
  StreamController<ChatPage<RichChannel>>? _inbox;
  bool _foreground = true, _disposed = false;
  String _channel(String id) => '/channels/${Uri.encodeComponent(id)}';
  String _query(Map<String, String?> values) =>
      Uri(
        queryParameters: Map.fromEntries(
          values.entries
              .where((e) => e.value != null)
              .map((e) => MapEntry(e.key, e.value!)),
        ),
      ).toString();
  Future<Map<String, Object?>> _get(String path) => transport.json('GET', path);
  Future<Map<String, Object?>> _post(
    String path,
    Map<String, Object?> body, [
    String? operationId,
  ]) => transport.json(
    'POST',
    path,
    body: {...body, 'operationId': operationId ?? newChatOperationId()},
  );
  @override
  Future<ChatCapabilities> capabilities() async {
    final d = await _get('/capabilities');
    return ChatCapabilities(
      enabled: d['enabled'] == true,
      canReview: d['canReview'] == true,
    );
  }

  @override
  Future<ChatPage<RichChannel>> channels({String? cursor}) async {
    try {
      final d = await _get('/channels${_query({'cursor': cursor})}');
      await store.put('', 'inbox', cursor ?? '', d);
      return ChatPage(
        objectList(d['channels']).map(decodeChannel).toList(),
        nextCursor: d['nextCursor'] as String?,
      );
    } on ChatFailure catch (e) {
      if (!_offlineError(e)) rethrow;
      final d = await store.get('', 'inbox', cursor ?? '');
      if (d == null) rethrow;
      return ChatPage(
        objectList(d['channels']).map(decodeChannel).toList(),
        nextCursor: d['nextCursor'] as String?,
        offline: true,
      );
    }
  }

  bool _offlineError(ChatFailure e) =>
      e.code == 'connection_interrupted' || e.code.startsWith('http_5');
  @override
  Stream<ChatPage<RichChannel>> watchInbox() {
    _inbox ??= StreamController<ChatPage<RichChannel>>.broadcast(
      onListen: () => _pollInbox(),
      onCancel: () => _timers.remove('inbox')?.cancel(),
    );
    return _inbox!.stream;
  }

  Future<void> _pollInbox() async {
    if (!_foreground || _disposed || _polling.contains('inbox')) return;
    _polling.add('inbox');
    try {
      _inbox?.add(await channels());
    } catch (e, st) {
      _inbox?.addError(e, st);
    } finally {
      _polling.remove('inbox');
      if (_foreground && !_disposed && (_inbox?.hasListener ?? false)) {
        _timers['inbox'] = Timer(const Duration(seconds: 15), _pollInbox);
      }
    }
  }

  @override
  Stream<RichChatSnapshot> watchChannel(String channelId) {
    return (_channels[channelId] ??=
            StreamController<RichChatSnapshot>.broadcast(
              onListen: () async {
                await _emit(channelId);
                await _poll(channelId);
              },
              onCancel: () => _timers.remove(channelId)?.cancel(),
            ))
        .stream;
  }

  @override
  void setForeground(bool foreground) {
    _foreground = foreground;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    if (foreground) {
      if (_inbox?.hasListener ?? false) _pollInbox();
      for (final e in _channels.entries) {
        if (e.value.hasListener) _poll(e.key);
      }
    }
  }

  Future<void> _poll(String id) async {
    if (!_foreground || _disposed || _polling.contains(id)) return;
    _polling.add(id);
    try {
      final meta = await store.get(id, 'meta', 'timeline');
      final cursor = meta?['changeCursor'] as String?;
      final d = await _get(
        '${_channel(id)}/${cursor == null ? 'messages?limit=50' : 'changes${_query({'after': cursor, 'limit': '100'})}'}',
      );
      await _cache(id, d, delta: cursor != null);
      _failures[id] = 0;
      await _emit(id);
      // One bounded page per tick; a backlog drains promptly without unbounded loops.
      if (d['hasMore'] == true) _failures[id] = -1;
    } catch (e) {
      _failures[id] = (_failures[id] ?? 0) + 1;
      await _emit(id, error: e is ChatFailure ? e.code : 'storage_unavailable');
    } finally {
      _polling.remove(id);
      if (_foreground && !_disposed && (_channels[id]?.hasListener ?? false)) {
        final failures = _failures[id] ?? 0;
        final seconds = failures < 0 ? 1 : (3 * (1 << failures.clamp(0, 4)));
        _timers[id] = Timer(Duration(seconds: seconds), () => _poll(id));
      }
    }
  }

  Future<void> _cache(
    String id,
    Map<String, Object?> data, {
    bool delta = false,
  }) async {
    await store.transaction(() async {
      for (final m in objectList(data['messages'])) {
        await store.put(id, 'message', '${m['id']}', m);
      }
      final old = await store.get(id, 'meta', 'timeline') ?? {};
      await store.put(id, 'meta', 'timeline', {
        ...old,
        ...data,
        'messages': [],
        if (delta) 'nextCursor': old['nextCursor'],
      });
      final accepted =
          objectList(data['messages']).map((m) => '${m['id']}').toSet();
      for (final row in await store.rows(id, 'outbox')) {
        if (accepted.contains(row['serverId'] ?? row['id'])) {
          await _removeOutbox(id, row);
        }
      }
    });
  }

  Future<RichChatSnapshot> _snapshot(String id, {String? error}) async {
    final meta = decodeSnapshot(await store.get(id, 'meta', 'timeline') ?? {});
    final rows = (await store.rows(id, 'message')).map(decodeMessage).toList();
    final ids = rows.map((m) => m.id).toSet();
    rows.addAll((await pending(id)).where((m) => !ids.contains(m.id)));
    rows.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    final denied =
        error == 'access_denied' ||
        error == 'session_expired' ||
        error == 'not_found';
    return RichChatSnapshot(
      messages: denied ? [] : rows,
      readers: denied ? [] : meta.readers,
      typing:
          denied
              ? []
              : meta.typing
                  .where((t) => t.expiresAt.isAfter(DateTime.now()))
                  .toList(),
      canPost: !denied && meta.canPost,
      nextCursor: meta.nextCursor,
      changeCursor: meta.changeCursor,
      hasMore: meta.hasMore,
      offline: error != null,
      errorCode: error,
    );
  }

  Future<void> _emit(String id, {String? error}) async {
    if (!_disposed) _channels[id]?.add(await _snapshot(id, error: error));
  }

  @override
  Future<RichChatSnapshot> history(String channelId, {String? before}) async {
    final d = await _get(
      '${_channel(channelId)}/messages${_query({'before': before, 'limit': '50'})}',
    );
    if (before != null) {
      final old = await store.get(channelId, 'meta', 'timeline');
      d['changeCursor'] = old?['changeCursor'];
    }
    await _cache(channelId, d);
    await _emit(channelId);
    return _snapshot(channelId);
  }

  @override
  Future<List<RichMessage>> pending(String channelId) async =>
      (await store.rows(channelId, 'outbox')).map(decodeMessage).toList();
  void _validate(String body, List<ChatDraftFile> files) {
    if (body.length > 4000 ||
        files.length > 10 ||
        (body.trim().isEmpty && files.isEmpty)) {
      throw const ChatFailure('invalid_message');
    }
    for (final f in files) {
      if (f.bytes.isEmpty ||
          f.bytes.length > 25 * 1024 * 1024 ||
          (f.durationSeconds ?? 0) > 300) {
        throw const ChatFailure('invalid_attachment');
      }
    }
  }

  Future<List<Map<String, Object?>>> _saveFiles(
    String prefix,
    List<ChatDraftFile> files,
  ) async {
    final result = <Map<String, Object?>>[];
    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      final id = '$prefix-$i';
      await store.blob(id, f.bytes);
      result.add({
        'blobId': id,
        'operationId': id,
        'fileName': f.fileName,
        'mimeType': f.mimeType,
        'sizeBytes': f.bytes.length,
        'kind': f.kind,
        'durationSeconds': f.durationSeconds,
      });
    }
    return result;
  }

  @override
  Future<void> send(
    String channelId, {
    required String body,
    List<ChatDraftFile> files = const [],
    String? replyToMessageId,
  }) async {
    _validate(body, files);
    final id = newChatOperationId();
    await store.transaction(() async {
      final saved = await _saveFiles(id, files);
      await store.put(channelId, 'outbox', id, {
        'id': id,
        'conversationId': channelId,
        'senderUserId': actorId,
        'body': body,
        'sentAt': DateTime.now().toUtc().toIso8601String(),
        'syncState': 'pending',
        'replyToMessageId': replyToMessageId,
        'files': saved,
        'attachments':
            saved
                .map((f) => {...f, 'resourceId': '', 'status': 'pending'})
                .toList(),
      });
      await _clearDraft(channelId);
    });
    await _emit(channelId);
    unawaited(retry(channelId, id).catchError((Object _) {}));
  }

  @override
  Future<void> retry(String channelId, String operationId) =>
      _sending[operationId] ??= _deliver(channelId, operationId).whenComplete(
        () {
          _sending.remove(operationId);
        },
      );
  Future<void> _deliver(String channelId, String id) async {
    final row = await store.get(channelId, 'outbox', id);
    if (row == null) return;
    try {
      row['syncState'] = 'pending';
      row['errorCode'] = null;
      await store.put(channelId, 'outbox', id, row);
      await _emit(channelId);
      final attachments = <Map<String, Object?>>[];
      for (final file in objectList(row['files'])) {
        final a = await _upload(channelId, file, (progress) async {
          row['uploadProgress'] = progress;
          await store.put(channelId, 'outbox', id, row);
          await _emit(channelId);
        });
        attachments.add(a);
      }
      final d = await _post('${_channel(channelId)}/messages', {
        'body': row['body'],
        'attachmentResourceIds':
            attachments.map((a) => a['resourceId']).toList(),
        'replyToMessageId': row['replyToMessageId'],
      }, id);
      final message = objectMap(d['message']);
      if (message['id'] == null) throw const ChatFailure('invalid_response');
      await store.transaction(() async {
        await store.put(channelId, 'message', '${message['id']}', message);
        await _removeOutbox(channelId, row);
      });
    } catch (e) {
      row['syncState'] =
          e is ChatFailure && e.code.contains('conflict')
              ? 'conflict'
              : 'failed';
      row['errorCode'] = e is ChatFailure ? e.code : 'storage_unavailable';
      await store.put(channelId, 'outbox', id, row);
    }
    await _emit(channelId);
  }

  Future<Map<String, Object?>> _upload(
    String channelId,
    Map<String, Object?> file,
    Future<void> Function(double) onProgress,
  ) async {
    final path = '${_channel(channelId)}/uploads';
    // Creation is keyed by persisted file operation ID; an uncertain result can be replayed.
    final created = await _post(path, {
      'fileName': file['fileName'],
      'mimeType': file['mimeType'],
      'sizeBytes': file['sizeBytes'],
      'kind': file['kind'],
      'durationSeconds': file['durationSeconds'],
    }, '${file['operationId']}');
    final resourceId = '${created['resourceId']}';
    final uploadPath = '$path/${Uri.encodeComponent(resourceId)}';
    var state = await _get(uploadPath);
    final bytes = await store.bytes('${file['blobId']}');
    var offset = (state['offset'] as num?)?.toInt() ?? 0;
    while (offset < bytes.length) {
      final end = (offset + 1024 * 1024).clamp(0, bytes.length);
      state = await transport.json(
        'PUT',
        uploadPath,
        bytes: Uint8List.sublistView(bytes, offset, end),
        headers: {
          'X-Upload-Offset': '$offset',
          'X-Operation-Id': '${file['operationId']}-$offset',
        },
      );
      final next = (state['offset'] as num?)?.toInt() ?? 0;
      if (next <= offset || next > bytes.length) {
        throw const ChatFailure('invalid_upload_offset');
      }
      offset = next;
      await onProgress(offset / bytes.length);
    }
    final finalized = await _post(
      '$uploadPath/finalize',
      {},
      '${file['operationId']}-finalize',
    );
    return objectMap(finalized['attachment']);
  }

  Future<void> _removeOutbox(String channelId, Map<String, Object?> row) async {
    for (final f in objectList(row['files'])) {
      await store.removeBlob('${f['blobId']}');
    }
    await store.remove(channelId, 'outbox', '${row['id']}');
  }

  Future<void> _clearDraft(String id) async {
    final old = await store.get(id, 'draft', 'draft');
    for (final f in objectList(old?['files'])) {
      await store.removeBlob('${f['blobId']}');
    }
    await store.remove(id, 'draft', 'draft');
  }

  @override
  Future<void> saveDraft(
    String channelId,
    String body,
    List<ChatDraftFile> files, {
    String? replyToMessageId,
  }) => store.transaction(() async {
    await _clearDraft(channelId);
    await store.put(channelId, 'draft', 'draft', {
      'body': body,
      'replyToMessageId': replyToMessageId,
      'files': await _saveFiles('draft-${newChatOperationId()}', files),
    });
  });
  @override
  Future<({String body, List<ChatDraftFile> files, String? replyToMessageId})>
  loadDraft(String channelId) async {
    final d = await store.get(channelId, 'draft', 'draft') ?? {};
    final files = <ChatDraftFile>[];
    for (final f in objectList(d['files'])) {
      files.add(
        ChatDraftFile(
          fileName: '${f['fileName']}',
          mimeType: '${f['mimeType']}',
          bytes: await store.bytes('${f['blobId']}'),
          kind: '${f['kind']}',
          durationSeconds: (f['durationSeconds'] as num?)?.toDouble(),
        ),
      );
    }
    return (
      body: '${d['body'] ?? ''}',
      files: files,
      replyToMessageId: d['replyToMessageId'] as String?,
    );
  }

  @override
  Future<RichMessage> action(
    String channelId,
    String messageId, {
    required String action,
    String? body,
    String? emoji,
    String? destinationId,
    int? expectedRevision,
    String? operationId,
  }) async {
    final d = await _post(
      '${_channel(channelId)}/messages/${Uri.encodeComponent(messageId)}/actions',
      {
        'action': action,
        if (body != null) 'body': body,
        if (emoji != null) 'emoji': emoji,
        if (destinationId != null) 'destinationId': destinationId,
        if (expectedRevision != null) 'expectedRevision': expectedRevision,
      },
      operationId,
    );
    final m = decodeMessage(objectMap(d['message']));
    await store.put(m.conversationId, 'message', m.id, encodeMessage(m));
    await _emit(m.conversationId);
    return m;
  }

  @override
  Future<List<Map<String, Object?>>> audit(
    String channelId,
    String messageId,
  ) async => objectList(
    (await _get(
      '${_channel(channelId)}/messages/${Uri.encodeComponent(messageId)}/audit',
    ))['revisions'],
  );
  @override
  Future<void> markRead(String channelId, String messageId) async {
    if (!_foreground) return;
    await _post('${_channel(channelId)}/read', {'messageId': messageId});
  }

  @override
  Future<void> typing(String channelId, bool typing) async {
    if (!_foreground) return;
    final last = _typed[channelId];
    if (typing &&
        last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 3)) {
      return;
    }
    _typed[channelId] = DateTime.now();
    await _post('${_channel(channelId)}/typing', {'typing': typing});
  }

  @override
  Future<ChatPage<RichMessage>> search(
    String channelId,
    String query, {
    String? cursor,
  }) async {
    try {
      final d = await _get(
        '${_channel(channelId)}/search${_query({'q': query, 'cursor': cursor})}',
      );
      return ChatPage(
        objectList(d['messages']).map(decodeMessage).toList(),
        nextCursor: d['nextCursor'] as String?,
        complete: d['complete'] == true,
      );
    } on ChatFailure catch (e) {
      if (!_offlineError(e)) rethrow;
      final rows =
          (await store.rows(channelId, 'message'))
              .map(decodeMessage)
              .where(
                (m) =>
                    !m.isDeleted &&
                    m.body.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
      return ChatPage(rows, offline: true, complete: false);
    }
  }

  @override
  Future<ChatLinkPreview?> preview(String channelId, String url) async {
    try {
      final p = objectMap(
        (await _post('${_channel(channelId)}/preview', {
          'url': url,
        }))['preview'],
      );
      return p.isEmpty
          ? null
          : ChatLinkPreview(
            url: '${p['url']}',
            title: '${p['title'] ?? ''}',
            image: p['image'] as String?,
          );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ChatPage<ChatUser>> users({String query = '', String? cursor}) async {
    final d = await _get('/users${_query({'q': query, 'cursor': cursor})}');
    return ChatPage(
      objectList(d['users'])
          .map(
            (u) => ChatUser(
              id: '${u['id']}',
              name: '${u['name']}',
              department: '${u['department'] ?? ''}',
            ),
          )
          .toList(),
      nextCursor: d['nextCursor'] as String?,
    );
  }

  @override
  Future<ChatPage<ChannelRequest>> requests({String? cursor}) async {
    final d = await _get('/requests${_query({'cursor': cursor})}');
    return ChatPage(
      objectList(d['requests']).map(decodeRequest).toList(),
      nextCursor: d['nextCursor'] as String?,
    );
  }

  @override
  Future<ChannelRequest> createRequest({
    required String name,
    required String reason,
    required List<String> memberUserIds,
    String? operationId,
  }) async => decodeRequest(
    objectMap(
      (await _post('/requests', {
        'name': name,
        'reason': reason,
        'memberUserIds': memberUserIds,
      }, operationId))['request'],
    ),
  );
  @override
  Future<ChannelRequest> reviewRequest(
    String requestId, {
    required String decision,
    required int expectedRevision,
    String? name,
    List<String>? memberUserIds,
    String? reason,
    String? operationId,
  }) async => decodeRequest(
    objectMap(
      (await _post('/requests/${Uri.encodeComponent(requestId)}/review', {
        'decision': decision,
        'expectedRevision': expectedRevision,
        if (name != null) 'name': name,
        if (memberUserIds != null) 'memberUserIds': memberUserIds,
        if (reason != null) 'reason': reason,
      }, operationId))['request'],
    ),
  );
  @override
  Future<RichChannel> updateMembers(
    String channelId,
    List<String> memberUserIds,
    int expectedRevision, {
    String? operationId,
  }) async => decodeChannel(
    objectMap(
      (await _post('${_channel(channelId)}/members', {
        'memberUserIds': memberUserIds,
        'expectedRevision': expectedRevision,
      }, operationId))['channel'],
    ),
  );
  @override
  Future<RichAttachment> attachment(
    String channelId,
    String resourceId,
  ) async => decodeAttachment(
    objectMap(
      (await _get(
        '${_channel(channelId)}/attachments/${Uri.encodeComponent(resourceId)}',
      ))['attachment'],
    ),
  );
  @override
  Future<ChatDraftFile> download(
    String channelId,
    String resourceId,
  ) => transport.download(
    '${_channel(channelId)}/attachments/${Uri.encodeComponent(resourceId)}/download',
  );
  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    await Future.wait(_sending.values);
    for (final c in _channels.values) {
      await c.close();
    }
    await _inbox?.close();
    await store.database.close();
  }
}
