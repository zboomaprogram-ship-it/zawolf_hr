import 'package:flutter/material.dart';
import '../../domain/entities/organization_change_set.dart';

final class OrganizationChangePreview extends StatelessWidget {
  const OrganizationChangePreview({super.key, required this.preview});
  final OrganizationImpactPreview preview;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('مراجعة أثر التغيير'),
    content: Text(
      'سيتأثر ${preview.affectedEmployees} موظف و${preview.affectedDepartments} قسم. لن تتغير مسارات الطلبات القديمة.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('تأكيد'),
      ),
    ],
  );
}
