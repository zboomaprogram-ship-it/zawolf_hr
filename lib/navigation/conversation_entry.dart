import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/sync/authenticated_operation_client.dart';
import '../features/conversations/data/conversation_repository_impl.dart';
import '../features/conversations/domain/entities/conversation.dart';
import '../features/conversations/presentation/pages/department_chat_channel_page.dart';

final class ConversationEntry extends StatefulWidget {
  const ConversationEntry({
    super.key,
    required this.channelId,
    this.channelName,
  });

  final String channelId;
  final String? channelName;

  @override
  State<ConversationEntry> createState() => _ConversationEntryState();
}

final class _ConversationEntryState extends State<ConversationEntry> {
  late final http.Client _httpClient;
  late final ConversationRepositoryImpl _repository;
  late Future<_DepartmentChatBootstrap> _bootstrap;

  @override
  void initState() {
    super.initState();
    _httpClient = http.Client();
    _repository = ConversationRepositoryImpl(
      operationClient: AuthenticatedOperationClient(
        client: _httpClient,
        tokenProvider: () async =>
            FirebaseAuth.instance.currentUser?.getIdToken(),
      ),
      operationsBaseUri: Uri.parse('https://notification.zawolf.ai'),
    );
    _bootstrap = _load(widget.channelId);
  }

  Future<_DepartmentChatBootstrap> _load(String requestedDepartment) async {
    if (requestedDepartment == 'manager-channel') {
      final conversation = await _repository.openManagerChannel();
      return _DepartmentChatBootstrap(
        conversation: conversation,
        department: 'قناة المديرين',
        departments: const [],
      );
    }
    final departments = await _repository.listAvailableDepartments();
    if (departments.isEmpty) throw StateError('department_not_assigned');
    final matching = departments.where(
      (value) =>
          value.trim().toLowerCase() ==
          requestedDepartment.trim().toLowerCase(),
    );
    final selected = matching.isNotEmpty ? matching.first : departments.first;
    final conversation = await _repository.openDepartmentChannel(selected);
    return _DepartmentChatBootstrap(
      conversation: conversation,
      department: selected,
      departments: departments,
    );
  }

  void _selectDepartment(String department) {
    setState(() => _bootstrap = _load(department));
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return FutureBuilder<_DepartmentChatBootstrap>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.forum_outlined, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'تعذر فتح قناة القسم. تأكد من ربط حسابك بقسم نشط.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _selectDepartment(widget.channelId),
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final data = snapshot.data!;
        return DepartmentChatChannelPage(
          key: ValueKey(data.conversation.id),
          channelId: data.conversation.id,
          channelName: widget.channelName ?? 'شات قسم ${data.department}',
          currentUserId: user.uid,
          repository: _repository,
          availableDepartments: data.departments,
          selectedDepartment: data.department,
          onDepartmentSelected: _selectDepartment,
        );
      },
    );
  }
}

final class _DepartmentChatBootstrap {
  const _DepartmentChatBootstrap({
    required this.conversation,
    required this.department,
    required this.departments,
  });

  final Conversation conversation;
  final String department;
  final List<String> departments;
}
