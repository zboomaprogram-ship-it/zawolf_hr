import 'dart:typed_data';

/// Binary storage boundary for chat drafts, outbox files, and downloaded media.
/// Metadata remains in Drift; production native builds use sandboxed files.
abstract interface class ChatBlobStore {
  Future<void> write(String id, Uint8List bytes);
  Future<Uint8List> read(String id);
  Future<void> remove(String id);
  Future<void> clear();
}
