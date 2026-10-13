import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zawolf_hr/features/conversations/data/chat_transport.dart';
import 'package:zawolf_hr/features/conversations/data/local/chat_database.dart';
import 'package:zawolf_hr/features/conversations/data/local/chat_store.dart';
import 'package:zawolf_hr/features/conversations/data/rich_chat_repository_impl.dart';
import 'package:zawolf_hr/features/conversations/domain/entities/rich_chat.dart';

void main() {
  test(
    'draft blobs survive repository recreation and are isolated by actor',
    () async {
      final db = ChatDatabase.forTesting(NativeDatabase.memory());
      final transport = ChatTransport(
        client: MockClient((_) async => http.Response('{}', 500)),
        tokenProvider: () async => 'token',
        baseUri: Uri.parse('https://example.test'),
      );
      final first = RichChatRepositoryImpl(
        actorId: 'a',
        transport: transport,
        store: ChatStore(db, 'a'),
      );
      await first.saveDraft('c', 'مرحبا', [
        ChatDraftFile(
          fileName: 'صورة.png',
          mimeType: 'image/png',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      ]);
      final second = RichChatRepositoryImpl(
        actorId: 'a',
        transport: transport,
        store: ChatStore(db, 'a'),
      );
      final draft = await second.loadDraft('c');
      expect(draft.body, 'مرحبا');
      expect(draft.files.single.bytes, [1, 2, 3]);
      final other = RichChatRepositoryImpl(
        actorId: 'b',
        transport: transport,
        store: ChatStore(db, 'b'),
      );
      expect((await other.loadDraft('c')).files, isEmpty);
      await db.close();
    },
  );
  test('body-only draft saves do not rewrite attachment blobs', () async {
    final db = ChatDatabase.forTesting(NativeDatabase.memory());
    final repository = RichChatRepositoryImpl(
      actorId: 'a',
      transport: ChatTransport(
        client: MockClient((_) async => http.Response('{}', 500)),
        tokenProvider: () async => 'token',
        baseUri: Uri.parse('https://example.test'),
      ),
      store: ChatStore(db, 'a'),
    );
    final file = ChatDraftFile(
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      kind: 'image',
    );
    await repository.saveDraft('c', 'first', [file]);
    final firstRows = await db.select(db.chatBlobRows).get();
    await repository.saveDraft('c', 'second', [file]);
    final secondRows = await db.select(db.chatBlobRows).get();
    expect(secondRows.map((row) => row.id), firstRows.map((row) => row.id));
    expect((await repository.loadDraft('c')).body, 'second');
    await repository.dispose();
  });
  test(
    'downloaded media is reused by another chat repository without a second fetch',
    () async {
      final db = ChatDatabase.forTesting(NativeDatabase.memory());
      var downloads = 0;
      final transport = ChatTransport(
        client: MockClient((request) async {
          downloads++;
          return http.Response.bytes(
            [7, 8, 9],
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
        tokenProvider: () async => 'token',
        baseUri: Uri.parse('https://example.test'),
      );
      final first = RichChatRepositoryImpl(
        actorId: 'employee-a',
        transport: transport,
        store: ChatStore(db, 'employee-a'),
      );
      expect((await first.download('channel-1', 'media-1')).bytes, [7, 8, 9]);
      // A second page repository receives the cached attachment rather than
      // issuing another network request.

      final second = RichChatRepositoryImpl(
        actorId: 'employee-a',
        transport: transport,
        store: ChatStore(db, 'employee-a'),
      );
      expect((await second.download('channel-1', 'media-1')).bytes, [7, 8, 9]);
      expect(downloads, 1);
      await second.dispose();
    },
  );
  test(
    'uncertain send retains blob and replays stable IDs after upload completes',
    () async {
      final db = ChatDatabase.forTesting(NativeDatabase.memory());
      final ids = <String>[];
      var fail = true;
      var offset = 0;
      var uploads = 0;
      final client = MockClient((r) async {
        final p = r.url.path;
        Map<String, dynamic> body = {};
        if (r.headers['content-type'] == 'application/json') {
          body = jsonDecode(r.body) as Map<String, dynamic>;
        }
        if (p.endsWith('/uploads')) {
          return http.Response(
            jsonEncode({'ok': true, 'resourceId': 'r', 'offset': offset}),
            200,
          );
        }
        if (p.endsWith('/uploads/r') && r.method == 'GET') {
          return http.Response(jsonEncode({'ok': true, 'offset': offset}), 200);
        }
        if (r.method == 'PUT') {
          uploads++;
          offset += r.bodyBytes.length;
          return http.Response(jsonEncode({'ok': true, 'offset': offset}), 200);
        }
        if (p.endsWith('/finalize')) {
          return http.Response(
            jsonEncode({
              'ok': true,
              'attachment': {
                'resourceId': 'r',
                'fileName': 'a',
                'mimeType': 'text/plain',
                'sizeBytes': 3,
              },
            }),
            200,
          );
        }
        if (p.endsWith('/messages')) {
          expect(offset, 3);
          ids.add(body['operationId'] as String);
          if (fail) throw http.ClientException('lost response');
          return http.Response(
            jsonEncode({
              'ok': true,
              'message': {
                'id': 'server',
                'conversationId': 'c',
                'senderUserId': 'a',
                'body': '',
                'sentAt': DateTime.now().toIso8601String(),
              },
            }),
            200,
          );
        }
        throw StateError('unexpected $p');
      });
      final repo = RichChatRepositoryImpl(
        actorId: 'a',
        transport: ChatTransport(
          client: client,
          tokenProvider: () async => 'token',
          baseUri: Uri.parse('https://example.test'),
        ),
        store: ChatStore(db, 'a'),
      );
      await repo.send(
        'c',
        body: '',
        files: [
          ChatDraftFile(
            fileName: 'a',
            mimeType: 'text/plain',
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ],
      );
      final id = (await repo.pending('c')).single.id;
      await repo.retry('c', id);
      expect((await repo.pending('c')).single.syncState, ChatSyncState.failed);
      fail = false;
      await repo.retry('c', id);
      expect(ids, [id, id]);
      expect(uploads, 1);
      expect(await repo.pending('c'), isEmpty);
      await repo.dispose();
    },
  );
  test('direct upload failure resumes through authenticated proxy', () async {
    final db = ChatDatabase.forTesting(NativeDatabase.memory());
    var cloudAttempts = 0;
    var proxyBytes = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'storage.googleapis.com') {
        cloudAttempts++;
        throw http.ClientException('corporate firewall');
      }
      final path = request.url.path;
      if (path.endsWith('/uploads') && request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'ok': true,
            'resourceId': 'direct-resource',
            'offset': 0,
            'direct': true,
            'sessionUri':
                'https://storage.googleapis.com/upload/storage/v1/b/demo/o?upload_id=x',
            'chunkSize': 4 * 1024 * 1024,
          }),
          200,
        );
      }
      if (path.endsWith('/uploads/direct-resource') &&
          request.method == 'GET') {
        return http.Response(jsonEncode({'ok': true, 'offset': 0}), 200);
      }
      if (path.endsWith('/uploads/direct-resource') &&
          request.method == 'PUT') {
        proxyBytes += request.bodyBytes.length;
        return http.Response(
          jsonEncode({'ok': true, 'offset': proxyBytes}),
          200,
        );
      }
      if (path.endsWith('/finalize')) {
        return http.Response(
          jsonEncode({
            'ok': true,
            'attachment': {
              'resourceId': 'direct-resource',
              'fileName': 'a.txt',
              'mimeType': 'text/plain',
              'sizeBytes': 3,
            },
          }),
          200,
        );
      }
      if (path.endsWith('/messages')) {
        return http.Response(
          jsonEncode({
            'ok': true,
            'message': {
              'id': 'sent',
              'conversationId': 'c',
              'senderUserId': 'a',
              'body': '',
              'sentAt': DateTime.now().toIso8601String(),
            },
          }),
          200,
        );
      }
      throw StateError('unexpected ${request.method} $path');
    });
    final repository = RichChatRepositoryImpl(
      actorId: 'a',
      transport: ChatTransport(
        client: client,
        tokenProvider: () async => 'token',
        baseUri: Uri.parse('https://notification.zawolf.ai'),
      ),
      store: ChatStore(db, 'a'),
    );

    await repository.send(
      'c',
      body: '',
      files: [
        ChatDraftFile(
          fileName: 'a.txt',
          mimeType: 'text/plain',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
      ],
    );
    final operationId = (await repository.pending('c')).single.id;
    await repository.retry('c', operationId);

    expect(cloudAttempts, 1);
    expect(proxyBytes, 3);
    expect(await repository.pending('c'), isEmpty);
    await repository.dispose();
  });
}
