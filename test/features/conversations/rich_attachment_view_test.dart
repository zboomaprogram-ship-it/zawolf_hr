import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/conversations/domain/entities/rich_chat.dart';
import 'package:zawolf_hr/features/conversations/domain/repositories/chat_media_gateway.dart';
import 'package:zawolf_hr/features/conversations/presentation/widgets/rich_attachment_view.dart';

class _MediaGateway implements ChatMediaGateway {
  @override
  Future<bool> copyImage(ChatDraftFile file) async => true;
  @override
  Future<String> localMediaUrl(ChatDraftFile file) async => '';
  @override
  Future<List<ChatDraftFile>> pickFiles() async => [];
  @override
  Future<ChatDraftFile?> recordVideo() async => null;
  @override
  Future<void> release(String url) async {}
  @override
  Future<void> save(ChatDraftFile file) async {}
  @override
  Future<void> share(ChatDraftFile file, {double? x, double? y}) async {}
}

void main() {
  testWidgets(
    'documents, spreadsheets, archives, and unknown files use readable dark cards',
    (tester) async {
      final gateway = _MediaGateway();
      final cases = [
        (
          'sheet.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'جدول بيانات',
        ),
        (
          'letter.docx',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'مستند',
        ),
        ('archive.zip', 'application/zip', 'ملف مضغوط'),
        ('binary.dat', 'application/octet-stream', 'ملف'),
      ];
      for (final item in cases) {
        final file = ChatDraftFile(
          fileName: item.$1,
          mimeType: item.$2,
          bytes: Uint8List.fromList([1, 2, 3]),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: RichAttachmentView(
              key: ValueKey(item.$1),
              attachment: RichAttachment(
                resourceId: item.$1,
                fileName: item.$1,
                mimeType: item.$2,
                sizeBytes: 3,
              ),
              download: () async => file,
              gateway: gateway,
            ),
          ),
        );
        await tester.tap(find.text('تحميل ومعاينة المرفق'));
        await tester.pumpAndSettle();
        expect(find.text(item.$3), findsOneWidget);
        expect(
          find.text('احفظ أو شارك لفتحه في التطبيق المناسب.'),
          findsOneWidget,
        );
      }
    },
  );
}
