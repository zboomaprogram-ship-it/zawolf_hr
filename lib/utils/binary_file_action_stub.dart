import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<bool> downloadBinaryFile(
  List<int> bytes,
  String fileName,
  String mimeType,
) => _shareBinaryFile(bytes, fileName, mimeType);

Object? prepareBinaryView() => null;

Future<bool> viewBinaryFile(
  List<int> bytes,
  String fileName,
  String mimeType, {
  Object? preparedView,
}) => _shareBinaryFile(bytes, fileName, mimeType);

Future<bool> _shareBinaryFile(
  List<int> bytes,
  String fileName,
  String mimeType,
) async {
  try {
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/${safeName.isEmpty ? 'conversation_attachment' : safeName}',
    );
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        subject: safeName,
      ),
    );
    return true;
  } catch (_) {
    return false;
  }
}
