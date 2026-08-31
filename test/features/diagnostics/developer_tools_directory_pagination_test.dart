import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'developer tools directory paginates instead of truncating employees',
    () {
      final source = File(
        'lib/features/diagnostics/data/'
        'firestore_developer_tools_directory_repository.dart',
      ).readAsStringSync();

      expect(source, contains('.orderBy(FieldPath.documentId)'));
      expect(source, contains('startAfterDocument(cursor)'));
      expect(source, contains('while (documents.length <'));
      expect(source, isNot(contains("collection('users').limit(300)")));
      expect(source, isNot(contains("['isActive'] != false")));
      expect(source, contains("data['email']"));
    },
  );
}
