import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_button.dart';
import '../../components/wolf_card.dart';
import '../../components/wolf_input_field.dart';
import '../../models/employee_role.dart';
import '../../services/auth_service.dart';
import '../../services/poll_service.dart';
import '../../theme/theme.dart';

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key});

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  final _db = FirebaseFirestore.instance;
  final _service = PollService();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _optionOne = TextEditingController();
  final _optionTwo = TextEditingController();
  final _selectedUsers = <String>{};
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _users = [];
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot = await _db
          .collection('users')
          .where('isActive', isEqualTo: true)
          .get();
      if (!mounted) return;
      setState(() {
        _users = snapshot.docs
            .where((doc) => doc.data()['role'] != EmployeeRole.superAdmin)
            .toList();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _optionOne.dispose();
    _optionTwo.dispose();
    super.dispose();
  }

  Future<void> _chooseRecipients() async {
    final selected = Set<String>.from(_selectedUsers);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, updateSheet) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .78,
            child: Column(
              children: [
                ListTile(
                  title: const Text('المشاركون في التصويت'),
                  subtitle: Text('تم اختيار ${selected.length}'),
                  trailing: TextButton(
                    onPressed: () => updateSheet(() {
                      if (selected.length == _users.length) {
                        selected.clear();
                      } else {
                        selected
                          ..clear()
                          ..addAll(_users.map((user) => user.id));
                      }
                    }),
                    child: Text(
                      selected.length == _users.length
                          ? 'إلغاء الكل'
                          : 'تحديد الكل',
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return CheckboxListTile(
                        value: selected.contains(user.id),
                        title: Text(user.data()['displayName'] ?? 'موظف'),
                        subtitle: Text(user.data()['employeeId'] ?? ''),
                        onChanged: (value) => updateSheet(() {
                          value == true
                              ? selected.add(user.id)
                              : selected.remove(user.id);
                        }),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedUsers
                          ..clear()
                          ..addAll(selected);
                      });
                      Navigator.pop(sheetContext);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('تأكيد'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _publish(String userId) async {
    setState(() => _publishing = true);
    try {
      await _service.createPoll(
        createdBy: userId,
        title: _title.text,
        description: _description.text,
        options: [_optionOne.text, _optionTwo.text],
        targetUserIds: _selectedUsers.toList(),
      );
      _title.clear();
      _description.clear();
      _optionOne.clear();
      _optionTwo.clear();
      setState(_selectedUsers.clear);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نشر التصويت وإرسال الإشعارات.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final canManage = EmployeeRole.isHr(user.role);
    Query<Map<String, dynamic>> query = _db.collection('polls');
    if (!canManage) {
      query = query.where('targetUserIds', arrayContains: user.uid);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('التصويتات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (canManage) ...[
            WolfCard(
              child: Column(
                children: [
                  WolfInputField(
                    controller: _title,
                    labelText: 'عنوان التصويت',
                    hintText: 'مثال: موعد اليوم الترفيهي',
                  ),
                  const SizedBox(height: 12),
                  WolfInputField(
                    controller: _description,
                    labelText: 'التفاصيل',
                    hintText: 'اكتب تفاصيل الفعالية أو السؤال',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  WolfInputField(
                    controller: _optionOne,
                    labelText: 'الخيار الأول',
                  ),
                  const SizedBox(height: 12),
                  WolfInputField(
                    controller: _optionTwo,
                    labelText: 'الخيار الثاني',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _chooseRecipients,
                    icon: const Icon(Icons.groups_outlined),
                    label: Text(
                      _selectedUsers.isEmpty
                          ? 'اختيار الموظفين'
                          : 'المحددون: ${_selectedUsers.length}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  WolfButton(
                    onPressed: () => _publish(user.uid),
                    text: 'نشر التصويت',
                    secondaryText: 'PUBLISH POLL',
                    loading: _publishing,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            canManage ? 'التصويتات والنتائج' : 'شارك برأيك',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('تعذر تحميل التصويتات.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final polls = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  final left = a.data()['createdAt'] as Timestamp?;
                  final right = b.data()['createdAt'] as Timestamp?;
                  return (right?.millisecondsSinceEpoch ?? 0).compareTo(
                    left?.millisecondsSinceEpoch ?? 0,
                  );
                });
              if (polls.isEmpty) return const Text('لا توجد تصويتات حالياً.');
              return Column(
                children: [
                  for (final poll in polls)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PollCard(
                        poll: poll,
                        userId: user.uid,
                        canManage: canManage,
                        service: _service,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  const _PollCard({
    required this.poll,
    required this.userId,
    required this.canManage,
    required this.service,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> poll;
  final String userId;
  final bool canManage;
  final PollService service;

  @override
  Widget build(BuildContext context) {
    final data = poll.data();
    final options = List<Map<String, dynamic>>.from(data['options'] as List);
    final open = data['status'] == 'open';
    final votes = poll.reference.collection('votes');
    return WolfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            data['title'] ?? '',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          if ((data['description'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(data['description']),
          ],
          const SizedBox(height: 12),
          if (canManage)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: votes.snapshots(),
              builder: (context, snapshot) {
                final voteDocs = snapshot.data?.docs ?? const [];
                return Column(
                  children: [
                    for (final option in options)
                      ListTile(
                        dense: true,
                        title: Text(option['label'] ?? ''),
                        trailing: Text(
                          '${voteDocs.where((vote) => vote.data()['optionId'] == option['id']).length} صوت',
                          style: const TextStyle(
                            color: ZaWolfColors.primaryCyan,
                          ),
                        ),
                      ),
                    Text('إجمالي المشاركات: ${voteDocs.length}'),
                  ],
                );
              },
            )
          else
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: votes.doc(userId).snapshots(),
              builder: (context, snapshot) {
                final selected = snapshot.data?.data()?['optionId'];
                return IgnorePointer(
                  ignoring: !open || selected != null,
                  child: RadioGroup<String>(
                    groupValue: selected as String?,
                    onChanged: (value) async {
                      if (value == null || !open || selected != null) return;
                      try {
                        await service.vote(
                          pollId: poll.id,
                          userId: userId,
                          optionId: value,
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('$error')));
                      }
                    },
                    child: Column(
                      children: [
                        for (final option in options)
                          RadioListTile<String>(
                            value: option['id'] as String,
                            title: Text(option['label'] ?? ''),
                          ),
                        if (selected != null)
                          const Text(
                            'تم تسجيل صوتك.',
                            style: TextStyle(color: ZaWolfColors.success),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (canManage && open) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => service.closePoll(poll.id),
              icon: const Icon(Icons.lock_outline),
              label: const Text('إغلاق التصويت'),
            ),
          ],
        ],
      ),
    );
  }
}
