import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'chat_blob_store.dart';

class NativeChatBlobStore implements ChatBlobStore {
  NativeChatBlobStore(this.actor, {Future<Directory> Function()? rootProvider})
    : _rootProvider = rootProvider ?? getApplicationSupportDirectory;

  final String actor;
  final Future<Directory> Function() _rootProvider;
  Future<Directory>? _root;

  String _safe(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');

  Future<Directory> _directory() =>
      _root ??= () async {
        final support = await _rootProvider();
        final directory = Directory(
          '${support.path}/chat_files/${_safe(actor)}',
        );
        if (!await directory.exists()) await directory.create(recursive: true);
        return directory;
      }();

  Future<File> _file(String id) async =>
      File('${(await _directory()).path}/${_safe(id)}.bin');

  @override
  Future<void> write(String id, Uint8List bytes) async {
    final target = await _file(id);
    final temporary = File('${target.path}.part');
    await temporary.writeAsBytes(bytes, flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  @override
  Future<Uint8List> read(String id) async => (await _file(id)).readAsBytes();

  @override
  Future<void> remove(String id) async {
    final file = await _file(id);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> clear() async {
    final directory = await _directory();
    if (await directory.exists()) await directory.delete(recursive: true);
    _root = null;
  }
}

ChatBlobStore createPlatformChatBlobStore(String actor) =>
    NativeChatBlobStore(actor);
