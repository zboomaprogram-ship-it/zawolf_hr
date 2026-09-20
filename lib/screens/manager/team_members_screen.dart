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
import '../../features/profile_images/presentation/employee_avatar.dart';

class TeamMembersScreen extends StatefulWidget {
  const TeamMembersScreen({super.key});

  @override
  State<TeamMembersScreen> createState() => _TeamMembersScreenState();
}

class _TeamMembersScreenState extends State<TeamMembersScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  Future<List<UserModel>>? _teamFuture;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<UserModel>> _loadTeam(UserModel reviewer) async {
    if (reviewer.role == EmployeeRole.teamLeader) {
      final snapshot =
          await _db
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
    final team =
        byId.values.toList()
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          return Scaffold(
            appBar: AppBar(
              leading:
                  Navigator.canPop(context)
                      ? IconButton(
                        icon: Icon(RtlNavigation.backIcon(context)),
                        tooltip: 'رجوع',
                        onPressed: () => Navigator.pop(context),
                      )
                      : null,
              title: Text('ملفات فريقي', style: theme.textTheme.headlineMedium),
              actions: [
                IconButton(
                  tooltip: 'تحديث',
                  icon: const Icon(
                    Icons.refresh,
                    color: ZaWolfColors.primaryCyan,
                  ),
                  onPressed: () => _refresh(manager),
                ),
              ],
            ),
            body: FutureBuilder<List<UserModel>>(
              future: _teamFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorState(
                    message:
                        'تعذر تحميل أعضاء الفريق. تحقق من الصلاحيات أو الاتصال.',
                    onRetry: () => _refresh(manager),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: SkeletonList(itemCount: 5, itemHeight: 84),
                  );
                }
                final allMembers = snapshot.data!;
                if (allMembers.isEmpty) {
                  return const EmptyState(
                    title: 'لا يوجد موظفون مسندون إليك حالياً.',
                    icon: Icons.group_off_outlined,
                  );
                }

                final query = _searchController.text.trim().toLowerCase();
                final members =
                    allMembers.where((emp) {
                      if (query.isEmpty) return true;
                      return emp.displayName.toLowerCase().contains(query) ||
                          emp.employeeId.toLowerCase().contains(query) ||
                          emp.department.toLowerCase().contains(query) ||
                          emp.position.toLowerCase().contains(query);
                    }).toList();

                return RefreshIndicator(
                  onRefresh: () async => _refresh(manager),
                  color: ZaWolfColors.primaryCyan,
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 24 : 16,
                      vertical: 16,
                    ),
                    children: [
                      // Top header & search bar
                      if (isDesktop)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: ZaWolfColors.surface01,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ZaWolfColors.surface03),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.search, size: 20),
                                    hintText:
                                        'ابحث بالاسم، كود الموظف، أو القسم...',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: ZaWolfColors.primaryCyan.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: ZaWolfColors.primaryCyan.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.group,
                                      color: ZaWolfColors.primaryCyan,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'إجمالي الفريق: ${allMembers.length} موظف',
                                      style: const TextStyle(
                                        color: ZaWolfColors.primaryCyan,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search, size: 20),
                                  hintText: 'بحث بالاسم أو الكود...',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: ZaWolfColors.surface01,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: ZaWolfColors.surface03,
                                ),
                              ),
                              child: Text(
                                '${members.length}',
                                style: const TextStyle(
                                  color: ZaWolfColors.primaryCyan,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Member cards
                      if (members.isEmpty)
                        WolfCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.person_search,
                                  size: 48,
                                  color: ZaWolfColors.textMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'لا يوجد أعضاء يطابقون البحث',
                                  style: theme.textTheme.titleMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (isDesktop)
                        _buildDesktopMembersGrid(
                          context,
                          manager,
                          members,
                          constraints.maxWidth,
                        )
                      else
                        ...members.map(
                          (employee) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildMemberCard(context, manager, employee),
                          ),
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

  Widget _buildDesktopMembersGrid(
    BuildContext context,
    UserModel manager,
    List<UserModel> members,
    double maxWidth,
  ) {
    final columnCount = maxWidth >= 1350 ? 3 : 2;
    final columns = List.generate(columnCount, (_) => <UserModel>[]);
    for (var i = 0; i < members.length; i++) {
      columns[i % columnCount].add(members[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < columnCount; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(
            child: Column(
              children:
                  columns[i]
                      .map(
                        (emp) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildMemberCard(context, manager, emp),
                        ),
                      )
                      .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMemberCard(
    BuildContext context,
    UserModel manager,
    UserModel employee,
  ) {
    final theme = Theme.of(context);

    return WolfCard(
      onTap:
          () => context.go(
            manager.role == EmployeeRole.teamLeader
                ? '/team-leader/employee/${employee.uid}'
                : '/manager/employee/${employee.uid}',
          ),
      child: Row(
        children: [
          EmployeeAvatar(
            name: employee.displayName,
            photoUrl: employee.photoURL,
            size: 44,
            ringColor: ZaWolfColors.primaryCyan,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        employee.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (employee.employeeId.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ZaWolfColors.surface02,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: ZaWolfColors.surface03),
                        ),
                        child: Text(
                          '#${employee.employeeId}',
                          style: const TextStyle(
                            color: ZaWolfColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${employee.position} · ${employee.department}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ZaWolfColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            RtlNavigation.chevronEnd(context),
            color: ZaWolfColors.primaryCyan,
            size: 20,
          ),
        ],
      ),
    );
  }
}
