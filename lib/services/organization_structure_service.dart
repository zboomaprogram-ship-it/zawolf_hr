import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/organization_structure.dart';
import '../models/user_model.dart';

class OrganizationStructureData {
  const OrganizationStructureData({
    required this.users,
    required this.divisions,
    required this.departments,
  });

  final List<UserModel> users;
  final List<OrganizationDivision> divisions;
  final List<OrganizationDepartment> departments;
}

class OrganizationStructureService {
  OrganizationStructureService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<List<OrganizationDivision>> loadDivisions() async {
    final snapshot = await _db.collection('organization_divisions').get();
    final divisionsById = <String, OrganizationDivision>{
      for (final division in OrganizationDefaults.divisions)
        division.id: division,
    };
    for (final doc in snapshot.docs) {
      final division = OrganizationDivision.fromFirestore(doc);
      divisionsById[division.id] = division;
    }
    final divisions =
        divisionsById.values.where((division) => division.isActive).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    return divisions;
  }

  Future<List<OrganizationDepartment>> loadDepartments() async {
    final snapshot = await _db.collection('departments').get();
    final departments =
        snapshot.docs.map(OrganizationDepartment.fromFirestore).toList()
          ..sort((a, b) {
            final order = a.order.compareTo(b.order);
            return order != 0 ? order : a.name.compareTo(b.name);
          });
    return departments;
  }

  Future<void> bootstrapDefaultsIfNeeded() async {
    final snapshot = await _db
        .collection('organization_divisions')
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) return;
    final batch = _db.batch();
    for (final division in OrganizationDefaults.divisions) {
      batch.set(_db.collection('organization_divisions').doc(division.id), {
        ...division.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> saveDivision(OrganizationDivision division) {
    return _db.collection('organization_divisions').doc(division.id).set({
      ...division.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> moveDepartment({
    required String departmentId,
    required String divisionId,
  }) {
    return _db.collection('departments').doc(departmentId).update({
      'organizationDivisionId': divisionId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
