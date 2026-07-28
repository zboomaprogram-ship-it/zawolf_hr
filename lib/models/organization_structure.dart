import 'package:cloud_firestore/cloud_firestore.dart';

class OrganizationLevel {
  static const employee = 'employee';
  static const teamLeader = 'team_leader';
  static const departmentManager = 'department_manager';
  static const divisionManager = 'division_manager';
  static const ceo = 'ceo';

  static const values = [
    employee,
    teamLeader,
    departmentManager,
    divisionManager,
    ceo,
  ];

  static String arabicLabel(String value) => switch (value) {
    ceo => 'المدير التنفيذي',
    divisionManager => 'مدير القطاع / GM',
    departmentManager => 'مدير القسم',
    teamLeader => 'قائد فريق',
    _ => 'موظف',
  };

  static String defaultFor({
    required String employeeId,
    required String appRole,
  }) {
    final code = employeeId.trim().toUpperCase();
    if (code == 'CEO-100') return ceo;
    if (code == 'COO-1300') return divisionManager;
    if (appRole == 'team_leader') return teamLeader;
    if (appRole == 'manager' || appRole == 'hr_manager') {
      return departmentManager;
    }
    return employee;
  }
}

class OrganizationDivision {
  const OrganizationDivision({
    required this.id,
    required this.name,
    required this.order,
    this.managerId,
    this.managerEmployeeId,
    this.isActive = true,
  });

  final String id;
  final String name;
  final int order;
  final String? managerId;
  final String? managerEmployeeId;
  final bool isActive;

  factory OrganizationDivision.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return OrganizationDivision(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      order: (data['order'] as num?)?.toInt() ?? 999,
      managerId: data['managerId'] as String?,
      managerEmployeeId: data['managerEmployeeId'] as String?,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'order': order,
    'managerId': managerId,
    'managerEmployeeId': managerEmployeeId,
    'isActive': isActive,
  };
}

class OrganizationDepartment {
  const OrganizationDepartment({
    required this.id,
    required this.name,
    required this.divisionId,
    required this.order,
  });

  final String id;
  final String name;
  final String divisionId;
  final int order;

  factory OrganizationDepartment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final name = data['name'] as String? ?? doc.id;
    return OrganizationDepartment(
      id: doc.id,
      name: name,
      divisionId:
          data['organizationDivisionId'] as String? ??
          OrganizationDefaults.inferDivisionId(name),
      order: (data['organizationOrder'] as num?)?.toInt() ?? 999,
    );
  }
}

class OrganizationDefaults {
  static const administration = 'administration';
  static const operations = 'operations';
  static const sales = 'sales';

  static const divisions = [
    OrganizationDivision(id: administration, name: 'الإدارة', order: 0),
    OrganizationDivision(
      id: operations,
      name: 'القسم التشغيلي',
      order: 1,
      managerEmployeeId: 'COO-1300',
    ),
    OrganizationDivision(id: sales, name: 'قسم المبيعات', order: 2),
  ];

  static String inferDivisionId(String departmentName) {
    final name = departmentName.trim().toLowerCase();
    const administrationKeywords = [
      'accounting',
      'human resources',
      'hr',
      'it',
      'legal',
      'الحسابات',
      'الموارد البشرية',
      'الشؤون القانونية',
      'تقنية المعلومات',
    ];
    if (administrationKeywords.any(name.contains)) return administration;

    final compact = name.replaceAll(RegExp(r'[^a-zأ-ي]'), '');
    if (compact == 'bd' ||
        compact == 'sdr' ||
        name.contains('business development')) {
      return sales;
    }
    return operations;
  }
}
