import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zawolf_hr/features/conversations/data/chat_transport.dart';

void main() {
  test(
    'direct upload uses cloud session without application authorization',
    () async {
      late http.Request captured;
      final transport = ChatTransport(
        client: MockClient((request) async {
          captured = request;
          return http.Response('', 308, headers: {'range': 'bytes=0-3'});
        }),
        tokenProvider: () async => 'private-app-token',
        baseUri: Uri.parse('https://notification.zawolf.ai'),
      );

      final offset = await transport.directUploadChunk(
        sessionUri: Uri.parse(
          'https://storage.googleapis.com/upload/storage/v1/b/demo/o?upload_id=secret',
        ),
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        offset: 0,
        totalBytes: 8,
      );

      expect(offset, 4);
      expect(captured.headers.containsKey('authorization'), isFalse);
      expect(captured.headers['content-range'], 'bytes 0-3/8');
    },
  );

  test('direct upload rejects untrusted session hosts', () async {
    final transport = ChatTransport(
      client: MockClient((_) async => http.Response('', 200)),
      tokenProvider: () async => 'token',
      baseUri: Uri.parse('https://notification.zawolf.ai'),
    );

    expect(
      () => transport.directUploadChunk(
        sessionUri: Uri.parse('https://example.com/upload'),
        bytes: Uint8List.fromList([1]),
        offset: 0,
        totalBytes: 1,
      ),
      throwsA(isA<Exception>()),
    );
  });
}
