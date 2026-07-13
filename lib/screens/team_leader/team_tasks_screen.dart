import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../theme/theme.dart';

class TeamLeaderTasksScreen extends StatefulWidget {
  const TeamLeaderTasksScreen({super.key});

  @override
  State<TeamLeaderTasksScreen> createState() => _TeamLeaderTasksScreenState();
}

class _TeamLeaderTasksScreenState extends State<TeamLeaderTasksScreen> {
  final _db = FirebaseFirestore.instance;
  Future<List<EmployeeTaskModel>>? _future;

  Future<List<EmployeeTaskModel>> _load(String leaderId) async {
    final members = await _db
        .collection('users')
        .where('teamLeaderId', isEqualTo: leaderId)
        .get();
    final ids = members.docs
        .map(UserModel.fromFirestore)
        .where((user) => user.isActive)
        .map((user) => user.uid)
        .toList();
    if (ids.isEmpty) return [];

    final snapshots = await Future.wait(
      ids.map(
        (id) =>
            _db.collection('tasks').where('assigneeId', isEqualTo: id).get(),
      ),
    );
    final tasks =
        snapshots
            .expand((snapshot) => snapshot.docs)
            .map(EmployeeTaskModel.fromFirestore)
            .toList()
          ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return tasks;
  }

  void _reload(String uid) => setState(() => _future = _load(uid));

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _future ??= _load(user.uid);
    return Scaffold(
      appBar: AppBar(
        title: const Text('مهام الفريق'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => _reload(user.uid),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<EmployeeTaskModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('تعذر تحميل مهام الفريق.'));
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            );
          }
          final tasks = snapshot.data!;
          if (tasks.isEmpty) {
            return const Center(child: Text('لا توجد مهام لأعضاء الفريق.'));
          }
          return RefreshIndicator(
            color: ZaWolfColors.primaryCyan,
            onRefresh: () async => _reload(user.uid),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return WolfCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        task.title,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${task.assigneeName} · ${TaskStatus.arabicLabel(task.status)}',
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الموعد: ${DateFormat('yyyy/MM/dd - hh:mm a').format(task.dueDate)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: ZaWolfColors.textMuted),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
