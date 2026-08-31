import 'package:flutter/material.dart';

/// Controller-facing helper for assigning an imported employee folder through
/// the existing, server-authorized grant flow. IDs are internal ZaWolf IDs;
/// Drive paths/IDs are never entered by an employee.
class DepartmentFolderAssignmentPanel extends StatefulWidget {
  const DepartmentFolderAssignmentPanel({
    required this.onUseAssignment,
    required this.onDiscover,
    super.key,
  });

  final void Function({required String folderId, required String departmentId})
  onUseAssignment;
  final VoidCallback onDiscover;

  @override
  State<DepartmentFolderAssignmentPanel> createState() =>
      _DepartmentFolderAssignmentPanelState();
}

class _DepartmentFolderAssignmentPanelState
    extends State<DepartmentFolderAssignmentPanel> {
  final _folder = TextEditingController();
  final _department = TextEditingController();

  @override
  void dispose() {
    _folder.dispose();
    _department.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'تعيين مجلد موظف لقسم',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(
            width: 240,
            child: TextField(
              controller: _folder,
              decoration: const InputDecoration(labelText: 'معرّف مجلد الموظف'),
            ),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _department,
              decoration: const InputDecoration(labelText: 'معرّف القسم'),
            ),
          ),
          FilledButton(
            onPressed: () {
              if (_folder.text.trim().isEmpty ||
                  _department.text.trim().isEmpty) {
                return;
              }
              widget.onUseAssignment(
                folderId: _folder.text.trim(),
                departmentId: _department.text.trim(),
              );
            },
            child: const Text('استخدام في الصلاحيات'),
          ),
          OutlinedButton.icon(
            onPressed: widget.onDiscover,
            icon: const Icon(Icons.manage_search_outlined),
            label: const Text('اكتشاف المصادر'),
          ),
        ],
      ),
    ),
  );
}
