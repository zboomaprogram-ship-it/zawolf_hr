import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/wolf_card.dart';
import '../../models/company_workspace_models.dart';
import '../../models/employee_role.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/company_workspace_service.dart';
import '../../services/google_workspace_service.dart';
import '../../theme/theme.dart';
import '../../utils/binary_file_action.dart';
import '../../utils/user_facing_error.dart';
import '../../utils/workspace_csv_import.dart';
import 'workspace_sheet_editor_screen.dart';
import 'workspace_folder_browser_screen.dart';
import '../../design_system/components/skeletons.dart' show SkeletonList;

class CompanyWorkspaceCenterScreen extends StatefulWidget {
  const CompanyWorkspaceCenterScreen({super.key});

  @override
  State<CompanyWorkspaceCenterScreen> createState() =>
      _CompanyWorkspaceCenterScreenState();
}

class _CompanyWorkspaceCenterScreenState
    extends State<CompanyWorkspaceCenterScreen> {
  final _service = CompanyWorkspaceService();
  final _googleWorkspace = GoogleWorkspaceService();
  List<CompanyWorkspaceResource> _resources = const [];
  List<WorkspaceSchemaProfile> _profiles = const [];
  List<WorkspaceAccessGrant> _grants = const [];
  List<WorkspaceAccessTemplate> _accessTemplates = const [];
  List<UserModel> _grantableUsers = const [];
  bool _loading = true;
  String? _error;
  String _query = '';

  UserModel? get _user => context.read<AuthService>().currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = _user;
    if (user == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resources = await _service.loadResources(user);
      final profiles = await _service.loadSchemaProfiles();
      final canGrant = _service.canGrantAccess(user);
      final grants = canGrant
          ? await _service.loadGrants(user)
          : const <WorkspaceAccessGrant>[];
      final templates = canGrant
          ? await _service.loadAccessTemplates()
          : const <WorkspaceAccessTemplate>[];
      final users = canGrant
          ? await _service.loadGrantableUsers(user)
          : const <UserModel>[];
      if (!mounted) return;
      setState(() {
        _resources = resources;
        _profiles = profiles;
        _grants = grants;
        _accessTemplates = templates;
        _grantableUsers = users;
      });
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showResourceDialog([CompanyWorkspaceResource? resource]) async {
    final actor = _user;
    if (actor == null) return;
    final name = TextEditingController(text: resource?.name ?? '');
    final department = TextEditingController(text: resource?.department ?? '');
    final description = TextEditingController(
      text: resource?.description ?? '',
    );
    final externalId = TextEditingController();
    final sheetTab = TextEditingController(text: resource?.sheetTab ?? '');
    var type = resource?.type ?? 'sheet';
    var schemaId = resource?.schemaProfileId ?? '';
    final selectedManagers = <String>{...?resource?.managerIds};
    final managers = _grantableUsers
        .where((item) => item.role == EmployeeRole.manager)
        .toList(growable: false);
    final key = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(resource == null ? 'إضافة مصدر شركة' : 'تعديل المصدر'),
          content: SizedBox(
            width: 620,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'اسم المصدر',
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'اسم المصدر مطلوب.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'النوع'),
                      items: const [
                        DropdownMenuItem(
                          value: 'sheet',
                          child: Text('Google Sheet'),
                        ),
                        DropdownMenuItem(
                          value: 'folder',
                          child: Text('مجلد Drive'),
                        ),
                        DropdownMenuItem(
                          value: 'file',
                          child: Text('ملف Drive'),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => type = value ?? 'sheet'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: department,
                      decoration: const InputDecoration(labelText: 'القسم'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: externalId,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: 'Google File/Folder ID (اختياري الآن)',
                        helperText: resource?.hasExternalId == true
                            ? 'يوجد معرّف محفوظ بأمان. اتركه فارغاً للاحتفاظ به.'
                            : 'يُحفظ منفصلاً ولا يظهر للموظف.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (type == 'sheet')
                      TextFormField(
                        controller: sheetTab,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'اسم تبويب Sheet (اختياري)',
                          helperText:
                              'مثال: Employee_Test_Data. اتركه فارغاً لاستخدام أول تبويب.',
                        ),
                      ),
                    if (type == 'sheet') const SizedBox(height: 10),
                    if (type == 'sheet')
                      DropdownButtonFormField<String>(
                        initialValue: _profiles.any((p) => p.id == schemaId)
                            ? schemaId
                            : '',
                        decoration: const InputDecoration(
                          labelText: 'Schema Profile',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('بدون مخطط حالياً'),
                          ),
                          ..._profiles.map(
                            (profile) => DropdownMenuItem(
                              value: profile.id,
                              child: Text(profile.name),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => schemaId = value ?? ''),
                      ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: description,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'وصف الاستخدام',
                      ),
                    ),
                    if (managers.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text('المديرون الذين يمكنهم منح الوصول'),
                      ),
                      ...managers.map(
                        (manager) => CheckboxListTile(
                          value: selectedManagers.contains(manager.uid),
                          title: Text(manager.displayName),
                          subtitle: Text(
                            '${manager.employeeId} · ${manager.department}',
                          ),
                          onChanged: (selected) => setDialogState(() {
                            if (selected == true) {
                              selectedManagers.add(manager.uid);
                            } else {
                              selectedManagers.remove(manager.uid);
                            }
                          }),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (key.currentState?.validate() != true) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _perform(
        () => _service.saveResource(
          id: resource?.id,
          actor: actor,
          name: name.text,
          type: type,
          department: department.text,
          description: description.text,
          externalId: externalId.text,
          schemaProfileId: schemaId,
          sheetTab: sheetTab.text,
          managerIds: selectedManagers.toList(),
        ),
      );
    }
    name.dispose();
    department.dispose();
    description.dispose();
    externalId.dispose();
    sheetTab.dispose();
  }

  Future<void> _showSchemaDialog() async {
    final actor = _user;
    if (actor == null) return;
    final name = TextEditingController();
    final headerRow = TextEditingController(text: '1');
    final keyColumn = TextEditingController(text: 'employee_code');
    final mappings = TextEditingController(
      text:
          'employee_code=employeeId\nemployee_name=displayName\nstatus=status\ndate=date',
    );
    final editable = TextEditingController(text: 'status, notes');
    final key = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إنشاء Schema Profile'),
        content: SizedBox(
          width: 620,
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'اسم المخطط'),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'اسم المخطط مطلوب.'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: headerRow,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'رقم صف العناوين',
                    ),
                    validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                        ? 'أدخل رقم صف صحيح.'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: keyColumn,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'عمود المفتاح الفريد',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: mappings,
                    minLines: 5,
                    maxLines: 10,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'ربط الأعمدة: source=systemField',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: editable,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'الحقول القابلة للتعديل، مفصولة بفاصلة',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState?.validate() == true) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('حفظ المخطط'),
          ),
        ],
      ),
    );
    if (saved == true) {
      final parsedMappings = <String, String>{};
      for (final line in mappings.text.split('\n')) {
        final separator = line.indexOf('=');
        if (separator <= 0) continue;
        final source = line.substring(0, separator).trim();
        final target = line.substring(separator + 1).trim();
        if (source.isNotEmpty && target.isNotEmpty) {
          parsedMappings[source] = target;
        }
      }
      await _perform(
        () => _service.saveSchemaProfile(
          actor: actor,
          name: name.text,
          headerRow: int.parse(headerRow.text),
          keyColumn: keyColumn.text,
          mappings: parsedMappings,
          editableFields: editable.text
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
        ),
      );
    }
    name.dispose();
    headerRow.dispose();
    keyColumn.dispose();
    mappings.dispose();
    editable.dispose();
  }

  Future<void> _seedStarterSchemaProfiles() async {
    final actor = _user;
    if (actor == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة المخططات الجاهزة'),
        content: const Text(
          'سيضيف النظام أربعة مخططات جاهزة: المهام والأداء، الحضور، '
          'الإجازات والأذونات، والمبيعات وKPI. لن تتغير ملفات Google الأصلية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _perform(() => _service.seedStarterSchemaProfiles(actor: actor));
  }

  Future<void> _showAccessTemplateDialog() async {
    final actor = _user;
    if (actor == null) return;
    final name = TextEditingController();
    var scopeType = 'employee';
    var permission = 'view';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إنشاء قالب صلاحيات'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(labelText: 'اسم القالب'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: scopeType,
                  decoration: const InputDecoration(labelText: 'نطاق القالب'),
                  items: const [
                    DropdownMenuItem(
                      value: 'employee',
                      child: Text('موظف محدد'),
                    ),
                    DropdownMenuItem(
                      value: 'department',
                      child: Text('جميع موظفي القسم'),
                    ),
                    DropdownMenuItem(
                      value: 'manager_team',
                      child: Text('فريق مدير'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => scopeType = value ?? 'employee'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: permission,
                  decoration: const InputDecoration(labelText: 'الصلاحية'),
                  items: const [
                    DropdownMenuItem(value: 'view', child: Text('عرض فقط')),
                    DropdownMenuItem(
                      value: 'download',
                      child: Text('عرض وتنزيل'),
                    ),
                    DropdownMenuItem(value: 'edit', child: Text('عرض وتعديل')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => permission = value ?? 'view'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: name.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('حفظ القالب'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _perform(
        () => _service.saveAccessTemplate(
          actor: actor,
          name: name.text,
          scopeType: scopeType,
          permission: permission,
        ),
      );
    }
    name.dispose();
  }

  Future<void> _applyAccessTemplate(CompanyWorkspaceResource resource) async {
    final actor = _user;
    if (actor == null || _accessTemplates.isEmpty) return;
    WorkspaceAccessTemplate? template;
    UserModel? selectedUser;
    final applied = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final needsSelection =
              template?.scopeType == 'employee' ||
              (template?.scopeType == 'manager_team' &&
                  actor.role == EmployeeRole.superAdmin);
          final selectableUsers = template?.scopeType == 'manager_team'
              ? _grantableUsers
                    .where((user) => user.role == EmployeeRole.manager)
                    .toList()
              : _grantableUsers;
          return AlertDialog(
            title: Text('تطبيق قالب على ${resource.name}'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<WorkspaceAccessTemplate>(
                    initialValue: template,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'القالب'),
                    items: _accessTemplates
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(() {
                      template = value;
                      selectedUser = null;
                    }),
                  ),
                  if (needsSelection) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UserModel>(
                      initialValue: selectedUser,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: template?.scopeType == 'manager_team'
                            ? 'المدير'
                            : 'الموظف',
                      ),
                      items: selectableUsers
                          .map(
                            (user) => DropdownMenuItem(
                              value: user,
                              child: Text(
                                '${user.displayName} · ${user.employeeId}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedUser = value),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed:
                    template == null || (needsSelection && selectedUser == null)
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('تطبيق'),
              ),
            ],
          );
        },
      ),
    );
    if (applied == true && template != null) {
      await _perform(
        () => _service.applyAccessTemplate(
          actor: actor,
          resource: resource,
          template: template!,
          selectedUser: selectedUser,
        ),
      );
    }
  }

  Future<void> _downloadCsvTemplate() async {
    const csv =
        'name,type,google_id,department,description,schema_profile,manager_code,employee_code,permission\n'
        'Sales Tasks,sheet,GOOGLE_FILE_ID,Sales,Monthly sales tasks,Employee Tasks Test,CEO-100,IT-400,edit\n';
    final handled = await downloadBinaryFile(
      [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)],
      'workspace_resources_template.csv',
      'text/csv;charset=utf-8',
    );
    if (!handled && mounted) {
      setState(() => _error = 'تنزيل نموذج CSV متاح من نسخة الويب.');
    }
  }

  Future<void> _importCsv() async {
    final actor = _user;
    if (actor == null) return;
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    final bytes = picked?.files.single.bytes;
    if (bytes == null) return;
    try {
      final csvText = utf8.decode(bytes, allowMalformed: false);
      final rawRows = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csvText);
      final preview = parseWorkspaceCsvRows(
        rawRows,
        employeeCodes: _grantableUsers.map((user) => user.employeeId).toSet(),
        schemaProfiles: {
          ..._profiles.map((profile) => profile.id),
          ..._profiles.map((profile) => profile.name),
        },
      );
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('معاينة استيراد المصادر'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('عدد الصفوف: ${preview.rows.length}'),
                  const SizedBox(height: 8),
                  if (preview.errors.isNotEmpty) ...[
                    const Text(
                      'يجب تصحيح الأخطاء قبل الاستيراد:',
                      style: TextStyle(color: ZaWolfColors.error),
                    ),
                    ...preview.errors
                        .take(20)
                        .map(
                          (error) => Text(
                            '• $error',
                            style: const TextStyle(color: ZaWolfColors.error),
                          ),
                        ),
                  ] else
                    ...preview.rows
                        .take(15)
                        .map(
                          (row) => ListTile(
                            dense: true,
                            title: Text('${row.rowNumber}. ${row.name}'),
                            subtitle: Text(
                              '${row.type} · ${row.department} · ${row.employeeCode.isEmpty ? 'بدون موظف مباشر' : row.employeeCode}',
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إغلاق'),
            ),
            FilledButton.icon(
              onPressed: preview.canImport
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('تنفيذ الاستيراد'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await _perform(
          () => _service.importResources(
            actor: actor,
            rows: preview.rows,
            directory: _grantableUsers,
            profiles: _profiles,
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    }
  }

  Future<void> _showGrantDialog(CompanyWorkspaceResource resource) async {
    final actor = _user;
    if (actor == null) return;
    UserModel? selected;
    var permission = 'view';
    final granted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('منح الوصول إلى ${resource.name}'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<UserModel>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الموظف'),
                  items: _grantableUsers
                      .map(
                        (user) => DropdownMenuItem(
                          value: user,
                          child: Text(
                            '${user.displayName} · ${user.employeeId}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => selected = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: permission,
                  decoration: const InputDecoration(labelText: 'الصلاحية'),
                  items: const [
                    DropdownMenuItem(value: 'view', child: Text('عرض فقط')),
                    DropdownMenuItem(
                      value: 'download',
                      child: Text('عرض وتنزيل'),
                    ),
                    DropdownMenuItem(value: 'edit', child: Text('عرض وتعديل')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => permission = value ?? 'view'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('منح الوصول'),
            ),
          ],
        ),
      ),
    );
    if (granted == true && selected != null) {
      await _perform(
        () => _service.grantAccess(
          actor: actor,
          resource: resource,
          target: selected!,
          permission: permission,
        ),
      );
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ العملية بنجاح.')));
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _recordView(CompanyWorkspaceResource resource) async {
    final actor = _user;
    if (actor == null) return;
    try {
      await _service.recordAudit(
        actor: actor,
        action: 'resource_viewed',
        resourceId: resource.id,
        resourceName: resource.name,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(resource.name),
          content: Text(
            '${_typeLabel(resource.type)}\n'
            'القسم: ${resource.department.isEmpty ? 'كل الشركة' : resource.department}\n'
            '${resource.description}\n\n'
            '${resource.hasExternalId ? 'المصدر جاهز للموصل الآمن. ستظهر بياناته هنا بعد تشغيل Google Workspace Connector.' : 'لم يُضف معرّف Google لهذا المصدر بعد.'}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    }
  }

  Future<void> _openResource(CompanyWorkspaceResource resource) async {
    if (!resource.hasExternalId) {
      await _recordView(resource);
      return;
    }
    try {
      if (resource.type == 'sheet') {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkspaceSheetEditorScreen(resource: resource),
          ),
        );
      } else if (resource.type == 'folder') {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkspaceFolderBrowserScreen(resource: resource),
          ),
        );
      } else {
        await _recordView(resource);
      }
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    }
  }

  Future<void> _discoverCompanyFiles() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('مزامنة ملفات الشركة'),
        content: const Text(
          'سيكتشف النظام تلقائياً كل Sheets والمجلدات والملفات داخل مجلد الشركة الرئيسي، ثم ينظمها داخل النظام. لا يحذف أو ينقل أي ملف في Google Drive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('بدء المزامنة'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _googleWorkspace.discoverCompanyWorkspace();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم اكتشاف ${result.discovered} ملفاً: ${result.created} جديد، ${result.updated} محدّث، و${result.grants} صلاحية موظف.',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _bootstrapCompanyWorkspace() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إنشاء هيكل ملفات الشركة'),
        content: const Text(
          'سيُنشئ النظام داخل مجلد الشركة الرئيسي مجلدات الإدارة والموارد '
          'البشرية والأقسام والتقارير والملفات المشتركة، بالإضافة إلى مجلد '
          'لكل موظف نشط. لن يحذف أو ينقل أو يشارك أي ملف موجود في Google Drive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('إنشاء الهيكل'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _googleWorkspace.bootstrapCompanyWorkspace();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إنشاء ${result.createdFolders} مجلد: ${result.departmentFolders} '
            'للأقسام و${result.employeeFolders} للموظفين. وتمت مزامنة '
            '${result.discovered} مصدر ومنح ${result.grants} صلاحية.'
            '${result.skippedWithoutEmployeeId > 0 ? ' يوجد ${result.skippedWithoutEmployeeId} حساب بدون كود موظف؛ أضف له الكود ثم أعد الإنشاء.' : ''}',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _typeLabel(String type) => switch (type) {
    'sheet' => 'Google Sheet',
    'folder' => 'مجلد Drive',
    _ => 'ملف Drive',
  };

  IconData _typeIcon(String type) => switch (type) {
    'sheet' => Icons.table_chart_outlined,
    'folder' => Icons.folder_outlined,
    _ => Icons.insert_drive_file_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) {
      return const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: SkeletonList(itemCount: 4, itemHeight: 88),
        ),
      );
    }
    final isAdmin = _service.canAdminister(user);
    final canGrant = _service.canGrantAccess(user);
    final query = _query.trim().toLowerCase();
    final folders = _resources
        .where((resource) => resource.type == 'folder')
        .toList(growable: false);
    final visible = _resources
        .where((resource) {
          // Discovery stores every Drive descendant as a resource.  The
          // landing page deliberately shows only the outermost available
          // folder; its contents are loaded after the user opens it.
          final nestedInAnotherFolder = folders.any(
            (folder) =>
                folder.id != resource.id &&
                folder.description.isNotEmpty &&
                resource.description.startsWith('${folder.description}/'),
          );
          if (nestedInAnotherFolder) return false;
          if (query.isEmpty) return true;
          return '${resource.name} ${resource.department} ${resource.description}'
              .toLowerCase()
              .contains(query);
        })
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('مركز ملفات الشركة')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'ملفات الشركة',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                isAdmin
                    ? 'أضف مصادر الشركة وحدد المديرين وSchema لكل Sheet.'
                    : canGrant
                    ? 'اعرض مصادر قسمك وامنح الوصول لموظفي فريقك.'
                    : 'تظهر هنا الملفات التي منحها لك مديرك فقط.',
                style: const TextStyle(color: ZaWolfColors.textSecondary),
              ),
              const SizedBox(height: 14),
              if (_error != null)
                WolfCard(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: ZaWolfColors.error),
                  ),
                ),
              if (isAdmin || canGrant)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (canGrant)
                      FilledButton.icon(
                        onPressed: _loading ? null : _bootstrapCompanyWorkspace,
                        icon: const Icon(Icons.account_tree_outlined),
                        label: const Text('إنشاء هيكل الشركة'),
                      ),
                    if (isAdmin)
                      FilledButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _showResourceDialog(),
                        icon: const Icon(Icons.add_to_drive_outlined),
                        label: const Text('إضافة مصدر'),
                      ),
                    if (canGrant)
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _discoverCompanyFiles,
                        icon: const Icon(Icons.sync_outlined),
                        label: const Text('مزامنة ملفات Google'),
                      ),
                    if (isAdmin)
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _showSchemaDialog,
                        icon: const Icon(Icons.schema_outlined),
                        label: const Text('إنشاء Schema Profile'),
                      ),
                    if (isAdmin)
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _seedStarterSchemaProfiles,
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('إضافة المخططات الجاهزة'),
                      ),
                    if (isAdmin)
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _showAccessTemplateDialog,
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('قالب صلاحيات'),
                      ),
                    if (isAdmin)
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _importCsv,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('استيراد CSV'),
                      ),
                    if (isAdmin)
                      TextButton.icon(
                        onPressed: _loading ? null : _downloadCsvTemplate,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('نموذج CSV'),
                      ),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('تحديث'),
                    ),
                  ],
                ),
              if (_loading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'بحث بالاسم أو القسم أو الوصف',
                ),
              ),
              const SizedBox(height: 12),
              if (!_loading && visible.isEmpty)
                const WolfCard(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'لا توجد ملفات متاحة حالياً. مسؤول النظام يضيف المصدر، ثم يمنح المدير الوصول لفريقه.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ...visible.map(
                (resource) => WolfCard(
                  hasBorderGlow: true,
                  child: ListTile(
                    leading: Icon(
                      _typeIcon(resource.type),
                      color: ZaWolfColors.primaryCyan,
                    ),
                    title: Text(resource.name),
                    subtitle: Text(
                      '${_typeLabel(resource.type)} · ${resource.department.isEmpty ? 'كل الشركة' : resource.department}\n'
                      '${resource.description.isEmpty ? 'لا يوجد وصف' : resource.description}\n'
                      '${resource.hasExternalId ? 'تم إعداد معرّف Google' : 'جاهز للربط لاحقاً'}',
                    ),
                    isThreeLine: true,
                    trailing: Wrap(
                      spacing: 2,
                      children: [
                        IconButton(
                          tooltip: 'فتح المصدر',
                          onPressed: _loading
                              ? null
                              : () => _openResource(resource),
                          icon: const Icon(Icons.visibility_outlined),
                        ),
                        if (canGrant)
                          IconButton(
                            tooltip: 'منح الوصول',
                            onPressed: _loading
                                ? null
                                : () => _showGrantDialog(resource),
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                          ),
                        if (canGrant && _accessTemplates.isNotEmpty)
                          IconButton(
                            tooltip: 'تطبيق قالب صلاحيات',
                            onPressed: _loading
                                ? null
                                : () => _applyAccessTemplate(resource),
                            icon: const Icon(Icons.rule_folder_outlined),
                          ),
                        if (isAdmin)
                          IconButton(
                            tooltip: 'تعديل المصدر',
                            onPressed: _loading
                                ? null
                                : () => _showResourceDialog(resource),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (canGrant && _grants.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'الصلاحيات النشطة (${_grants.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ..._grants.map(
                  (grant) => WolfCard(
                    child: ListTile(
                      title: Text('${grant.userName} · ${grant.employeeCode}'),
                      subtitle: Text(
                        '${grant.resourceName} · ${grant.permission}',
                      ),
                      trailing: IconButton(
                        tooltip: 'إلغاء الوصول',
                        onPressed: _loading
                            ? null
                            : () => _perform(
                                () => _service.revokeAccess(
                                  actor: user,
                                  grant: grant,
                                ),
                              ),
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: ZaWolfColors.error,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (isAdmin && _profiles.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Schema Profiles (${_profiles.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ..._profiles.map(
                  (profile) => WolfCard(
                    child: ListTile(
                      leading: const Icon(Icons.schema_outlined),
                      title: Text(profile.name),
                      subtitle: Text(
                        'صف العناوين: ${profile.headerRow} · المفتاح: ${profile.keyColumn}\n'
                        '${profile.columnMappings.length} أعمدة مربوطة · ${profile.editableFields.length} قابلة للتعديل',
                      ),
                    ),
                  ),
                ),
              ],
              if (isAdmin && _accessTemplates.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'قوالب الصلاحيات (${_accessTemplates.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ..._accessTemplates.map(
                  (template) => WolfCard(
                    child: ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: Text(template.name),
                      subtitle: Text(
                        '${_scopeLabel(template.scopeType)} · ${_permissionLabel(template.permission)}',
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _scopeLabel(String scope) => switch (scope) {
    'department' => 'كل موظفي القسم',
    'manager_team' => 'فريق مدير',
    _ => 'موظف محدد',
  };

  String _permissionLabel(String permission) => switch (permission) {
    'edit' => 'عرض وتعديل',
    'download' => 'عرض وتنزيل',
    _ => 'عرض فقط',
  };
}
