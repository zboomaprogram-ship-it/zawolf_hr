enum AssistantAnswerKind { guidance, refusal, unavailable }

final class AssistantQuestion {
  const AssistantQuestion({required this.textAr, required this.operationId});

  final String textAr;
  final String operationId;
}

final class AssistantAnswer {
  const AssistantAnswer({
    required this.kind,
    required this.messageAr,
    this.sourceIds = const <String>[],
  });

  final AssistantAnswerKind kind;
  final String messageAr;
  final List<String> sourceIds;
}
