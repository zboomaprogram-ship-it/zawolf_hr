import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/organization_change_set.dart';
import '../../domain/entities/organization_membership.dart';
import '../../domain/entities/organization_snapshot.dart';
import '../../domain/entities/organization_tree.dart';
import '../../domain/entities/organization_unit.dart';
import '../../domain/repositories/organization_structure_repository.dart';
import '../../domain/repositories/multi_tree_organization_repository.dart';
import '../cubit/organization_editor_cubit.dart';
import '../cubit/organization_hierarchy_cubit.dart';
import '../cubit/organization_manager_picker_cubit.dart';
import '../cubit/organization_membership_cubit.dart';
import '../cubit/organization_tree_selector_cubit.dart';
import '../widgets/interactive_org_node_card.dart';
import '../widgets/organization_change_preview.dart';
import '../widgets/organization_people_picker.dart';
import 'organization_structure_map_page.dart';

final class OrganizationStructureEditorPage extends StatelessWidget {
  const OrganizationStructureEditorPage({
    super.key,
    required this.repository,
    this.canManage = false,
    this.multiTreeEnabled = false,
    this.embedded = false,
  });
  final OrganizationStructureRepository repository;
  final bool canManage;
  final bool multiTreeEnabled;
  final bool embedded;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        // A multi-tree page must wait for the selector to choose a tree.
        // Loading the legacy hierarchy in parallel races that selection and
        // was the reason the embedded departments page could briefly be empty.
        create: (_) {
          final cubit = OrganizationHierarchyCubit(repository);
          if (!multiTreeEnabled) cubit.load();
          return cubit;
        },
      ),
      BlocProvider(create: (_) => OrganizationEditorCubit(repository)),
      BlocProvider(create: (_) => OrganizationManagerPickerCubit(repository)),
      BlocProvider(create: (_) => OrganizationMembershipCubit(repository)),
      if (multiTreeEnabled && repository is MultiTreeOrganizationRepository)
        BlocProvider(
          create: (_) => OrganizationTreeSelectorCubit(
            repository as MultiTreeOrganizationRepository,
          )..load(),
        ),
    ],
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: _OrganizationEditorBody(
        canManage: canManage,
        multiTreeEnabled:
            multiTreeEnabled && repository is MultiTreeOrganizationRepository,
        embedded: embedded,
      ),
    ),
  );
}

final class _OrganizationEditorBody extends StatefulWidget {
  const _OrganizationEditorBody({
    required this.canManage,
    required this.multiTreeEnabled,
    required this.embedded,
  });
  final bool canManage;
  final bool multiTreeEnabled;
  final bool embedded;

  @override
  State<_OrganizationEditorBody> createState() =>
      _OrganizationEditorBodyState();
}

final class _OrganizationEditorBodyState
    extends State<_OrganizationEditorBody> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final content =
        BlocListener<OrganizationEditorCubit, OrganizationEditorState>(
          listener: (context, state) {
            if (state.message != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message!),
                  action: state.status == OrganizationSaveStatus.pendingSync
                      ? SnackBarAction(
                          label: 'تحقق',
                          onPressed: () => context
                              .read<OrganizationEditorCubit>()
                              .checkStatus(),
                        )
                      : null,
                ),
              );
            }
            if (state.status == OrganizationSaveStatus.saved) {
              _reloadSelectedHierarchy(context);
            }
          },
          child: Column(
            children: [
              if (widget.multiTreeEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _OrganizationTreeSelector(canManage: widget.canManage),
                ),
              Expanded(
                child:
                    BlocBuilder<
                      OrganizationHierarchyCubit,
                      OrganizationHierarchyState
                    >(
                      builder: (context, state) => switch (state) {
                        OrganizationHierarchyLoading() => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        OrganizationHierarchyEmpty() => _EmptyOrganization(
                          canManage: widget.canManage,
                          onAdd: widget.canManage
                              ? () => _createUnit(context)
                              : null,
                        ),
                        OrganizationHierarchyFailure(:final message) => Center(
                          child: OutlinedButton.icon(
                            onPressed: () => context
                                .read<OrganizationHierarchyCubit>()
                                .load(),
                            icon: const Icon(Icons.refresh),
                            label: Text(message),
                          ),
                        ),
                        OrganizationHierarchyReady(
                          :final snapshot,
                          :final query,
                        ) =>
                          snapshot.units.isEmpty
                              ? _EmptyOrganization(
                                  canManage: widget.canManage,
                                  onAdd: widget.canManage
                                      ? () => _createUnit(context)
                                      : null,
                                )
                              : _HierarchyContent(
                                  snapshot: snapshot,
                                  query: query,
                                  canManage: widget.canManage,
                                  multiTreeEnabled: widget.multiTreeEnabled,
                                  showArchived: _showArchived,
                                  onToggleArchived: () {
                                    final showArchived = !_showArchived;
                                    setState(
                                      () => _showArchived = showArchived,
                                    );
                                    context
                                        .read<OrganizationHierarchyCubit>()
                                        .load(includeArchived: showArchived);
                                  },
                                ),
                      },
                    ),
              ),
            ],
          ),
        );
    final actions = [
      IconButton(
        tooltip: 'عرض الخريطة التنظيمية',
        onPressed: () {
          final state = context.read<OrganizationHierarchyCubit>().state;
          if (state is! OrganizationHierarchyReady) return;
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  OrganizationStructureMapPage(snapshot: state.snapshot),
            ),
          );
        },
        icon: const Icon(Icons.account_tree_outlined),
      ),
      IconButton(
        tooltip: 'تحديث',
        onPressed: () => _reloadSelectedHierarchy(context),
        icon: const Icon(Icons.refresh),
      ),
    ];
    final fab = widget.canManage
        ? FloatingActionButton.extended(
            onPressed: () => _createUnit(context),
            icon: const Icon(Icons.add),
            label: const Text('إضافة وحدة'),
          )
        : null;
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('إدارة الهيكل الوظيفي'), actions: actions),
      floatingActionButton: fab,
      body: widget.embedded
          ? Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 8, 6),
                    child: Row(
                      children: [
                        Text(
                          'الأشجار التنظيمية',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        ...actions,
                      ],
                    ),
                  ),
                ),
                Expanded(child: content),
              ],
            )
          : content,
    );
  }

  Future<void> _createUnit(BuildContext context) async {
    final name = await _textDialog(
      context,
      title: 'إضافة قطاع',
      label: 'اسم القطاع',
    );
    if (name == null || !context.mounted) return;
    final hierarchyState = context.read<OrganizationHierarchyCubit>().state;
    final selectedTreeId = hierarchyState is OrganizationHierarchyReady
        ? hierarchyState.snapshot.selectedTreeId
        : null;
    await context.read<OrganizationEditorCubit>().apply(
      OrganizationChangeSet(
        operationId: 'org-ui-${DateTime.now().microsecondsSinceEpoch}',
        kind: 'create_unit',
        payload: {
          'type': 'sector',
          'name': name,
          if (selectedTreeId != null) 'treeId': selectedTreeId,
        },
      ),
    );
  }

  void _reloadSelectedHierarchy(BuildContext context) {
    if (widget.multiTreeEnabled) {
      final state = context.read<OrganizationTreeSelectorCubit>().state;
      if (state is OrganizationTreeSelectorReady &&
          state.selectedTreeId != null) {
        context.read<OrganizationHierarchyCubit>().loadTree(
          state.selectedTreeId!,
        );
        return;
      }
    }
    context.read<OrganizationHierarchyCubit>().load(
      includeArchived: _showArchived,
    );
  }
}

final class _HierarchyContent extends StatefulWidget {
  const _HierarchyContent({
    required this.snapshot,
    required this.query,
    required this.canManage,
    required this.multiTreeEnabled,
    required this.showArchived,
    required this.onToggleArchived,
  });
  final OrganizationSnapshot snapshot;
  final String query;
  final bool canManage;
  final bool multiTreeEnabled;
  final bool showArchived;
  final VoidCallback onToggleArchived;

  @override
  State<_HierarchyContent> createState() => _HierarchyContentState();
}

class _HierarchyContentState extends State<_HierarchyContent> {
  bool _isVisualView = true;

  @override
  Widget build(BuildContext context) {
    final normalized = widget.query.toLowerCase();
    final sectors = widget.snapshot.sectors
        .where(
          (sector) =>
              normalized.isEmpty ||
              sector.name.toLowerCase().contains(normalized) ||
              widget.snapshot
                  .departmentsFor(sector.id)
                  .any(
                    (department) =>
                        department.name.toLowerCase().contains(normalized),
                  ),
        )
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth >= 1100 ? constraints.maxWidth : 900,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              LayoutBuilder(
                builder: (context, controls) {
                  final search = TextField(
                    key: const Key('organization-search'),
                    onChanged: context
                        .read<OrganizationHierarchyCubit>()
                        .search,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'بحث بالقطاع أو القسم',
                    ),
                  );
                  final viewToggle = SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.account_tree_outlined),
                        label: Text('الخريطة التنظيمية'),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(
                          Icons.view_list_outlined,
                          key: Key('organization-list-view-toggle'),
                        ),
                        label: Text('إدارة الوحدات'),
                      ),
                    ],
                    selected: {_isVisualView},
                    onSelectionChanged: (selection) {
                      setState(() => _isVisualView = selection.first);
                    },
                  );
                  if (controls.maxWidth < 620) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        search,
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: viewToggle,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 12),
                      viewToggle,
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              if (_isVisualView) ...[
                if (sectors.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('لا توجد نتائج مطابقة.')),
                  )
                else
                  _SnapshotVisualMap(
                    snapshot: widget.snapshot,
                    sectors: sectors,
                    canManage: widget.canManage,
                  ),
                if (widget.multiTreeEnabled && sectors.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'عضويات الموظفين في الشجرة الحالية',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final sector in sectors)
                    for (final department in widget.snapshot.departmentsFor(
                      sector.id,
                    ))
                      ExpansionTile(
                        key: ValueKey('tree-memberships-${department.id}'),
                        initiallyExpanded: true,
                        title: Text('عضويات قسم ${department.name}'),
                        children: _treeMembershipTiles(context, department),
                      ),
                ],
              ] else ...[
                if (widget.canManage)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: widget.onToggleArchived,
                      icon: Icon(
                        widget.showArchived
                            ? Icons.visibility_off
                            : Icons.archive_outlined,
                      ),
                      label: Text(
                        widget.showArchived ? 'إخفاء المؤرشف' : 'عرض المؤرشف',
                      ),
                    ),
                  ),
                if (sectors.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('لا توجد نتائج مطابقة.')),
                  ),
                for (
                  var sectorIndex = 0;
                  sectorIndex < sectors.length;
                  sectorIndex++
                )
                  InteractiveOrgNodeCard(
                    key: ValueKey(sectors[sectorIndex].id),
                    unit: sectors[sectorIndex],
                    canManage: widget.canManage,
                    onRename: () => _rename(context, sectors[sectorIndex]),
                    onArchive: () => _archive(context, sectors[sectorIndex]),
                    onMoveUp: sectorIndex == 0
                        ? null
                        : () => _reorder(
                            context,
                            sectors,
                            sectorIndex,
                            sectorIndex - 1,
                            null,
                          ),
                    onMoveDown: sectorIndex == sectors.length - 1
                        ? null
                        : () => _reorder(
                            context,
                            sectors,
                            sectorIndex,
                            sectorIndex + 1,
                            null,
                          ),
                    children: [
                      for (
                        var departmentIndex = 0;
                        departmentIndex <
                            widget.snapshot
                                .departmentsFor(sectors[sectorIndex].id)
                                .length;
                        departmentIndex++
                      )
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: 24,
                            end: 8,
                          ),
                          child: InteractiveOrgNodeCard(
                            unit: widget.snapshot.departmentsFor(
                              sectors[sectorIndex].id,
                            )[departmentIndex],
                            canManage: widget.canManage,
                            initiallyExpanded: widget.multiTreeEnabled,
                            onRename: () => _rename(
                              context,
                              widget.snapshot.departmentsFor(
                                sectors[sectorIndex].id,
                              )[departmentIndex],
                            ),
                            onArchive: () => _archive(
                              context,
                              widget.snapshot.departmentsFor(
                                sectors[sectorIndex].id,
                              )[departmentIndex],
                            ),
                            onAssignManager: () => _manager(
                              context,
                              widget.snapshot.departmentsFor(
                                sectors[sectorIndex].id,
                              )[departmentIndex],
                            ),
                            onManageMembers: () => _members(
                              context,
                              widget.snapshot.departmentsFor(
                                sectors[sectorIndex].id,
                              )[departmentIndex],
                            ),
                            onRemoveMembers: () => widget.multiTreeEnabled
                                ? _manageTreeMemberships(
                                    context,
                                    widget.snapshot.departmentsFor(
                                      sectors[sectorIndex].id,
                                    )[departmentIndex],
                                  )
                                : _members(
                                    context,
                                    widget.snapshot.departmentsFor(
                                      sectors[sectorIndex].id,
                                    )[departmentIndex],
                                    remove: true,
                                  ),
                            onMoveToSector: () => _moveDepartment(
                              context,
                              widget.snapshot.departmentsFor(
                                sectors[sectorIndex].id,
                              )[departmentIndex],
                              widget.snapshot.sectors,
                            ),
                            onMoveUp: departmentIndex == 0
                                ? null
                                : () => _reorder(
                                    context,
                                    widget.snapshot.departmentsFor(
                                      sectors[sectorIndex].id,
                                    ),
                                    departmentIndex,
                                    departmentIndex - 1,
                                    sectors[sectorIndex].id,
                                  ),
                            onMoveDown:
                                departmentIndex ==
                                    widget.snapshot
                                            .departmentsFor(
                                              sectors[sectorIndex].id,
                                            )
                                            .length -
                                        1
                                ? null
                                : () => _reorder(
                                    context,
                                    widget.snapshot.departmentsFor(
                                      sectors[sectorIndex].id,
                                    ),
                                    departmentIndex,
                                    departmentIndex + 1,
                                    sectors[sectorIndex].id,
                                  ),
                            children: widget.multiTreeEnabled
                                ? _treeMembershipTiles(
                                    context,
                                    widget.snapshot.departmentsFor(
                                      sectors[sectorIndex].id,
                                    )[departmentIndex],
                                  )
                                : const [],
                          ),
                        ),
                      if (widget.canManage)
                        ListTile(
                          leading: const Icon(Icons.add),
                          title: const Text('إضافة قسم'),
                          onTap: () =>
                              _addDepartment(context, sectors[sectorIndex].id),
                        ),
                    ],
                  ),
                if (widget.showArchived) ...[
                  const Divider(height: 32),
                  const Text('الوحدات المؤرشفة'),
                  for (final unit in widget.snapshot.units.where(
                    (item) => item.archived,
                  ))
                    InteractiveOrgNodeCard(
                      unit: unit,
                      canManage: widget.canManage,
                      children: const [],
                      onRestore: () => _restore(context, unit),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addDepartment(BuildContext context, String sectorId) async {
    final name = await _textDialog(
      context,
      title: 'إضافة قسم',
      label: 'اسم القسم',
    );
    if (name == null || !context.mounted) return;
    await _apply(context, 'create_unit', {
      'type': 'department',
      'name': name,
      'parentId': sectorId,
      'treeId': widget.snapshot.units
          .firstWhere((unit) => unit.id == sectorId)
          .treeId,
    });
  }

  Future<void> _rename(BuildContext context, OrganizationUnit unit) async {
    final name = await _textDialog(
      context,
      title: 'إعادة التسمية',
      label: 'الاسم',
      initial: unit.name,
    );
    if (name == null || !context.mounted) return;
    await _apply(context, 'rename_unit', {
      'unitId': unit.id,
      'name': name,
    }, expectedVersion: unit.version);
  }

  Future<void> _moveDepartment(
    BuildContext context,
    OrganizationUnit department,
    List<OrganizationUnit> sectors,
  ) async {
    final destinations = sectors
        .where((sector) => sector.id != department.parentId && !sector.archived)
        .toList(growable: false);
    if (destinations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد قطاع آخر متاح للنقل.')),
      );
      return;
    }
    final destination = await showDialog<OrganizationUnit>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SimpleDialog(
          title: const Text('نقل القسم إلى قطاع'),
          children: [
            for (final sector in destinations)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, sector),
                child: SelectableText(sector.name),
              ),
          ],
        ),
      ),
    );
    if (destination == null || !context.mounted) return;
    await _apply(context, 'move_unit', {
      'unitId': department.id,
      'destinationSectorId': destination.id,
    }, expectedVersion: department.version);
  }

  Future<void> _archive(BuildContext context, OrganizationUnit unit) async {
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('تأكيد الأرشفة'),
            content: const Text(
              'لا يمكن أرشفة وحدة تحتوي موظفين أو أقسامًا نشطة.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('أرشفة'),
              ),
            ],
          ),
        ) ??
        false;
    if (approved && context.mounted) {
      await _apply(context, 'archive_unit', {
        'unitId': unit.id,
      }, expectedVersion: unit.version);
    }
  }

  Future<void> _manager(BuildContext context, OrganizationUnit unit) async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعيين مدير القسم'),
          content: OrganizationPeoplePicker(
            repository: context
                .read<OrganizationManagerPickerCubit>()
                .repository,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, <String>{}),
              child: const Text('ترك المنصب شاغرًا'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    await _apply(context, 'assign_manager', {
      'unitId': unit.id,
      'managerUid': selected.isEmpty ? null : selected.first,
    }, expectedVersion: unit.version);
  }

  Future<void> _members(
    BuildContext context,
    OrganizationUnit unit, {
    bool remove = false,
  }) async {
    final cubit = context.read<OrganizationMembershipCubit>();
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            remove
                ? 'إزالة موظفين من ${unit.name}'
                : 'إضافة أو نقل موظفين إلى ${unit.name}',
          ),
          content: OrganizationPeoplePicker(
            repository: cubit.repository,
            multiSelect: true,
            departmentFilter: remove ? unit.id : null,
            initialSelection: cubit.state.selected,
            onSelectionChanged: cubit.setSelection,
          ),
        ),
      ),
    );
    if (selected == null || selected.isEmpty || !context.mounted) return;
    cubit.setSelection(selected);
    final treeId = widget.snapshot.selectedTreeId;
    if (treeId != null) {
      if (remove) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'إزالة عضوية شجرة تحتاج اختيار العضوية نفسها، وستضاف في الخطوة التالية.',
            ),
          ),
        );
        return;
      }
      final approved =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('إضافة عضويات للشجرة'),
                content: Text(
                  'سيتم ربط ${selected.length} موظف بقسم '
                  '${unit.name}. لن تُحذف عضوياتهم في الأشجار الأخرى.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('تأكيد الإضافة'),
                  ),
                ],
              ),
            ),
          ) ??
          false;
      if (!approved || !context.mounted) return;
      final saved = await context.read<OrganizationEditorCubit>().apply(
        OrganizationChangeSet(
          operationId: 'org-ui-${DateTime.now().microsecondsSinceEpoch}',
          kind: 'tree_membership',
          payload: {
            'treeId': treeId,
            'unitId': unit.id,
            'employeeUids': selected.toList(growable: false),
            'directManagerUid': unit.managerUid,
          },
        ),
      );
      if (saved) cubit.clear();
      return;
    }
    final change = OrganizationChangeSet(
      operationId: 'org-ui-${DateTime.now().microsecondsSinceEpoch}',
      kind: 'membership',
      expectedVersion: unit.version,
      payload: {
        'employeeUids': selected.toList(growable: false),
        'destinationDepartmentId': remove ? null : unit.id,
        'sourceDepartmentId': remove ? unit.id : null,
        'directManagerUid': remove ? null : unit.managerUid,
      },
    );
    final editor = context.read<OrganizationEditorCubit>();
    await editor.prepare(change);
    if (!context.mounted || editor.state.preview == null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: OrganizationChangePreview(preview: editor.state.preview!),
      ),
    );
    if (approved == true && context.mounted) {
      final saved = await editor.apply(change);
      if (saved) cubit.clear();
    }
  }

  List<Widget> _treeMembershipTiles(
    BuildContext context,
    OrganizationUnit unit,
  ) {
    final items = widget.snapshot.memberships
        .where(
          (membership) =>
              membership.active && membership.departmentUnitId == unit.id,
        )
        .toList(growable: false);
    if (items.isEmpty) {
      return const [
        ListTile(
          dense: true,
          leading: Icon(Icons.people_outline),
          title: Text('لا توجد عضويات نشطة في هذا القسم.'),
        ),
      ];
    }
    return [
      for (final membership in items)
        ListTile(
          dense: true,
          leading: Icon(
            membership.isPrimary ? Icons.star : Icons.person_outline,
            color: membership.isPrimary ? Colors.amber : null,
          ),
          title: SelectableText(
            membership.employeeName.trim().isNotEmpty
                ? membership.employeeName
                : membership.employeeUid,
          ),
          subtitle: Text(
            membership.isPrimary
                ? 'العضوية الأساسية'
                : 'عضوية إضافية · ${membership.employeeCode}',
          ),
          trailing: widget.canManage
              ? PopupMenuButton<String>(
                  tooltip: membership.isPrimary
                      ? 'إدارة العضوية الأساسية'
                      : 'إدارة العضوية الإضافية',
                  onSelected: (action) {
                    if (action == 'primary') {
                      _setPrimaryMembership(context, membership);
                    } else if (action == 'remove') {
                      _removeTreeMembership(context, membership);
                    }
                  },
                  itemBuilder: (_) => [
                    if (!membership.isPrimary)
                      const PopupMenuItem(
                        value: 'primary',
                        child: Text('تعيين كعضوية أساسية'),
                      ),
                    if (!membership.isPrimary)
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('إزالة من هذه الشجرة'),
                      ),
                  ],
                )
              : null,
        ),
    ];
  }

  Future<void> _manageTreeMemberships(
    BuildContext context,
    OrganizationUnit unit,
  ) async {
    final count = widget.snapshot.memberships
        .where(
          (membership) =>
              membership.active && membership.departmentUnitId == unit.id,
        )
        .length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'لا توجد عضويات لإزالتها.'
              : 'افتح القسم واختر الموظف ثم استخدم قائمة إدارة العضوية.',
        ),
      ),
    );
  }

  Future<void> _setPrimaryMembership(
    BuildContext context,
    OrganizationMembership membership,
  ) async {
    final id = membership.id;
    if (id == null) return;
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('تغيير العضوية الأساسية'),
              content: const Text(
                'سيُستخدم هذا القسم ومديره لمسارات الطلبات الجديدة فقط. لن تتغير الطلبات القديمة.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('تأكيد'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!approved || !context.mounted) return;
    await _apply(context, 'primary_tree_membership', {
      'membershipId': id,
    }, expectedVersion: membership.version);
  }

  Future<void> _removeTreeMembership(
    BuildContext context,
    OrganizationMembership membership,
  ) async {
    final id = membership.id;
    if (id == null || membership.isPrimary) return;
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('إزالة عضوية الشجرة'),
              content: const Text(
                'ستُزال العضوية من هذه الشجرة فقط، وتبقى عضويات الموظف الأخرى دون تغيير.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('تأكيد الإزالة'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!approved || !context.mounted) return;
    await _apply(context, 'archive_tree_membership', {
      'membershipId': id,
    }, expectedVersion: membership.version);
  }

  Future<void> _restore(BuildContext context, OrganizationUnit unit) => _apply(
    context,
    'restore_unit',
    {'unitId': unit.id},
    expectedVersion: unit.version,
  );

  Future<void> _reorder(
    BuildContext context,
    List<OrganizationUnit> units,
    int from,
    int to,
    String? parentId,
  ) async {
    final ordered = units.map((item) => item.id).toList(growable: true);
    final moved = ordered.removeAt(from);
    ordered.insert(to, moved);
    await _apply(context, 'reorder', {
      'parentId': parentId,
      'orderedIds': ordered,
    });
  }

  Future<void> _apply(
    BuildContext context,
    String kind,
    Map<String, Object?> payload, {
    int? expectedVersion,
  }) => context.read<OrganizationEditorCubit>().apply(
    OrganizationChangeSet(
      operationId: 'org-ui-${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      payload: payload,
      expectedVersion: expectedVersion,
    ),
  );
}

final class _OrganizationTreeSelector extends StatelessWidget {
  const _OrganizationTreeSelector({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<
        OrganizationTreeSelectorCubit,
        OrganizationTreeSelectorState
      >(
        listenWhen: (previous, current) =>
            current is OrganizationTreeSelectorReady &&
            (previous is! OrganizationTreeSelectorReady ||
                previous.selectedTreeId != current.selectedTreeId),
        listener: (context, state) {
          if (state is! OrganizationTreeSelectorReady) return;
          final hierarchy = context.read<OrganizationHierarchyCubit>();
          final selectedTreeId = state.selectedTreeId;
          if (selectedTreeId == null) {
            hierarchy.showEmpty();
            return;
          }
          hierarchy.loadTree(selectedTreeId);
        },
        builder: (context, state) => switch (state) {
          OrganizationTreeSelectorLoading() => const LinearProgressIndicator(),
          OrganizationTreeSelectorFailure() => OutlinedButton.icon(
            onPressed: context.read<OrganizationTreeSelectorCubit>().load,
            icon: const Icon(Icons.refresh),
            label: const Text('تعذر تحميل الأشجار التنظيمية'),
          ),
          OrganizationTreeSelectorReady(:final trees, :final selectedTreeId) =>
            LayoutBuilder(
              builder: (context, constraints) {
                final selector = _treeDropdown(context, trees, selectedTreeId);
                final actions = _treeActions(context, trees, selectedTreeId);
                if (constraints.maxWidth < 700) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      selector,
                      if (canManage) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: actions,
                        ),
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: selector),
                    if (canManage) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: actions,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
        },
      );

  Widget _treeDropdown(
    BuildContext context,
    List<OrganizationTree> trees,
    String? selectedTreeId,
  ) => DropdownButtonFormField<String>(
    key: const Key('organization-tree-selector'),
    initialValue: selectedTreeId,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'الشجرة التنظيمية',
      prefixIcon: Icon(Icons.account_tree_outlined),
    ),
    items: [
      for (final tree in trees)
        DropdownMenuItem(
          value: tree.id,
          child: Text(
            '${tree.name}${tree.isDefault ? ' · الأساسية' : ''}'
            '${tree.status == OrganizationTreeStatus.archived
                ? ' · مؤرشفة'
                : tree.status == OrganizationTreeStatus.draft
                ? ' · مسودة'
                : ''}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: (value) {
      if (value != null) {
        context.read<OrganizationTreeSelectorCubit>().select(value);
      }
    },
  );

  Widget _treeActions(
    BuildContext context,
    List<OrganizationTree> trees,
    String? selectedTreeId,
  ) {
    final selectedTree = selectedTreeId != null
        ? trees.firstWhere(
            (t) => t.id == selectedTreeId,
            orElse: () => trees.first,
          )
        : null;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          key: const Key('organization-create-tree-with-ceo'),
          onPressed: () =>
              _createTreeWithNewCeo(context, trees, selectedTreeId),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('هيكل جديد بـ CEO'),
        ),
        if (selectedTree != null && !selectedTree.isDefault)
          IconButton.outlined(
            tooltip: 'حذف / أرشفة هذا الهيكل',
            style: IconButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
            ),
            onPressed: () => _archiveTree(context, selectedTree),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        OutlinedButton.icon(
          onPressed: () => _bootstrapLegacyHierarchy(context),
          icon: const Icon(Icons.system_update_alt_outlined),
          label: const Text('تهيئة الهيكل الحالي'),
        ),
        OutlinedButton.icon(
          onPressed: () => _createTree(
            context,
            source: selectedTreeId == null
                ? null
                : trees.firstWhere((tree) => tree.id == selectedTreeId),
          ),
          icon: const Icon(Icons.add),
          label: const Text('شجرة فارغة'),
        ),
        PopupMenuButton<String>(
          tooltip: 'إدارة الشجرة',
          enabled: selectedTreeId != null,
          onSelected: (action) {
            final tree = trees.firstWhere((item) => item.id == selectedTreeId);
            switch (action) {
              case 'clone':
                _cloneTree(context, tree);
                break;
              case 'leadership':
                _manageLeadership(context, tree);
                break;
              case 'activate':
                _activateTree(context, tree);
                break;
              case 'archive':
                _archiveTree(context, tree);
                break;
            }
          },
          itemBuilder: (context) {
            if (selectedTreeId == null) return const [];
            final tree = trees.firstWhere((item) => item.id == selectedTreeId);
            return [
              const PopupMenuItem(value: 'clone', child: Text('نسخ الشجرة')),
              const PopupMenuItem(
                value: 'leadership',
                child: Text('المدير الأعلى ومديرو الشجرة'),
              ),
              if (tree.status != OrganizationTreeStatus.active)
                const PopupMenuItem(
                  value: 'activate',
                  child: Text('تفعيل / استعادة'),
                ),
              if (tree.status == OrganizationTreeStatus.active &&
                  !tree.isDefault)
                const PopupMenuItem(value: 'archive', child: Text('أرشفة')),
            ];
          },
          icon: const Icon(Icons.more_vert),
        ),
      ],
    );
  }

  Future<void> _createTreeWithNewCeo(
    BuildContext context,
    List<OrganizationTree> trees,
    String? selectedTreeId,
  ) async {
    final name = await _textDialog(
      context,
      title: 'إنشاء هيكل جديد بـ CEO جديد',
      label: 'اسم الهيكل التنظيمي الجديد',
      initial: 'هيكل وظيفي جديد',
    );
    if (name == null || !context.mounted) return;

    final repository = context
        .read<OrganizationManagerPickerCubit>()
        .repository;
    final root = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اختر المدير الأعلى / CEO الهيكل الجديد'),
          content: OrganizationPeoplePicker(
            repository: repository,
            initialSelection: const {},
          ),
        ),
      ),
    );
    if (root == null || root.isEmpty || !context.mounted) return;
    final newCeoUid = root.first;

    final sourceTree = selectedTreeId != null
        ? trees.firstWhere(
            (t) => t.id == selectedTreeId,
            orElse: () => trees.first,
          )
        : trees.first;

    final approved =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('تأكيد إنشاء الهيكل التلقائي'),
              content: Text(
                'سيتم إنشاء "$name" برئاسة CEO الجديد.\n\n'
                'سيتم نسخ جميع القطاعات والأقسام والمديرين وعضويات الموظفين تلقائياً من "${sourceTree.name}" كعضويات إضافية، دون تغيير عضوياتهم الأساسية أو مسارات الطلبات الحالية.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('إنشاء الهيكل'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!approved || !context.mounted) return;

    final selector = context.read<OrganizationTreeSelectorCubit>();
    try {
      final preview = await selector.previewLegacyBootstrap();
      if (preview.hasChanges) {
        await selector.applyLegacyBootstrap(preview.fingerprint);
        await selector.load();
      }
    } catch (_) {}

    if (!context.mounted) return;
    final treeId = 'tree-${DateTime.now().microsecondsSinceEpoch}';
    final saved = await context.read<OrganizationEditorCubit>().apply(
      OrganizationChangeSet(
        operationId: 'org-ui-${DateTime.now().microsecondsSinceEpoch}',
        kind: 'clone_tree',
        payload: {
          'sourceTreeId': sourceTree.id,
          'id': treeId,
          'name': name,
          'rootLeaderUid': newCeoUid,
          'copyMemberships': true,
        },
      ),
    );
    if (!saved || !context.mounted) return;
    await selector.load();
    if (context.mounted) selector.select(treeId);
  }

  Future<void> _bootstrapLegacyHierarchy(BuildContext context) async {
    final selector = context.read<OrganizationTreeSelectorCubit>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final preview = await selector.previewLegacyBootstrap();
      if (!context.mounted) return;
      if (!preview.hasChanges) {
        messenger.showSnackBar(
          const SnackBar(content: Text('الهيكل الحالي تمت تهيئته بالفعل.')),
        );
        return;
      }
      final approved =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('تهيئة الهيكل الحالي'),
                content: Text(
                  'سيتم نسخ البيانات القديمة بشكل إضافي فقط: '
                  '${preview.legacyUnits + preview.units} وحدة، '
                  '${preview.memberships} عضوية موظف، و${preview.users} ملف مستخدم.\n\n'
                  'لن يتم حذف بيانات، ولن تتغير الشجرة الأساسية أو مسارات الطلبات.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('نسخ وتهيئة'),
                  ),
                ],
              ),
            ),
          ) ??
          false;
      if (!approved || !context.mounted) return;
      await selector.applyLegacyBootstrap(preview.fingerprint);
      if (!context.mounted) return;
      await selector.load();
      messenger.showSnackBar(
        const SnackBar(content: Text('تمت تهيئة الهيكل الحالي بنجاح.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تعذر تهيئة الهيكل الآن. أعد المحاولة بعد لحظات.'),
        ),
      );
    }
  }

  Future<void> _createTree(
    BuildContext context, {
    required OrganizationTree? source,
  }) async {
    final name = await _textDialog(
      context,
      title: 'إنشاء شجرة تنظيمية',
      label: 'اسم الشجرة',
    );
    if (name == null || !context.mounted) return;
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('تأكيد إنشاء الشجرة'),
              content: Text(
                source == null
                    ? 'سيتم إنشاء "$name" كمسودة فارغة. '
                          'لن تتغير أي عضوية أو طلب قديم.'
                    : 'سيتم نسخ الأقسام والوحدات من "${source.name}" تلقائياً '
                          'إلى "$name" كمسودة مستقلة، مع المديرين وعضويات الموظفين '
                          'كعضويات إضافية فقط. لن تتغير الشجرة الحالية أو مسارات الطلبات.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('إنشاء'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!approved || !context.mounted) return;
    final treeId = 'tree-${DateTime.now().microsecondsSinceEpoch}';
    final saved = await context.read<OrganizationEditorCubit>().apply(
      OrganizationChangeSet(
        operationId: 'org-ui-${DateTime.now().microsecondsSinceEpoch}',
        kind: source == null ? 'create_tree' : 'clone_tree',
        payload: source == null
            ? {'id': treeId, 'name': name}
            : {
                'sourceTreeId': source.id,
                'id': treeId,
                'name': name,
                'rootLeaderUid': source.rootLeaderUid,
                'copyMemberships': true,
              },
      ),
    );
    if (!saved || !context.mounted) return;
    final selector = context.read<OrganizationTreeSelectorCubit>();
    await selector.load();
    if (context.mounted) selector.select(treeId);
  }

  Future<void> _archiveTree(BuildContext context, OrganizationTree tree) async {
    if (tree.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن أرشفة الشجرة الأساسية.')),
      );
      return;
    }
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text('أرشفة ${tree.name}'),
              content: const Text(
                'يمنع النظام الأرشفة إذا كانت للشجرة عضويات نشطة.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('أرشفة'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!approved || !context.mounted) return;
    final saved = await context.read<OrganizationEditorCubit>().apply(
      OrganizationChangeSet(
        operationId: 'org-ui-${DateTime.now().microsecondsSinceEpoch}',
        kind: 'archive_tree',
        expectedVersion: tree.version,
        payload: {'treeId': tree.id},
      ),
    );
    if (!saved || !context.mounted) return;
    await context.read<OrganizationTreeSelectorCubit>().load();
  }

  Future<void> _cloneTree(BuildContext context, OrganizationTree source) async {
    final name = await _textDialog(
      context,
      title: 'نسخ ${source.name}',
      label: 'اسم الشجرة الجديدة',
      initial: 'نسخة من ${source.name}',
    );
    if (name == null || !context.mounted) return;
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('تأكيد نسخ الهيكل'),
              content: const Text(
                'سيتم نسخ القطاعات والأقسام والمديرين كمسودة مستقلة. '
                'وسيظهر الموظفون فيها كعضويات إضافية فقط؛ لن يتغير المدير أو المسار الرئيسي أو الطلبات الحالية.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('إنشاء النسخة'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!approved || !context.mounted) return;
    final treeId = 'tree-${DateTime.now().microsecondsSinceEpoch}';
    final saved = await context.read<OrganizationEditorCubit>().apply(
      OrganizationChangeSet(
        operationId: 'org-ui-${DateTime.now().microsecondsSinceEpoch}',
        kind: 'clone_tree',
        payload: {
          'sourceTreeId': source.id,
          'id': treeId,
          'name': name,
          'rootLeaderUid': source.rootLeaderUid,
          'copyMemberships': true,
        },
      ),
    );
    if (!saved || !context.mounted) return;
    final selector = context.read<OrganizationTreeSelectorCubit>();
    await selector.load();
    if (context.mounted) selector.select(treeId);
  }

  Future<void> _activateTree(
    BuildContext context,
    OrganizationTree tree,
  ) async {
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text('تفعيل ${tree.name}'),
              content: const Text(
                'سيصبح هذا الهيكل متاحاً فوراً، دون تغيير الشجرة الأساسية أو مسارات الطلبات القديمة.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('تفعيل'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!approved || !context.mounted) return;
    final saved = await context.read<OrganizationEditorCubit>().apply(
      OrganizationChangeSet(
        operationId: 'org-ui-${DateTime.now().microsecondsSinceEpoch}',
        kind: 'activate_tree',
        expectedVersion: tree.version,
        payload: {'treeId': tree.id},
      ),
    );
    if (saved && context.mounted) {
      await context.read<OrganizationTreeSelectorCubit>().load();
    }
  }

  Future<void> _manageLeadership(
    BuildContext context,
    OrganizationTree tree,
  ) async {
    final repository = context
        .read<OrganizationManagerPickerCubit>()
        .repository;
    final root = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اختر المدير الأعلى'),
          content: OrganizationPeoplePicker(
            repository: repository,
            initialSelection: {
              if (tree.rootLeaderUid != null) tree.rootLeaderUid!,
            },
          ),
        ),
      ),
    );
    if (root == null || root.isEmpty || !context.mounted) return;
    final admins = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اختر مديري الشجرة'),
          content: OrganizationPeoplePicker(
            repository: repository,
            multiSelect: true,
            initialSelection: tree.treeAdminUids.toSet(),
          ),
        ),
      ),
    );
    if (admins == null || !context.mounted) return;
    final saved = await context.read<OrganizationEditorCubit>().apply(
      OrganizationChangeSet(
        operationId: 'org-ui-${DateTime.now().microsecondsSinceEpoch}',
        kind: 'tree_leadership',
        expectedVersion: tree.version,
        payload: {
          'treeId': tree.id,
          'rootLeaderUid': root.first,
          'treeAdminUids': admins.toList(growable: false),
        },
      ),
    );
    if (saved && context.mounted) {
      await context.read<OrganizationTreeSelectorCubit>().load();
    }
  }
}

final class _EmptyOrganization extends StatelessWidget {
  const _EmptyOrganization({required this.canManage, this.onAdd});
  final bool canManage;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          canManage ? 'ابدأ بإضافة أول قطاع.' : 'لا توجد وحدات تنظيمية متاحة.',
        ),
        if (onAdd != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('organization-empty-add-sector'),
            onPressed: onAdd,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('إضافة أول قطاع'),
          ),
        ],
      ],
    ),
  );
}

Future<String?> _textDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  bool allowEmpty = false,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (allowEmpty || value.length >= 2) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
  // showDialog completes before its closing transition has fully detached the
  // TextField. Defer disposal so the route never rebuilds with a dead controller.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  return result;
}

class _SnapshotVisualMap extends StatelessWidget {
  const _SnapshotVisualMap({
    required this.snapshot,
    required this.sectors,
    required this.canManage,
  });

  final OrganizationSnapshot snapshot;
  final List<OrganizationUnit> sectors;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    if (sectors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xFF0F2B33),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
          ),
        ),
        child: const Center(
          child: Text(
            'لا توجد قطاعات في هذا الهيكل حتى الآن.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    final tree = snapshot.trees.firstWhere(
      (t) => t.id == snapshot.selectedTreeId,
      orElse: () => snapshot.trees.isNotEmpty
          ? snapshot.trees.first
          : const OrganizationTree(
              id: 'default',
              name: 'الهيكل الوظيفي',
              isDefault: true,
              status: OrganizationTreeStatus.active,
              version: 1,
            ),
    );

    final rootMembership = snapshot.memberships.firstWhere(
      (m) => m.employeeUid == tree.rootLeaderUid,
      orElse: () => snapshot.memberships.isNotEmpty
          ? snapshot.memberships.first
          : const OrganizationMembership(
              id: 'root',
              treeId: 'default',
              departmentUnitId: 'default',
              employeeUid: 'root',
              employeeName: 'المدير التنفيذي / CEO',
              employeeCode: 'CEO-100',
              isPrimary: true,
            ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1C22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          // Top CEO Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF133B47), Color(0xFF0A222A)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.workspace_premium,
                      color: Color(0xFFFFD700),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        rootMembership.employeeName.isNotEmpty
                            ? rootMembership.employeeName
                            : 'سامي المتولي التولي',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'المدير التنفيذي (CEO) · ${tree.name}',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Vertical Line
          Container(width: 2, height: 24, color: const Color(0xFF00E5FF)),
          // Horizontal Connector Bar
          Container(
            height: 2,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 40),
            color: const Color(0xFF00E5FF),
          ),
          const SizedBox(height: 16),
          // Sectors Columns
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final sector in sectors) ...[
                  Container(
                    width: 280,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2B33),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        // Sector Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFF163E4A),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: Semantics(
                            label: 'قطاع ${sector.name}',
                            container: true,
                            child: ExcludeSemantics(
                              child: Text(
                                sector.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Department Cards
                        for (final dept in snapshot.departmentsFor(
                          sector.id,
                        )) ...[
                          Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF08181E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(
                                  0xFF00E5FF,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        dept.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF00E5FF,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${snapshot.memberships.where((m) => m.departmentUnitId == dept.id).length}',
                                        style: const TextStyle(
                                          color: Color(0xFF00E5FF),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'أعضاء الفريق:',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                for (final member in snapshot.memberships.where(
                                  (m) => m.departmentUnitId == dept.id,
                                ))
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.person_outline,
                                          size: 14,
                                          color: Color(0xFF00E5FF),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            member.employeeName.isNotEmpty
                                                ? member.employeeName
                                                : member.employeeUid,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
