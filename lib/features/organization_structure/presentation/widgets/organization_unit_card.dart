import 'package:flutter/material.dart';

import '../../domain/entities/organization_unit.dart';

final class OrganizationUnitCard extends StatelessWidget {
  const OrganizationUnitCard({
    super.key,
    required this.unit,
    required this.children,
    required this.canManage,
    this.onRename,
    this.onAssignManager,
    this.onArchive,
    this.onManageMembers,
    this.onRemoveMembers,
    this.onMoveToSector,
    this.onMoveUp,
    this.onMoveDown,
    this.onRestore,
  });
  final OrganizationUnit unit;
  final List<Widget> children;
  final bool canManage;
  final VoidCallback? onRename;
  final VoidCallback? onAssignManager;
  final VoidCallback? onArchive;
  final VoidCallback? onManageMembers;
  final VoidCallback? onRemoveMembers;
  final VoidCallback? onMoveToSector;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label:
        '${unit.type == OrganizationUnitType.sector ? 'قطاع' : 'قسم'} ${unit.name}',
    child: Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: unit.type == OrganizationUnitType.sector,
        leading: Icon(
          unit.type == OrganizationUnitType.sector
              ? Icons.account_tree_outlined
              : Icons.apartment_outlined,
        ),
        title: SelectableText(
          unit.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: unit.hasVacantManager
            ? const Text(
                'لا يوجد مدير حاليًا',
                style: TextStyle(color: Colors.amber),
              )
            : null,
        trailing: canManage
            ? PopupMenuButton<String>(
                tooltip: 'إجراءات الوحدة',
                onSelected: (value) => switch (value) {
                  'rename' => onRename?.call(),
                  'manager' => onAssignManager?.call(),
                  'members' => onManageMembers?.call(),
                  'remove_members' => onRemoveMembers?.call(),
                  'move_sector' => onMoveToSector?.call(),
                  'up' => onMoveUp?.call(),
                  'down' => onMoveDown?.call(),
                  'restore' => onRestore?.call(),
                  'archive' => onArchive?.call(),
                  _ => null,
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('إعادة التسمية'),
                  ),
                  if (unit.type == OrganizationUnitType.department)
                    const PopupMenuItem(
                      value: 'manager',
                      child: Text('تعيين المدير'),
                    ),
                  if (unit.type == OrganizationUnitType.department)
                    const PopupMenuItem(
                      value: 'members',
                      child: Text('إضافة أو نقل موظفين'),
                    ),
                  if (unit.type == OrganizationUnitType.department)
                    const PopupMenuItem(
                      value: 'remove_members',
                      child: Text('إزالة موظفين من القسم'),
                    ),
                  if (unit.type == OrganizationUnitType.department &&
                      onMoveToSector != null)
                    const PopupMenuItem(
                      value: 'move_sector',
                      child: Text('نقل إلى قطاع'),
                    ),
                  if (onMoveUp != null)
                    const PopupMenuItem(
                      value: 'up',
                      child: Text('تحريك لأعلى'),
                    ),
                  if (onMoveDown != null)
                    const PopupMenuItem(
                      value: 'down',
                      child: Text('تحريك لأسفل'),
                    ),
                  if (onRestore != null)
                    const PopupMenuItem(
                      value: 'restore',
                      child: Text('استعادة'),
                    ),
                  if (onArchive != null)
                    const PopupMenuItem(value: 'archive', child: Text('أرشفة')),
                ],
              )
            : null,
        children: children,
      ),
    ),
  );
}
