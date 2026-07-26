import 'dart:convert';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<bool> downloadCsvFile(String contents, String fileName) async {
  final bytes = Uint8List.fromList([
    0xEF,
    0xBB,
    0xBF,
    ...utf8.encode(contents),
  ]);
  final encoded = base64Encode(bytes);
  web.HTMLAnchorElement()
    ..href = 'data:text/csv;charset=utf-8;base64,$encoded'
    ..download = '$fileName.csv'
    ..click();
  return true;
}
