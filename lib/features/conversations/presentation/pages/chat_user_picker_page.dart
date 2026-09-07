import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/rich_chat_repository.dart';
import '../cubit/chat_user_picker_cubit.dart';
import '../widgets/chat_feedback.dart';

Future<List<String>?> pickChatUsers(BuildContext context, RichChatRepository repository, {required List<String> selected, Set<String> locked = const {}}) => Navigator.of(context).push<List<String>>(MaterialPageRoute(builder: (_) => ChatUserPickerPage(repository: repository, selected: selected, locked: locked)));

class ChatUserPickerPage extends StatelessWidget {
  const ChatUserPickerPage({super.key, required this.repository, required this.selected, this.locked = const {}});
  final RichChatRepository repository;
  final List<String> selected;
  final Set<String> locked;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ChatUserPickerCubit(repository, selected.toSet(), locked: locked)..load(),
    child: Directionality(textDirection: TextDirection.rtl, child: BlocBuilder<ChatUserPickerCubit, ChatUserPickerState>(builder: (context, state) {
      final cubit = context.read<ChatUserPickerCubit>();
      final names = {for (final user in state.users) user.id: user.name};
      return Scaffold(
        appBar: AppBar(title: const Text('اختيار الزملاء'), actions: [TextButton(onPressed: state.selected.length < 2 ? null : () => Navigator.pop(context, state.selected.toList()), child: Text('تم (${state.selected.length}/100)'))]),
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: Column(children: [
          Padding(padding: const EdgeInsets.all(12), child: TextField(decoration: const InputDecoration(labelText: 'البحث بالاسم', prefixIcon: Icon(Icons.search)), onSubmitted: (query) => cubit.load(query: query))),
          if (state.selected.isNotEmpty) SizedBox(height: 54, child: ListView(scrollDirection: Axis.horizontal, children: state.selected.map((id) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: InputChip(label: Text(names[id] ?? (id == repository.actorId ? 'أنت' : id)), onDeleted: locked.contains(id) ? null : () => cubit.remove(id)))).toList())),
          if (state.error != null) ChatFeedback(text: chatErrorText(state.error!), onRetry: () => cubit.load(query: state.query)),
          if (state.loading) const LinearProgressIndicator(),
          Expanded(child: state.users.isEmpty && !state.loading ? const Center(child: Text('لا يوجد زملاء مطابقون')) : ListView.builder(itemCount: state.users.length + (state.cursor == null ? 0 : 1), itemBuilder: (context, index) {
            if (index == state.users.length) return TextButton(onPressed: state.loading ? null : () => cubit.load(query: state.query, more: true), child: const Text('تحميل المزيد'));
            final user = state.users[index];
            return CheckboxListTile(value: state.selected.contains(user.id), onChanged: locked.contains(user.id) ? null : (_) => cubit.toggle(user.id), title: Text(user.name), subtitle: user.department.isEmpty ? null : Text(user.department));
          })),
        ]))),
      );
    })),
  );
}
