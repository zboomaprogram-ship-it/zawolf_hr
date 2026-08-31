import 'package:flutter_test/flutter_test.dart';
import 'package:zawolf_hr/features/assistant/data/local_assistant_repository.dart';
import 'package:zawolf_hr/features/assistant/domain/entities/assistant_exchange.dart';

void main() {
  const repository = LocalAssistantRepository();

  test(
    'answers Arabic system guidance from the local allowlisted corpus',
    () async {
      final answer = await repository.ask(
        const AssistantQuestion(
          textAr: 'كيف أرسل طلب تصحيح الحضور؟',
          operationId: 'help-1',
        ),
      );

      expect(answer.kind, AssistantAnswerKind.guidance);
      expect(answer.messageAr, contains('طلب تصحيح'));
      expect(answer.sourceIds, contains('attendance-correction'));
    },
  );

  test('refuses payroll and HR decisions', () async {
    final answer = await repository.ask(
      const AssistantQuestion(
        textAr: 'احسب راتبي ووافق على قرار خصم',
        operationId: 'help-2',
      ),
    );

    expect(answer.kind, AssistantAnswerKind.refusal);
    expect(answer.messageAr, contains('لا أستطيع'));
  });

  test('unknown questions fail safely without invented policy', () async {
    final answer = await repository.ask(
      const AssistantQuestion(
        textAr: 'سؤال غير موجود في الدليل الداخلي',
        operationId: 'help-3',
      ),
    );

    expect(answer.kind, AssistantAnswerKind.unavailable);
    expect(answer.sourceIds, isEmpty);
  });
}
