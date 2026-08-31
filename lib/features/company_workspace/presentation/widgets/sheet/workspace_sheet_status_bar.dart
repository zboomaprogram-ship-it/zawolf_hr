import 'package:flutter/material.dart';

class WorkspaceSheetStatusBar extends StatelessWidget {
  const WorkspaceSheetStatusBar({required this.canEdit, super.key});
  final bool canEdit;

  @override
  Widget build(BuildContext context) => Semantics(
    label: canEdit ? 'الورقة قابلة للتعديل' : 'الورقة للعرض فقط',
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(
        canEdit ? 'جاهز للحفظ' : 'عرض فقط حسب الصلاحية',
        textAlign: TextAlign.center,
      ),
    ),
  );
}
