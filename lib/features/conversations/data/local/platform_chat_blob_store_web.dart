import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'chat_blob_store.dart';

/// Browser binary storage backed by Cache Storage. Drift keeps only metadata,
/// matching the native filesystem design without requiring an OPFS polyfill.
class WebChatBlobStore implements ChatBlobStore {
  WebChatBlobStore(String actor)
    : _cacheName =
          'zawolf-chat-${base64Url.encode(utf8.encode(actor)).replaceAll('=', '')}';

  final String _cacheName;
  Future<web.Cache> get _cache => web.window.caches.open(_cacheName).toDart;
  String _key(String id) =>
      'https://chat-cache.invalid/${Uri.encodeComponent(id)}';

  @override
  Future<void> write(String id, Uint8List bytes) async {
    final response = web.Response(bytes.toJS);
    await (await _cache).put(_key(id).toJS, response).toDart;
  }

  @override
  Future<Uint8List> read(String id) async {
    final response = await (await _cache).match(_key(id).toJS).toDart;
    if (response == null) throw StateError('chat_blob_missing');
    final buffer = (await response.arrayBuffer().toDart).toDart;
    return Uint8List.view(buffer);
  }

  @override
  Future<void> remove(String id) async {
    await (await _cache).delete(_key(id).toJS).toDart;
  }

  @override
  Future<void> clear() async {
    await web.window.caches.delete(_cacheName).toDart;
  }
}

ChatBlobStore createPlatformChatBlobStore(String actor) =>
    WebChatBlobStore(actor);
