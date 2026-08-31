import 'package:flutter/material.dart';
import '../../domain/entities/organization_snapshot.dart';

final class OrganizationStructureMapPage extends StatelessWidget {
  const OrganizationStructureMapPage({super.key, required this.snapshot});
  final OrganizationSnapshot snapshot;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('الخريطة التنظيمية')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: snapshot.sectors.length,
        itemBuilder: (context, index) {
          final sector = snapshot.sectors[index];
          final departments = snapshot.departmentsFor(sector.id);
          return Card(
            child: ExpansionTile(
              title: SelectableText(sector.name),
              subtitle: Text('${departments.length} قسم'),
              children: [
                for (final department in departments)
                  ListTile(
                    leading: const Icon(Icons.apartment),
                    title: SelectableText(department.name),
                    subtitle: Text(
                      '${department.memberCount > 0 ? department.memberCount : snapshot.memberships.where((membership) => membership.active && membership.departmentUnitId == department.id).length} موظف · '
                      '${department.hasVacantManager ? 'المدير: شاغر' : 'تم تعيين مدير'}',
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
