import 'chat_blob_store.dart';

/// Browser builds retain the existing Drift/IndexedDB adapter until the OPFS
/// adapter is enabled. This keeps web compatible while native builds stop
/// writing large values into SQLite.
ChatBlobStore? createPlatformChatBlobStore(String actor) => null;
