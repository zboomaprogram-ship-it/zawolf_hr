import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'chat_database.g.dart';

class ChatLocalRows extends Table {
  TextColumn get actor => text()();
  TextColumn get channel => text()();
  TextColumn get kind => text()();
  TextColumn get id => text()();
  TextColumn get payload => text()();
  @override
  Set<Column<Object>> get primaryKey => {actor, channel, kind, id};
}

class ChatBlobRows extends Table {
  TextColumn get actor => text()();
  TextColumn get id => text()();
  BlobColumn get bytes => blob()();
  @override
  Set<Column<Object>> get primaryKey => {actor, id};
}

@DriftDatabase(tables: [ChatLocalRows, ChatBlobRows])
class ChatDatabase extends _$ChatDatabase {
  ChatDatabase()
    : super(
        driftDatabase(
          name: 'conversations_rich_v1',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );
  ChatDatabase.forTesting(super.executor);
  @override
  int get schemaVersion => 1;
}
