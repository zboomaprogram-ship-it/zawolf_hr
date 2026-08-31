import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/employee_role.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../theme/theme.dart';
import '../../design_system/components/rtl_navigation.dart';
import '../../design_system/components/feedback_states.dart'
    show EmptyState, ErrorState;
import '../../design_system/components/skeletons.dart' show SkeletonList;

class TeamMembersScreen extends StatefulWidget {
  const TeamMembersScreen({super.key});

  @override
  State<TeamMembersScreen> createState() => _TeamMembersScreenState();
}

class _TeamMembersScreenState extends State<TeamMembersScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Future<List<UserModel>>? _teamFuture;

  Future<List<UserModel>> _loadTeam(UserModel reviewer) async {
    if (reviewer.role == EmployeeRole.teamLeader) {
      final snapshot = await _db
          .collection('users')
          .where('teamLeaderId', isEqualTo: reviewer.uid)
          .get();
      final team =
          snapshot.docs
              .map(UserModel.fromFirestore)
              .where((employee) => employee.isActive)
              .toList()
            ..sort((a, b) => a.displayName.compareTo(b.displayName));
      return team;
    }

    final results = await Future.wait([
      _db
          .collection('users')
          .where('managerIds', arrayContains: reviewer.uid)
          .get(),
      _db.collection('users').where('managerId', isEqualTo: reviewer.uid).get(),
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

  void _refresh(UserModel reviewer) {
    setState(() => _teamFuture = _loadTeam(reviewer));
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
    _teamFuture ??= _loadTeam(manager);
    return Scaffold(
      appBar: AppBar(
        title: Text('ملفات فريقي', style: theme.textTheme.headlineMedium),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(manager),
          ),
        ],
      ),
      body: FutureBuilder<List<UserModel>>(
        future: _teamFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorState(
              message: 'تعذر تحميل أعضاء الفريق. تحقق من الصلاحيات أو الاتصال.',
              onRetry: () => _refresh(manager),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonList(itemCount: 5, itemHeight: 84),
            );
          }
          final team = snapshot.data!;
          if (team.isEmpty) {
            return const EmptyState(
              title: 'لا يوجد موظفون مسندون إليك حالياً.',
              icon: Icons.group_off_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(manager),
            color: ZaWolfColors.primaryCyan,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: team.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final employee = team[index];
                return WolfCard(
                  onTap: () => context.go(
                    manager.role == EmployeeRole.teamLeader
                        ? '/team-leader/employee/${employee.uid}'
                        : '/manager/employee/${employee.uid}',
                  ),
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
                      Icon(
                        RtlNavigation.chevronEnd(context),
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
