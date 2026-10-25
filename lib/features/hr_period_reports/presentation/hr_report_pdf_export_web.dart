import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<bool> printOrDownloadPdfReport({
  required String htmlContent,
  required String fileName,
}) async {
  try {
    final bytes = Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(htmlContent),
    ]);
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final printWindow = web.window.open(url, '_blank');
    if (printWindow != null) {
      Future.delayed(const Duration(milliseconds: 600), () {
        printWindow.print();
      });
      return true;
    }
  } catch (_) {}

  // Fallback: download file
  try {
    final bytes = Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(htmlContent),
    ]);
    final encoded = base64Encode(bytes);
    web.HTMLAnchorElement()
      ..href = 'data:text/html;charset=utf-8;base64,$encoded'
      ..download = '$fileName.html'
      ..click();
    return true;
  } catch (_) {
    return false;
  }
}

