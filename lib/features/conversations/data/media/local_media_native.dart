import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
Future<String> createLocalMedia(Uint8List bytes, String name, String mime) async {
  final directory = await Directory('${(await getTemporaryDirectory()).path}/chat_media').create(recursive: true);
  final file = File('${directory.path}/${DateTime.now().microsecondsSinceEpoch}_${name.replaceAll(RegExp(r"[^a-zA-Z0-9_.-]"), "_")}');
  await file.writeAsBytes(bytes, flush: true);
  return file.uri.toString();
}
Future<void> releaseLocalMedia(String url) async {
  final file = File.fromUri(Uri.parse(url));
  if (await file.exists()) await file.delete();
}
