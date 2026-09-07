import 'dart:convert';
import 'package:drift/drift.dart';
import 'chat_database.dart';
import '../chat_codec.dart';

class ChatStore {
  ChatStore(this.database, this.actor);
  final ChatDatabase database;
  final String actor;
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

  Future<void> blob(String id, Uint8List bytes) => database
      .into(database.chatBlobRows)
      .insertOnConflictUpdate(
        ChatBlobRowsCompanion.insert(actor: actor, id: id, bytes: bytes),
      );
  Future<Uint8List> bytes(String id) async =>
      (await (database.select(
            database.chatBlobRows,
          )..where((r) => r.actor.equals(actor) & r.id.equals(id))).getSingle())
          .bytes;
  Future<void> removeBlob(String id) async {
    await (database.delete(database.chatBlobRows)
      ..where((r) => r.actor.equals(actor) & r.id.equals(id))).go();
  }

  Future<T> transaction<T>(Future<T> Function() action) =>
      database.transaction(action);
}
