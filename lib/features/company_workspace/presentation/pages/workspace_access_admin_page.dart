import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/workspace_access_grant.dart';
import '../../domain/entities/workspace_capability.dart';
import '../../domain/entities/workspace_pilot_configuration.dart';
import '../cubit/workspace_access_admin_cubit.dart';
import '../widgets/workspace_sync_status_banner.dart';
import '../widgets/access/department_folder_assignment_panel.dart';

class WorkspaceAccessAdminPage extends StatefulWidget {
  const WorkspaceAccessAdminPage({super.key});

  @override
  State<WorkspaceAccessAdminPage> createState() =>
      _WorkspaceAccessAdminPageState();
}

class _WorkspaceAccessAdminPageState extends State<WorkspaceAccessAdminPage> {
  final _resource = TextEditingController();
  final _subject = TextEditingController();
  WorkspaceGrantScope _scope = WorkspaceGrantScope.employee;
  WorkspaceCapability _capability = WorkspaceCapability.view;
  WorkspaceGrantEffect _effect = WorkspaceGrantEffect.allow;

  @override
  void dispose() {
    _resource.dispose();
    _subject.dispose();
    super.dispose();
  }

  void _load() => context.read<WorkspaceAccessAdminCubit>().loadGrants(
    _resource.text.trim(),
  );

  void _grant() {
    final resourceId = _resource.text.trim();
    final subjectId = _subject.text.trim();
    if (resourceId.isEmpty || subjectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل معرّف الملف أو المجلد والمستفيد أولاً.'),
        ),
      );
      return;
    }
    context.read<WorkspaceAccessAdminCubit>().createGrant(
      WorkspaceAccessGrant(
        id: '',
        resourceId: resourceId,
        scope: _scope,
        subjectId: subjectId,
        capability: _capability,
        isActive: true,
        updatedAt: DateTime.now().toUtc(),
        effect: _effect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('إدارة وصول ملفات الشركة'),
        actions: [
          IconButton(
            tooltip: 'تجربة V2 والتراجع',
            icon: const Icon(Icons.rocket_launch_outlined),
            onPressed: _showPilotConfiguration,
          ),
          IconButton(
            tooltip: 'تعيين مجلد موظف لقسم',
            icon: const Icon(Icons.account_tree_outlined),
            onPressed: _showDepartmentAssignment,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocBuilder<WorkspaceAccessAdminCubit, WorkspaceAccessAdminState>(
          builder: (context, state) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state is WorkspaceAccessAdminReady && state.message != null)
                WorkspaceSyncStatusBanner(
                  message: state.message!,
                  kind: state.isError
                      ? WorkspaceSyncStatusKind.failure
                      : WorkspaceSyncStatusKind.saved,
                  onAction: _load,
                  actionLabel: state.isError
                      ? 'إعادة المحاولة'
                      : 'تحديث الصلاحيات',
                ),
              if (state is WorkspaceAccessAdminFailure)
                WorkspaceSyncStatusBanner(
                  key: const ValueKey('workspace-access-error'),
                  message: state.message,
                  kind: WorkspaceSyncStatusKind.failure,
                  onAction: _load,
                  actionLabel: 'إعادة المحاولة',
                ),
              const Text(
                'امنح صلاحية دقيقة لملف أو مجلد. يقبل الموظف بريده أو كوده أو UID، وتبقى كل التغييرات مسجلة في التدقيق.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('موظف: عرض فقط'),
                    selected:
                        _scope == WorkspaceGrantScope.employee &&
                        _capability == WorkspaceCapability.view &&
                        _effect == WorkspaceGrantEffect.allow,
                    onSelected: (_) => setState(() {
                      _scope = WorkspaceGrantScope.employee;
                      _capability = WorkspaceCapability.view;
                      _effect = WorkspaceGrantEffect.allow;
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('موظف: تعديل'),
                    selected:
                        _scope == WorkspaceGrantScope.employee &&
                        _capability == WorkspaceCapability.edit &&
                        _effect == WorkspaceGrantEffect.allow,
                    onSelected: (_) => setState(() {
                      _scope = WorkspaceGrantScope.employee;
                      _capability = WorkspaceCapability.edit;
                      _effect = WorkspaceGrantEffect.allow;
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('قسم: تعديل'),
                    selected:
                        _scope == WorkspaceGrantScope.department &&
                        _capability == WorkspaceCapability.edit &&
                        _effect == WorkspaceGrantEffect.allow,
                    onSelected: (_) => setState(() {
                      _scope = WorkspaceGrantScope.department;
                      _capability = WorkspaceCapability.edit;
                      _effect = WorkspaceGrantEffect.allow;
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('موظف: منع'),
                    selected:
                        _scope == WorkspaceGrantScope.employee &&
                        _effect == WorkspaceGrantEffect.deny,
                    onSelected: (_) => setState(() {
                      _scope = WorkspaceGrantScope.employee;
                      _capability = WorkspaceCapability.view;
                      _effect = WorkspaceGrantEffect.deny;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 340,
                    child: TextField(
                      controller: _resource,
                      decoration: const InputDecoration(
                        labelText: 'معرّف الملف أو المجلد',
                        hintText: 'انسخه من تفاصيل المورد في مركز الملفات',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _subject,
                      decoration: InputDecoration(
                        labelText: _subjectLabel,
                        hintText: _subjectHint,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<WorkspaceGrantScope>(
                      initialValue: _scope,
                      isExpanded: true,
                      items: WorkspaceGrantScope.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                _scopeLabel(value),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _scope = value!),
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<WorkspaceCapability>(
                      initialValue: _capability,
                      isExpanded: true,
                      items: WorkspaceCapability.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                _capabilityLabel(value),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _capability = value!),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<WorkspaceGrantEffect>(
                      initialValue: _effect,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'نوع القاعدة',
                      ),
                      items: WorkspaceGrantEffect.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                _effectLabel(value),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _effect = value!),
                    ),
                  ),
                  FilledButton(
                    onPressed: _grant,
                    child: const Text('منح الوصول'),
                  ),
                  OutlinedButton(
                    onPressed: _load,
                    child: const Text('عرض الصلاحيات'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context
                        .read<WorkspaceAccessAdminCubit>()
                        .importSource(),
                    icon: const Icon(Icons.sync),
                    label: const Text('مزامنة Google Drive'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (state is WorkspaceAccessAdminLoading)
                const LinearProgressIndicator(),
              if (state is WorkspaceAccessAdminReady)
                Expanded(
                  child: ListView.builder(
                    itemCount: state.grants.length,
                    itemBuilder: (context, index) {
                      final grant = state.grants[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            '${_scopeLabel(grant.scope)}: ${grant.subjectId}',
                          ),
                          subtitle: Text(
                            '${_effectLabel(grant.effect)} · ${_capabilityLabel(grant.capability)} · ${grant.isActive ? 'نشطة' : 'مسحوبة'}',
                          ),
                          trailing: grant.isActive
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.person_remove_outlined,
                                  ),
                                  tooltip: 'سحب الوصول',
                                  onPressed: () => context
                                      .read<WorkspaceAccessAdminCubit>()
                                      .revoke(grant.id),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  String get _subjectLabel => switch (_scope) {
    WorkspaceGrantScope.employee => 'بريد الموظف أو كود الموظف أو UID',
    WorkspaceGrantScope.department => 'اسم أو رمز القسم',
    WorkspaceGrantScope.team => 'معرّف الفريق',
    WorkspaceGrantScope.role => 'الدور الوظيفي',
    WorkspaceGrantScope.resource => 'معرّف مورد مرتبط',
  };

  String get _subjectHint => switch (_scope) {
    WorkspaceGrantScope.employee => 'مثال: name@company.com أو BD-1208',
    WorkspaceGrantScope.department => 'مثال: Sales أو BD',
    WorkspaceGrantScope.team => 'مثال: sales-team-1',
    WorkspaceGrantScope.role => 'مثال: manager أو employee',
    WorkspaceGrantScope.resource => 'معرّف المورد الذي يرث الوصول',
  };

  static String _scopeLabel(WorkspaceGrantScope value) => switch (value) {
    WorkspaceGrantScope.employee => 'موظف محدد',
    WorkspaceGrantScope.team => 'فريق',
    WorkspaceGrantScope.department => 'قسم',
    WorkspaceGrantScope.role => 'دور وظيفي',
    WorkspaceGrantScope.resource => 'مورد مرتبط',
  };

  static String _capabilityLabel(WorkspaceCapability value) => switch (value) {
    WorkspaceCapability.view => 'عرض',
    WorkspaceCapability.download => 'تنزيل',
    WorkspaceCapability.comment => 'تعليق',
    WorkspaceCapability.edit => 'تعديل',
    WorkspaceCapability.manageContent => 'إدارة المحتوى',
    WorkspaceCapability.manageAccess => 'إدارة الصلاحيات',
  };

  static String _effectLabel(WorkspaceGrantEffect value) => switch (value) {
    WorkspaceGrantEffect.allow => 'سماح',
    WorkspaceGrantEffect.deny => 'منع',
  };

  void _showDepartmentAssignment() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DepartmentFolderAssignmentPanel(
            onDiscover: () {
              Navigator.pop(sheetContext);
              context.read<WorkspaceAccessAdminCubit>().importSource();
            },
            onUseAssignment: ({required folderId, required departmentId}) {
              Navigator.pop(sheetContext);
              setState(() {
                _resource.text = folderId;
                _subject.text = departmentId;
                _scope = WorkspaceGrantScope.department;
              });
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showPilotConfiguration() async {
    final cubit = context.read<WorkspaceAccessAdminCubit>();
    await cubit.loadPilotConfiguration();
    if (!mounted) return;
    final state = cubit.state;
    if (state is! WorkspaceAccessAdminReady ||
        state.pilotConfiguration == null) {
      return;
    }
    final initial = state.pilotConfiguration!;
    final audience = TextEditingController(
      text: initial.enabledActorIds.join(', '),
    );
    final reason = TextEditingController();
    var enabledForEveryone = initial.enabledForEveryone;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تجربة Workspace V2 والتراجع'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile.adaptive(
                    value: enabledForEveryone,
                    onChanged: (value) =>
                        setDialogState(() => enabledForEveryone = value),
                    title: const Text('تشغيل V2 للجميع'),
                    subtitle: const Text(
                      'لا تُفعّل إلا بعد قبول التجربة وقرار المالك. إيقافها يعيد المسار القديم فوراً.',
                    ),
                  ),
                  TextField(
                    controller: audience,
                    enabled: !enabledForEveryone,
                    decoration: const InputDecoration(
                      labelText: 'معرّفات مستخدمي التجربة (UID مفصولة بفواصل)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reason,
                    maxLength: 250,
                    decoration: const InputDecoration(
                      labelText: 'سبب التغيير أو التراجع (يسجل في التدقيق)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              OutlinedButton(
                onPressed: () async {
                  await cubit.savePilotConfiguration(
                    const WorkspacePilotConfiguration(
                      enabledForEveryone: false,
                      enabledActorIds: [],
                    ),
                    reason: 'rollback',
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('تراجع فوري'),
              ),
              FilledButton(
                onPressed: () async {
                  final ids = audience.text
                      .split(',')
                      .map((value) => value.trim())
                      .where((value) => value.isNotEmpty)
                      .toList(growable: false);
                  await cubit.savePilotConfiguration(
                    WorkspacePilotConfiguration(
                      enabledForEveryone: enabledForEveryone,
                      enabledActorIds: ids,
                    ),
                    reason: reason.text.trim(),
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('حفظ الإعداد'),
              ),
            ],
          ),
        ),
      ),
    );
    audience.dispose();
    reason.dispose();
  }
}
