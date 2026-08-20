Future<bool> downloadBinaryFile(
  List<int> bytes,
  String fileName,
  String mimeType,
) async => false;

Object? prepareBinaryView() => null;

Future<bool> viewBinaryFile(
  List<int> bytes,
  String fileName,
  String mimeType, {
  Object? preparedView,
}) async => false;
