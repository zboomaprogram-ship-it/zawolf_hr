import 'package:flutter/material.dart';
import '../../domain/entities/organization_unit.dart';

final class InteractiveOrgNodeCard extends StatefulWidget {
  const InteractiveOrgNodeCard({
    super.key,
    required this.unit,
    required this.children,
    required this.canManage,
    this.initiallyExpanded,
    this.memberCount,
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
  final bool? initiallyExpanded;
  final int? memberCount;
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
  State<InteractiveOrgNodeCard> createState() => _InteractiveOrgNodeCardState();
}

class _InteractiveOrgNodeCardState extends State<InteractiveOrgNodeCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded =
        widget.initiallyExpanded ??
        widget.unit.type == OrganizationUnitType.sector;
  }

  @override
  Widget build(BuildContext context) {
    final isSector = widget.unit.type == OrganizationUnitType.sector;
    final primaryColor = isSector
        ? const Color(0xFF00E5FF)
        : const Color(0xFF7C4DFF);
    final badgeBg = isSector
        ? const Color(0xFF00E5FF).withValues(alpha: 0.15)
        : const Color(0xFF7C4DFF).withValues(alpha: 0.15);

    return Semantics(
      container: true,
      label: '${isSector ? 'قطاع' : 'قسم'} ${widget.unit.name}',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primaryColor.withValues(alpha: _expanded ? 0.6 : 0.25),
            width: _expanded ? 1.5 : 1.0,
          ),
          boxShadow: _expanded
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.children.isNotEmpty
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isSector
                            ? Icons.account_tree_rounded
                            : Icons.apartment_rounded,
                        color: primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isSector ? 'قطاع' : 'قسم',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.memberCount != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${widget.memberCount} موظف',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.unit.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (widget.unit.hasVacantManager)
                            Row(
                              children: const [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 13,
                                  color: Colors.amber,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'لا يوجد مدير حاليًا',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            )
                          else if (widget.unit.managerUid != null &&
                              widget.unit.managerUid!.isNotEmpty)
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline_rounded,
                                  size: 13,
                                  color: Colors.white54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'المدير: ${widget.unit.managerUid}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (widget.canManage)
                      PopupMenuButton<String>(
                        tooltip: 'إجراءات الوحدة',
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white70,
                        ),
                        onSelected: (value) => switch (value) {
                          'rename' => widget.onRename?.call(),
                          'manager' => widget.onAssignManager?.call(),
                          'members' => widget.onManageMembers?.call(),
                          'remove_members' => widget.onRemoveMembers?.call(),
                          'move_sector' => widget.onMoveToSector?.call(),
                          'up' => widget.onMoveUp?.call(),
                          'down' => widget.onMoveDown?.call(),
                          'restore' => widget.onRestore?.call(),
                          'archive' => widget.onArchive?.call(),
                          _ => null,
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Text('إعادة التسمية'),
                          ),
                          if (!isSector)
                            const PopupMenuItem(
                              value: 'manager',
                              child: Text('تعيين المدير'),
                            ),
                          if (!isSector)
                            const PopupMenuItem(
                              value: 'members',
                              child: Text('إضافة أو نقل موظفين'),
                            ),
                          if (!isSector)
                            const PopupMenuItem(
                              value: 'remove_members',
                              child: Text('إزالة موظفين من القسم'),
                            ),
                          if (!isSector && widget.onMoveToSector != null)
                            const PopupMenuItem(
                              value: 'move_sector',
                              child: Text('نقل إلى قطاع'),
                            ),
                          if (widget.onMoveUp != null)
                            const PopupMenuItem(
                              value: 'up',
                              child: Text('تحريك لأعلى'),
                            ),
                          if (widget.onMoveDown != null)
                            const PopupMenuItem(
                              value: 'down',
                              child: Text('تحريك لأسفل'),
                            ),
                          if (widget.onRestore != null)
                            const PopupMenuItem(
                              value: 'restore',
                              child: Text('استعادة'),
                            ),
                          if (widget.onArchive != null)
                            const PopupMenuItem(
                              value: 'archive',
                              child: Text('أرشفة'),
                            ),
                        ],
                      ),
                    if (widget.children.isNotEmpty)
                      IconButton(
                        icon: AnimatedRotation(
                          turns: _expanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white70,
                          ),
                        ),
                        onPressed: () => setState(() => _expanded = !_expanded),
                      ),
                  ],
                ),
              ),
            ),
            if (_expanded && widget.children.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 16, left: 8, bottom: 12),
                child: Column(children: widget.children),
              ),
          ],
        ),
      ),
    );
  }
}
