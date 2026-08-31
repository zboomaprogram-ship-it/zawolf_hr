import 'package:flutter/material.dart';

import '../../../../design_system/components/rtl_navigation.dart';
import '../../domain/entities/workspace_capability.dart';
import '../../domain/entities/workspace_resource.dart';

class WorkspaceBreadcrumb extends StatelessWidget {
  const WorkspaceBreadcrumb({
    required this.items,
    required this.onNavigate,
    super.key,
  });
  final List<WorkspaceResource> items;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'مسار الملفات',
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        TextButton.icon(
          onPressed: () => onNavigate(-1),
          icon: const Icon(Icons.home_outlined),
          label: const Text('ملفات الشركة'),
        ),
        for (var index = 0; index < items.length; index++) ...[
          Icon(RtlNavigation.chevronEnd(context), size: 18),
          TextButton(
            onPressed: () => onNavigate(index),
            child: Text(items[index].name),
          ),
        ],
      ],
    ),
  );
}

class WorkspaceResourceList extends StatelessWidget {
  const WorkspaceResourceList({
    required this.resources,
    required this.onOpen,
    required this.onMore,
    super.key,
  });
  final List<WorkspaceResource> resources;
  final ValueChanged<WorkspaceResource> onOpen;
  final ValueChanged<WorkspaceResource> onMore;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    itemCount: resources.length,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final resource = resources[index];
      final editable =
          resource.can(WorkspaceCapability.edit) ||
          resource.can(WorkspaceCapability.manageContent);
      return Card(
        child: ListTile(
          key: ValueKey('workspace-resource-${resource.id}'),
          onTap: () => onOpen(resource),
          leading: Icon(
            resource.type == WorkspaceResourceType.folder
                ? Icons.folder_outlined
                : Icons.description_outlined,
          ),
          title: Text(
            resource.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(editable ? 'قابل للتعديل' : 'عرض فقط'),
          trailing: IconButton(
            tooltip: 'إجراءات الملف',
            icon: const Icon(Icons.more_vert),
            onPressed: () => onMore(resource),
          ),
        ),
      );
    },
  );
}

class WorkspaceLoadMore extends StatelessWidget {
  const WorkspaceLoadMore({required this.onPressed, super.key});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.expand_more),
      label: const Text('تحميل المزيد'),
    ),
  );
}
