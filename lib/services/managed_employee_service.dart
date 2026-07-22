import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/employee_role.dart';
import '../models/user_model.dart';

class ManagedEmployeeService {
  ManagedEmployeeService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static bool isManagedBy(UserModel employee, String reviewerId) {
    return employee.managerId == reviewerId ||
        employee.managerIds.contains(reviewerId);
  }

  Future<List<UserModel>> loadForReviewer(UserModel reviewer) async {
    if (reviewer.role == EmployeeRole.teamLeader) {
      final snapshot = await _db
          .collection('users')
          .where('teamLeaderId', isEqualTo: reviewer.uid)
          .get();
      return _activeUsers(snapshot.docs);
    }

    if (reviewer.role == EmployeeRole.manager) {
      final results = await Future.wait([
        _db
            .collection('users')
            .where('managerIds', arrayContains: reviewer.uid)
            .get(),
        _db
            .collection('users')
            .where('managerId', isEqualTo: reviewer.uid)
            .get(),
      ]);
      final byId = <String, UserModel>{};
      for (final doc in results.expand((snapshot) => snapshot.docs)) {
        final employee = UserModel.fromFirestore(doc);
        if (employee.isActive &&
            employee.role != EmployeeRole.superAdmin &&
            isManagedBy(employee, reviewer.uid)) {
          byId[employee.uid] = employee;
        }
      }
      final employees = byId.values.toList();
      employees.sort((a, b) => a.displayName.compareTo(b.displayName));
      return employees;
    }

    final snapshot = await _db
        .collection('users')
        .where('isActive', isEqualTo: true)
        .get();
    return _activeUsers(snapshot.docs);
  }

  List<UserModel> _activeUsers(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final users = docs
        .map(UserModel.fromFirestore)
        .where((user) => user.isActive && user.role != EmployeeRole.superAdmin)
        .toList();
    users.sort((a, b) => a.displayName.compareTo(b.displayName));
    return users;
  }
}
