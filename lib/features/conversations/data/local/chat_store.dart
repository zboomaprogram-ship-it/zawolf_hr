import 'dart:convert';
import 'package:drift/drift.dart';
import 'chat_database.dart';
import '../chat_codec.dart';
import 'chat_blob_store.dart';

class ChatStore {
  ChatStore(this.database, this.actor, {ChatBlobStore? blobStore})
    : _blobStore = blobStore;
  final ChatDatabase database;
  final String actor;
  final ChatBlobStore? _blobStore;
  Future<void> put(
    String channel,
    String kind,
    String id,
    Map<String, Object?> payload,
  ) => database
      .into(database.chatLocalRows)
      .insertOnConflictUpdate(
        ChatLocalRowsCompanion.insert(
          actor: actor,
          channel: channel,
          kind: kind,
          id: id,
          payload: jsonEncode(payload),
        ),
      );
  Future<List<Map<String, Object?>>> rows(String channel, String kind) async =>
      (await (database.select(database.chatLocalRows)..where(
            (r) =>
                r.actor.equals(actor) &
                r.channel.equals(channel) &
                r.kind.equals(kind),
          )).get())
          .map((r) => objectMap(jsonDecode(r.payload)))
          .toList();

  Future<List<Map<String, Object?>>> rowsByKind(String kind) async =>
      (await (database.select(database.chatLocalRows)
            ..where((r) => r.actor.equals(actor) & r.kind.equals(kind))).get())
          .map(
            (r) => {
              ...objectMap(jsonDecode(r.payload)),
              '_channel': r.channel,
              '_id': r.id,
            },
          )
          .toList();
  Future<Map<String, Object?>?> get(
    String channel,
    String kind,
    String id,
  ) async {
    final row =
        await (database.select(database.chatLocalRows)..where(
          (r) =>
              r.actor.equals(actor) &
              r.channel.equals(channel) &
              r.kind.equals(kind) &
              r.id.equals(id),
        )).getSingleOrNull();
    return row == null ? null : objectMap(jsonDecode(row.payload));
  }

  Future<void> remove(String channel, String kind, String id) async {
    await (database.delete(database.chatLocalRows)..where(
      (r) =>
          r.actor.equals(actor) &
          r.channel.equals(channel) &
          r.kind.equals(kind) &
          r.id.equals(id),
    )).go();
  }

  Future<void> blob(String id, Uint8List bytes) async {
    if (_blobStore != null) {
      await _blobStore.write(id, bytes);
      await (database.delete(database.chatBlobRows)
        ..where((r) => r.actor.equals(actor) & r.id.equals(id))).go();
      return;
    }
    await database
        .into(database.chatBlobRows)
        .insertOnConflictUpdate(
          ChatBlobRowsCompanion.insert(actor: actor, id: id, bytes: bytes),
        );
  }

  Future<Uint8List> bytes(String id) async {
    if (_blobStore != null) {
      try {
        return await _blobStore.read(id);
      } catch (_) {
        // Lazily move binaries created by older releases out of SQLite. This
        // keeps existing drafts/outbox items recoverable after the migration.
        final legacy =
            await (database.select(database.chatBlobRows)..where(
              (r) => r.actor.equals(actor) & r.id.equals(id),
            )).getSingleOrNull();
        if (legacy == null) rethrow;
        await _blobStore.write(id, legacy.bytes);
        await (database.delete(database.chatBlobRows)
          ..where((r) => r.actor.equals(actor) & r.id.equals(id))).go();
        return legacy.bytes;
      }
    }
    return (await (database.select(database.chatBlobRows)
          ..where((r) => r.actor.equals(actor) & r.id.equals(id))).getSingle())
        .bytes;
  }

  Future<void> removeBlob(String id) async {
    if (_blobStore != null) {
      await _blobStore.remove(id);
    }
    await (database.delete(database.chatBlobRows)
      ..where((r) => r.actor.equals(actor) & r.id.equals(id))).go();
  }

  Future<void> clearActorFiles() async => _blobStore?.clear();

  Future<T> transaction<T>(Future<T> Function() action) =>
      database.transaction(action);
}
