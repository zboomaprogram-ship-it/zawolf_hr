// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> downloadBinaryFile(
  List<int> bytes,
  String fileName,
  String mimeType,
) async {
  final url = _objectUrl(bytes, mimeType);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return true;
}

Object prepareBinaryView() => html.window.open('', '_blank');

Future<bool> viewBinaryFile(
  List<int> bytes,
  String fileName,
  String mimeType, {
  Object? preparedView,
}) async {
  final url = _objectUrl(bytes, mimeType);
  if (preparedView is html.WindowBase) {
    preparedView.location.href = url;
  } else {
    html.window.open(url, '_blank');
  }
  Timer(const Duration(minutes: 1), () => html.Url.revokeObjectUrl(url));
  return true;
}

String _objectUrl(List<int> bytes, String mimeType) {
  final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
  return html.Url.createObjectUrlFromBlob(blob);
}
