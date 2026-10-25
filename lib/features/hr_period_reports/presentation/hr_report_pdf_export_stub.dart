import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<bool> printOrDownloadPdfReport({
  required String htmlContent,
  required String fileName,
}) async {
  try {
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$safeName.html');
    await file.writeAsString(htmlContent);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/html')],
        subject: safeName,
      ),
    );
    return true;
  } catch (_) {
    return false;
  }
}
