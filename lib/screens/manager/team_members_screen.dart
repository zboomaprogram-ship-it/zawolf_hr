import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/employee_role.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../theme/theme.dart';

class TeamMembersScreen extends StatefulWidget {
  const TeamMembersScreen({super.key});

  @override
  State<TeamMembersScreen> createState() => _TeamMembersScreenState();
}

class _TeamMembersScreenState extends State<TeamMembersScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Future<List<UserModel>>? _teamFuture;

  Future<List<UserModel>> _loadTeam(String managerId) async {
    final results = await Future.wait([
      _db
          .collection('users')
          .where('managerIds', arrayContains: managerId)
          .get(),
      _db.collection('users').where('managerId', isEqualTo: managerId).get(),
    ]);
    final byId = <String, UserModel>{};
    for (final doc in [...results[0].docs, ...results[1].docs]) {
      final employee = UserModel.fromFirestore(doc);
      if (employee.isActive && employee.role != EmployeeRole.superAdmin) {
        byId[employee.uid] = employee;
      }
    }
    final team = byId.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return team;
  }

  void _refresh(String managerId) {
    setState(() => _teamFuture = _loadTeam(managerId));
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AuthService>().currentUser;
    final theme = Theme.of(context);
    if (manager == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
        ),
      );
    }
    _teamFuture ??= _loadTeam(manager.uid);
    return Scaffold(
      appBar: AppBar(
        title: Text('ملفات فريقي', style: theme.textTheme.headlineMedium),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(manager.uid),
          ),
        ],
      ),
      body: FutureBuilder<List<UserModel>>(
        future: _teamFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'تعذر تحميل أعضاء الفريق. تحقق من الصلاحيات أو الاتصال.',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: ZaWolfColors.primaryCyan),
            );
          }
          final team = snapshot.data!;
          if (team.isEmpty) {
            return const Center(
              child: Text('لا يوجد موظفون مسندون إليك حالياً.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(manager.uid),
            color: ZaWolfColors.primaryCyan,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: team.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final employee = team[index];
                return WolfCard(
                  onTap: () => context.go('/manager/employee/${employee.uid}'),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: ZaWolfColors.primaryCyan.withValues(
                          alpha: .15,
                        ),
                        child: Text(
                          employee.displayName.isEmpty
                              ? '?'
                              : employee.displayName[0],
                          style: const TextStyle(
                            color: ZaWolfColors.primaryCyan,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              employee.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${employee.position} · ${employee.department}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'الكود: ${employee.employeeId}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_left,
                        color: ZaWolfColors.primaryCyan,
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
