import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/conversations/data/local/platform_chat_blob_store_native.dart';

void main() {
  test('native chat files are isolated, replaceable, and removable', () async {
    final root = await Directory.systemTemp.createTemp('chat-files-test-');
    addTearDown(() => root.delete(recursive: true));
    final alice = NativeChatBlobStore('alice', rootProvider: () async => root);
    final bob = NativeChatBlobStore('bob', rootProvider: () async => root);

    await alice.write('same-id', Uint8List.fromList([1, 2]));
    await bob.write('same-id', Uint8List.fromList([9]));
    expect(await alice.read('same-id'), [1, 2]);
    expect(await bob.read('same-id'), [9]);

    await alice.write('same-id', Uint8List.fromList([3, 4, 5]));
    expect(await alice.read('same-id'), [3, 4, 5]);
    await alice.remove('same-id');
    expect(alice.read('same-id'), throwsA(isA<FileSystemException>()));
  });
}
