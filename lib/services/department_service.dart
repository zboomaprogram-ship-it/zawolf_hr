import 'package:cloud_firestore/cloud_firestore.dart';

class DepartmentService {
  static final DepartmentService instance = DepartmentService._internal();
  DepartmentService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final List<String> _initialDepartments = [
    'Human Resources',
    'Accounting',
    'Data Analytics',
    'Operations',
    'Administration',
    'IT',
    'Account Management',
    'Support Services',
    'Programming',
    'Management',
    'Marketing',
    'Sales',
    'Customer Service',
    'Office',
    'AI',
    'Tech Ops',
    'PR',
    'Legal Affairs',
    'BD',
    'Research and Development',
    'Safety & Security',
    'Public Relations',
  ];

  Future<void> bootstrapDepartmentsIfNeeded() async {
    final snap = await _db.collection('departments').limit(1).get();
    if (snap.docs.isEmpty) {
      final batch = _db.batch();
      for (final dept in _initialDepartments) {
        final docRef = _db.collection('departments').doc();
        batch.set(docRef, {
          'name': dept,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Stream<List<String>> watchDepartments() {
    return _db.collection('departments').orderBy('name').snapshots().map(
      (snap) {
        return snap.docs.map((doc) => doc.data()['name'] as String).toList();
      },
    );
  }

  Future<void> addDepartment(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    
    // Check if exists
    final snap = await _db
        .collection('departments')
        .where('name', isEqualTo: cleanName)
        .get();
        
    if (snap.docs.isEmpty) {
      await _db.collection('departments').add({
        'name': cleanName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
