import '../entities/assistant_exchange.dart';

abstract interface class AssistantRepository {
  Future<AssistantAnswer> ask(AssistantQuestion question);
}
