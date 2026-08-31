import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/entities/developer_tools_employee.dart';
import '../domain/repositories/developer_tools_directory_repository.dart';

/// A bounded list used only by the HR/admin entitlement screen.
///
/// It is a one-shot read rather than a live listener: access management does
/// not need to keep the full employee directory subscribed in the background.
final class FirestoreDeveloperToolsDirectoryRepository
    implements DeveloperToolsDirectoryRepository {
  FirestoreDeveloperToolsDirectoryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int _pageSize = 250;
  static const int _maximumDirectorySize = 5000;

  @override
  Future<List<DeveloperToolsEmployee>> loadActiveEmployees() async {
    final documents = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (documents.length < _maximumDirectorySize) {
      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .orderBy(FieldPath.documentId)
          .limit(_pageSize);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final page = await query.get();
      documents.addAll(page.docs);
      if (page.docs.length < _pageSize) break;
      cursor = page.docs.last;
    }

    final employees = documents.map((document) {
      final data = document.data();
      final displayName =
          <Object?>[
                data['displayName'],
                data['name'],
                data['fullName'],
                data['email'],
                data['employeeId'],
                document.id,
              ]
              .map((value) => (value ?? '').toString().trim())
              .firstWhere(
                (value) => value.isNotEmpty,
                orElse: () => document.id,
              );
      return DeveloperToolsEmployee(
        userId: document.id,
        displayName: displayName,
        employeeCode: (data['employeeId'] ?? '').toString().trim(),
        department: (data['department'] ?? '').toString().trim(),
      );
    }).toList();
    employees.sort(
      (left, right) => left.displayName.compareTo(right.displayName),
    );
    return employees;
  }
}
