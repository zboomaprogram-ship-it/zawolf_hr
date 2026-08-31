import '../domain/entities/assistant_exchange.dart';
import '../domain/repositories/assistant_repository.dart';

final class LocalAssistantRepository implements AssistantRepository {
  const LocalAssistantRepository();

  static const _refusalTerms = <String>[
    'وافق',
    'ارفض',
    'قرار خصم',
    'احسب راتبي',
    'تشخيص طبي',
    'عاقب',
    'افصل الموظف',
  ];

  static const _corpus = <_HelpEntry>[
    _HelpEntry(
      id: 'attendance-correction',
      terms: ['تصحيح', 'حضور', 'تأخير', 'بصمة'],
      answer:
          'يمكنك فتح تفاصيل الحضور أو نسبة الانضباط، ثم اختيار «طلب تصحيح وقت الحضور». راجع الوقت والسبب قبل الإرسال، وستظهر حالة الطلب في سجل طلباتك.',
    ),
    _HelpEntry(
      id: 'deductions',
      terms: ['خصم', 'خصومات', 'انضباط'],
      answer:
          'افتح صفحة الخصومات لمشاهدة سبب كل خصم وتاريخه ودورته وحالة مراجعته. إذا كان وقت الحضور غير صحيح فاستخدم طلب التصحيح المرتبط بالسجل.',
    ),
    _HelpEntry(
      id: 'requests',
      terms: ['طلب', 'إجازة', 'إذن', 'سلفة', 'مهمة'],
      answer:
          'افتح «طلباتي»، ثم «تقديم طلب جديد»، واختر النوع وأكمل البيانات. يمكنك متابعة مرحلة الموافقة من سجل الطلبات دون إعادة الإرسال.',
    ),
    _HelpEntry(
      id: 'notifications',
      terms: ['إشعار', 'إشعارات', 'تنبيه'],
      answer:
          'افتح مركز الإشعارات من رمز الجرس. عند فتح الإشعار سينقلك النظام إلى السجل المسموح لك فقط، ويمكنك تحديد الكل كمقروء.',
    ),
    _HelpEntry(
      id: 'work-outcomes',
      terms: ['مهمة', 'مهام', 'هدف', 'أداء', 'kpi'],
      answer:
          'من صفحة نتائج العمل يمكنك متابعة المطلوب، إضافة التقدم والدليل، ومعرفة أثر النتيجة على مؤشر الأداء دون إنشاء سجلين منفصلين.',
    ),
  ];

  @override
  Future<AssistantAnswer> ask(AssistantQuestion question) async {
    final text = question.textAr.trim().toLowerCase();
    if (text.length < 3 || text.length > 500) {
      return const AssistantAnswer(
        kind: AssistantAnswerKind.refusal,
        messageAr: 'اكتب سؤالًا مختصرًا عن استخدام النظام.',
      );
    }
    if (_refusalTerms.any(text.contains)) {
      return const AssistantAnswer(
        kind: AssistantAnswerKind.refusal,
        messageAr:
            'لا أستطيع اتخاذ قرار موارد بشرية أو رواتب أو قرار تأديبي. أستطيع شرح خطوات النظام، ويمكنك التواصل مع HR لاتخاذ القرار.',
      );
    }
    for (final entry in _corpus) {
      if (entry.terms.any(text.contains)) {
        return AssistantAnswer(
          kind: AssistantAnswerKind.guidance,
          messageAr: entry.answer,
          sourceIds: [entry.id],
        );
      }
    }
    return const AssistantAnswer(
      kind: AssistantAnswerKind.unavailable,
      messageAr:
          'لم أجد إرشادًا موثوقًا لهذا السؤال. جرّب السؤال عن الحضور أو الطلبات أو الخصومات أو نتائج العمل، أو تواصل مع HR.',
    );
  }
}

final class _HelpEntry {
  const _HelpEntry({
    required this.id,
    required this.terms,
    required this.answer,
  });

  final String id;
  final List<String> terms;
  final String answer;
}
