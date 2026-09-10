import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';
import '../cubit/chat_direct_picker_cubit.dart';
import '../widgets/chat_feedback.dart';

class DirectChatPickerPage extends StatelessWidget {
  const DirectChatPickerPage({super.key, required this.repository});
  final RichChatRepository repository;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ChatDirectPickerCubit(repository)..loadDepartments(),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: BlocBuilder<ChatDirectPickerCubit, ChatDirectPickerState>(
        builder: (context, state) {
          final cubit = context.read<ChatDirectPickerCubit>();
          return Scaffold(
            appBar: AppBar(title: const Text('محادثة خاصة')),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    if (state.loading) const LinearProgressIndicator(),
                    if (state.error != null)
                      ChatFeedback(
                        text: chatErrorText(state.error!),
                        onRetry:
                            state.selectedDepartment == null
                                ? cubit.loadDepartments
                                : () => cubit.chooseDepartment(
                                  state.selectedDepartment!,
                                ),
                      ),
                    if (state.selectedDepartment == null)
                      Expanded(
                        child: ListView(
                          children: [
                            for (final department in state.departments)
                              ListTile(
                                leading: const Icon(Icons.business_outlined),
                                title: Text(department.name),
                                trailing: Text('${department.eligibleCount}'),
                                onTap:
                                    () => cubit.chooseDepartment(department.id),
                              ),
                          ],
                        ),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextButton.icon(
                          onPressed: cubit.loadDepartments,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('تغيير القسم'),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          children: [
                            for (final user in state.contacts)
                              ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person_outline),
                                ),
                                title: Text(user.name),
                                subtitle: Text(user.department),
                                onTap: () => _start(context, user),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Future<void> _start(BuildContext context, ChatUser user) async {
    try {
      final channel = await repository.startDirect(user.id);
      if (context.mounted) Navigator.pop(context, channel);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(chatErrorText(error.toString()))),
        );
      }
    }
  }
}
