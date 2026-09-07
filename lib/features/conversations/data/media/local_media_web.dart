import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
Future<String> createLocalMedia(Uint8List bytes, String name, String mime) async =>
    web.URL.createObjectURL(web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime)));
Future<void> releaseLocalMedia(String url) async => web.URL.revokeObjectURL(url);
