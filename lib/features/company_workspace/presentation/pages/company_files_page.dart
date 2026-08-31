import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../utils/binary_file_action.dart';
import '../../domain/entities/workspace_capability.dart';
import '../../domain/entities/workspace_operation.dart';
import '../../domain/entities/workspace_resource.dart';
import '../cubit/workspace_browser_cubit.dart';
import '../cubit/workspace_operations_cubit.dart';
import '../widgets/workspace_resource_browser.dart';
import '../widgets/workspace_sync_status_banner.dart';

class CompanyFilesPage extends StatefulWidget {
  const CompanyFilesPage({
    this.onOpenSpreadsheet,
    this.onDownload,
    this.onManageAccess,
    this.onOpenReports,
    super.key,
  });

  /// Routing/composition owns the editor dependencies. The browser only
  /// declares the user intent, keeping presentation independent from HTTP,
  /// Firebase and data implementations.
  final ValueChanged<WorkspaceResource>? onOpenSpreadsheet;
  final Future<WorkspaceDownloadedFile> Function(WorkspaceResource resource)?
  onDownload;
  final VoidCallback? onManageAccess;
  final VoidCallback? onOpenReports;

  @override
  State<CompanyFilesPage> createState() => _CompanyFilesPageState();
}

class _CompanyFilesPageState extends State<CompanyFilesPage> {
  final _breadcrumbs = <WorkspaceResource>[];

  void _open(WorkspaceResource resource) {
    if (resource.type == WorkspaceResourceType.spreadsheet) {
      widget.onOpenSpreadsheet?.call(resource);
      return;
    }
    if (resource.type != WorkspaceResourceType.folder) return;
    setState(() => _breadcrumbs.add(resource));
    context.read<WorkspaceBrowserCubit>().load(parentId: resource.id);
  }

  void _navigate(int index) {
    setState(() {
      if (index < 0) {
        _breadcrumbs.clear();
      } else {
        _breadcrumbs.removeRange(index + 1, _breadcrumbs.length);
      }
    });
    context.read<WorkspaceBrowserCubit>().load(
      parentId: index < 0 ? null : _breadcrumbs[index].id,
    );
  }

  void _showActions(WorkspaceResource resource) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    resource.type == WorkspaceResourceType.folder
                        ? Icons.folder_outlined
                        : Icons.insert_drive_file_outlined,
                  ),
                  title: Text(resource.name),
                  subtitle: Text(
                    _canEdit(resource)
                        ? 'يمكنك إدارة هذا المورد وفق الصلاحية الممنوحة.'
                        : 'هذا المورد متاح للعرض فقط.',
                  ),
                ),
                if (resource.type != WorkspaceResourceType.folder &&
                    resource.can(WorkspaceCapability.download))
                  ListTile(
                    leading: const Icon(Icons.download_outlined),
                    title: const Text('تنزيل آمن'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _downloadResource(resource);
                    },
                  ),
                if (_canEdit(resource)) ...[
                  ListTile(
                    leading: const Icon(Icons.drive_file_rename_outline),
                    title: const Text('إعادة تسمية'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _renameResource(resource);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.content_copy_outlined),
                    title: const Text('نسخ إلى مجلد'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _moveOrCopyResource(resource, copy: true);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.drive_file_move_outline),
                    title: const Text('نقل إلى مجلد'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _moveOrCopyResource(resource, copy: false);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('نقل إلى سلة المحذوفات'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _trashResource(resource);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _canEdit(WorkspaceResource resource) =>
      resource.can(WorkspaceCapability.edit) ||
      resource.can(WorkspaceCapability.manageContent);

  bool get _canCreateFolder {
    if (_breadcrumbs.isEmpty) return false;
    final folder = _breadcrumbs.last;
    return folder.can(WorkspaceCapability.edit) ||
        folder.can(WorkspaceCapability.manageContent);
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إنشاء مجلد'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'اسم المجلد'),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (name == null ||
        name.trim().isEmpty ||
        _breadcrumbs.isEmpty ||
        !mounted) {
      return;
    }
    await context.read<WorkspaceOperationsCubit>().submit(
      resourceId: _breadcrumbs.last.id,
      kind: WorkspaceOperationKind.fileCreate,
      payload: {'name': name.trim()},
    );
  }

  Future<void> _renameResource(WorkspaceResource resource) async {
    final controller = TextEditingController(text: resource.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إعادة تسمية'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'الاسم الجديد'),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    await context.read<WorkspaceOperationsCubit>().submit(
      resourceId: resource.id,
      kind: WorkspaceOperationKind.fileRename,
      payload: {'name': name.trim()},
    );
  }

  Future<void> _trashResource(WorkspaceResource resource) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('نقل إلى سلة المحذوفات؟'),
          content: Text(
            'سيُنقل “${resource.name}” إلى سلة المحذوفات ويمكن استعادته لاحقاً.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('نقل'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<WorkspaceOperationsCubit>().submit(
      resourceId: resource.id,
      kind: WorkspaceOperationKind.fileTrash,
    );
    if (!mounted ||
        context.read<WorkspaceOperationsCubit>().state
            is! WorkspaceOperationsSaved) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نقل “${resource.name}” إلى سلة المحذوفات.'),
        action: SnackBarAction(
          label: 'استعادة',
          onPressed: () => context.read<WorkspaceOperationsCubit>().submit(
            resourceId: resource.id,
            kind: WorkspaceOperationKind.fileRestore,
            expectedVersion: resource.version,
          ),
        ),
      ),
    );
  }

  Future<void> _downloadResource(WorkspaceResource resource) async {
    final download = widget.onDownload;
    if (download == null) return;
    try {
      final file = await download(resource);
      if (!mounted) return;
      final handled = await downloadBinaryFile(
        file.bytes,
        file.fileName,
        file.mimeType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            handled
                ? 'بدأ تنزيل الملف.'
                : 'تعذر بدء تنزيل الملف على هذا الجهاز.',
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر تنزيل الملف الآن. تحقق من الصلاحية ثم أعد المحاولة.',
          ),
        ),
      );
    }
  }

  Future<void> _moveOrCopyResource(
    WorkspaceResource resource, {
    required bool copy,
  }) async {
    final controller = TextEditingController(
      text: _breadcrumbs.isEmpty ? '' : _breadcrumbs.last.id,
    );
    final destinationResourceId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(copy ? 'نسخ إلى مجلد' : 'نقل إلى مجلد'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'معرّف مجلد الوجهة المسموح',
              helperText: 'لا يقبل النظام إلا مجلداً لديك صلاحية تعديله.',
            ),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: Text(copy ? 'نسخ' : 'نقل'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (destinationResourceId == null ||
        destinationResourceId.trim().isEmpty ||
        !mounted) {
      return;
    }
    await context.read<WorkspaceOperationsCubit>().submit(
      resourceId: resource.id,
      kind: copy
          ? WorkspaceOperationKind.fileCopy
          : WorkspaceOperationKind.fileMove,
      payload: {'destinationResourceId': destinationResourceId.trim()},
      expectedVersion: resource.version,
    );
  }

  Future<void> _uploadFile() async {
    if (_breadcrumbs.isEmpty) return;
    final picked = await FilePicker.pickFiles(
      withData: true,
      allowMultiple: false,
    );
    final file = picked?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) return;
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب ألا يتجاوز حجم الملف 20 MB.')),
      );
      return;
    }
    await context.read<WorkspaceOperationsCubit>().submit(
      resourceId: _breadcrumbs.last.id,
      kind: WorkspaceOperationKind.fileUpload,
      payload: {
        'name': file.name,
        'mimeType': _mimeTypeForExtension(file.extension ?? ''),
        'contentsBase64': base64Encode(bytes),
      },
    );
  }

  String _mimeTypeForExtension(String extension) => switch (extension
      .toLowerCase()) {
    'pdf' => 'application/pdf',
    'csv' => 'text/csv',
    'txt' => 'text/plain',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    _ => 'application/octet-stream',
  };

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<WorkspaceOperationsCubit, WorkspaceOperationsState>(
    listener: (context, state) {
      final message = switch (state) {
        WorkspaceOperationsSaved(:final message) => message,
        WorkspaceOperationsRejected(:final message) => message,
        WorkspaceOperationsPending() => 'تم حفظ الطلب وسيتم التحقق من نتيجته.',
        _ => null,
      };
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      if (state is WorkspaceOperationsSaved && _breadcrumbs.isNotEmpty) {
        context.read<WorkspaceBrowserCubit>().load(
          parentId: _breadcrumbs.last.id,
        );
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('ملفات الشركة'),
        actions: [
          if (widget.onManageAccess != null)
            IconButton(
              tooltip: 'إدارة الوصول',
              onPressed: widget.onManageAccess,
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          if (widget.onOpenReports != null)
            IconButton(
              tooltip: 'التقارير',
              onPressed: widget.onOpenReports,
              icon: const Icon(Icons.assessment_outlined),
            ),
        ],
      ),
      floatingActionButton: _canCreateFolder
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'workspace-upload',
                  onPressed: _uploadFile,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('رفع ملف'),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'workspace-folder',
                  onPressed: _createFolder,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('مجلد'),
                ),
              ],
            )
          : null,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            BlocBuilder<WorkspaceOperationsCubit, WorkspaceOperationsState>(
              builder: (context, state) => switch (state) {
                WorkspaceOperationsSaved(:final message) =>
                  WorkspaceSyncStatusBanner(
                    message: message,
                    kind: WorkspaceSyncStatusKind.saved,
                  ),
                WorkspaceOperationsPending() => WorkspaceSyncStatusBanner(
                  message:
                      'الطلب قيد المزامنة. سيتحقق النظام من نتيجته تلقائياً.',
                  kind: WorkspaceSyncStatusKind.pending,
                  onAction: () => context.read<WorkspaceBrowserCubit>().load(
                    parentId: _breadcrumbs.isEmpty
                        ? null
                        : _breadcrumbs.last.id,
                  ),
                ),
                WorkspaceOperationsRejected(:final message) =>
                  WorkspaceSyncStatusBanner(
                    message: message,
                    kind: WorkspaceSyncStatusKind.failure,
                    onAction: () => context.read<WorkspaceBrowserCubit>().load(
                      parentId: _breadcrumbs.isEmpty
                          ? null
                          : _breadcrumbs.last.id,
                    ),
                  ),
                _ => const SizedBox.shrink(),
              },
            ),
            Expanded(
              child: BlocBuilder<WorkspaceBrowserCubit, WorkspaceBrowserState>(
                builder: (context, state) => switch (state) {
                  WorkspaceBrowserLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  WorkspaceBrowserDenied() => _MessageState(
                    icon: Icons.lock_outline,
                    text: 'لا توجد ملفات متاحة لك حالياً.',
                    action: 'إعادة المحاولة',
                    onPressed: () =>
                        context.read<WorkspaceBrowserCubit>().load(),
                  ),
                  WorkspaceBrowserFailure(:final message) => _MessageState(
                    icon: Icons.cloud_off_outlined,
                    text: message,
                    action: 'إعادة المحاولة',
                    onPressed: () =>
                        context.read<WorkspaceBrowserCubit>().load(),
                  ),
                  WorkspaceBrowserReady(:final resources, :final canLoadMore) =>
                    resources.isEmpty
                        ? _MessageState(
                            icon: Icons.folder_off_outlined,
                            text: 'لا توجد ملفات مسندة إليك حالياً.',
                            action: 'تحديث',
                            onPressed: () =>
                                context.read<WorkspaceBrowserCubit>().load(),
                          )
                        : Column(
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                    16,
                                    8,
                                    16,
                                    4,
                                  ),
                                  child: WorkspaceBreadcrumb(
                                    items: _breadcrumbs,
                                    onNavigate: _navigate,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: WorkspaceResourceList(
                                  resources: resources,
                                  onOpen: _open,
                                  onMore: _showActions,
                                ),
                              ),
                              if (canLoadMore)
                                WorkspaceLoadMore(
                                  onPressed: () => context
                                      .read<WorkspaceBrowserCubit>()
                                      .loadMore(),
                                ),
                            ],
                          ),
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.text,
    required this.action,
    required this.onPressed,
  });
  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: onPressed, child: Text(action)),
      ],
    ),
  );
}
