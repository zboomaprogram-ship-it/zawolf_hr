import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/assistant_exchange.dart';
import '../cubit/employee_assistant_cubit.dart';

final class EmployeeAssistantPage extends StatefulWidget {
  const EmployeeAssistantPage({required this.cubit, super.key});

  final EmployeeAssistantCubit cubit;

  @override
  State<EmployeeAssistantPage> createState() => _EmployeeAssistantPageState();
}

final class _EmployeeAssistantPageState extends State<EmployeeAssistantPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: widget.cubit,
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مساعد الموظف')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'يساعدك في استخدام النظام فقط، ولا يصدر قرارات HR أو الرواتب.',
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child:
                          BlocBuilder<
                            EmployeeAssistantCubit,
                            EmployeeAssistantState
                          >(
                            builder: (context, state) {
                              if (state.status ==
                                  EmployeeAssistantStatus.asking) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final answer = state.answer;
                              if (state.status ==
                                  EmployeeAssistantStatus.unavailable) {
                                return const _AnswerCard(
                                  icon: Icons.cloud_off_outlined,
                                  text: 'الخدمة غير متاحة الآن. حاول مرة أخرى.',
                                );
                              }
                              if (answer == null) {
                                return const _AnswerCard(
                                  icon: Icons.support_agent,
                                  text:
                                      'اسأل عن الحضور أو الطلبات أو الخصومات أو نتائج العمل.',
                                );
                              }
                              return _AnswerCard(
                                icon:
                                    answer.kind == AssistantAnswerKind.guidance
                                    ? Icons.auto_awesome_outlined
                                    : Icons.info_outline,
                                text: answer.messageAr,
                              );
                            },
                          ),
                    ),
                    TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'اكتب سؤالك',
                        prefixIcon: Icon(Icons.question_answer_outlined),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.send),
                      label: const Text('إرسال'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.cubit.ask(text);
  }
}

final class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38),
          const SizedBox(height: 12),
          SelectableText(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
