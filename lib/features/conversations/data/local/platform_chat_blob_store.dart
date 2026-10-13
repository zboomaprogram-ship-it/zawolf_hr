export 'platform_chat_blob_store_stub.dart'
    if (dart.library.io) 'platform_chat_blob_store_native.dart'
    if (dart.library.js_interop) 'platform_chat_blob_store_web.dart';
