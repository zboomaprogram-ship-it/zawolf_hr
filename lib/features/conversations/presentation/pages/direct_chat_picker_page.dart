import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/rich_chat.dart';
import '../../domain/repositories/rich_chat_repository.dart';
import '../cubit/chat_direct_picker_cubit.dart';
import '../widgets/chat_feedback.dart';

class DirectChatPickerPage extends StatefulWidget {
  const DirectChatPickerPage({super.key, required this.repository});
  final RichChatRepository repository;

  @override
  State<DirectChatPickerPage> createState() => _DirectChatPickerPageState();
}

class _DirectChatPickerPageState extends State<DirectChatPickerPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ChatDirectPickerCubit(widget.repository)..loadDepartments(),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: BlocBuilder<ChatDirectPickerCubit, ChatDirectPickerState>(
        builder: (context, state) {
          final cubit = context.read<ChatDirectPickerCubit>();
          final isSearching = state.searchQuery.isNotEmpty;

          return Scaffold(
            appBar: AppBar(title: const Text('محادثة خاصة')),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        controller: _searchController,
                        onChanged: cubit.search,
                        decoration: InputDecoration(
                          hintText: 'بحث بالاسم أو القسم...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    _searchController.clear();
                                    cubit.search('');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    if (state.loading) const LinearProgressIndicator(),
                    if (state.error != null)
                      ChatFeedback(
                        text: chatErrorText(state.error!),
                        onRetry: isSearching
                            ? () => cubit.search(_searchController.text)
                            : state.selectedDepartment == null
                                ? cubit.loadDepartments
                                : () => cubit.chooseDepartment(
                                      state.selectedDepartment!,
                                    ),
                      ),
                    if (isSearching) ...[
                      if (!state.loading && state.contacts.isEmpty && state.error == null)
                        const Expanded(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'لا يوجد موظفون مطابقون أو مسموح بمراسلتهم وفق سياسة التواصل.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: state.contacts.length,
                            itemBuilder: (context, index) {
                              final user = state.contacts[index];
                              return ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person_outline),
                                ),
                                title: Text(user.name),
                                subtitle: Text(
                                  user.department.isEmpty ? 'موظف' : user.department,
                                ),
                                onTap: () => _start(context, user),
                              );
                            },
                          ),
                        ),
                    ] else if (state.selectedDepartment == null) ...[
                      Expanded(
                        child: ListView(
                          children: [
                            for (final department in state.departments)
                              ListTile(
                                leading: const Icon(Icons.business_outlined),
                                title: Text(department.name),
                                trailing: Text('${department.eligibleCount}'),
                                onTap: () => cubit.chooseDepartment(department.id),
                              ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            cubit.loadDepartments();
                          },
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
      final channel = await widget.repository.startDirect(user.id);
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
