import 'package:cloud_firestore/cloud_firestore.dart';

class JobTitleService {
  JobTitleService._internal();
  static final JobTitleService instance = JobTitleService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final List<String> _initialJobTitles = [
    'Auditor',
    'Account Manager',
    'Content Creator',
    'Media Buyer',
    'SEO Specialist',
    'Graphic Designer',
    'UI Designer',
    'Motion Graphics Artist',
    'General Manager',
    'Video Editor',
    'Training Officer',
    'Tele Sales',
    'Financial Officer',
    'Sales Manager',
    'Software Manager',
    'Customer Manager',
    'System Analyst',
    'CEO',
    'Office Girl',
    'Mobile Developer',
    'Web Developer',
  ];

  Future<void> bootstrapJobTitlesIfNeeded() async {
    final snap = await _db.collection('job_titles').limit(1).get();
    if (snap.docs.isEmpty) {
      final batch = _db.batch();
      for (final title in _initialJobTitles) {
        final docRef = _db.collection('job_titles').doc();
        batch.set(docRef, {
          'name': title,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Stream<List<String>> watchJobTitles() {
    return _db
        .collection('job_titles')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()['name'] as String).toList());
  }

  Future<void> addJobTitle(String name) async {
    final nameTrimmed = name.trim();
    if (nameTrimmed.isEmpty) return;

    final existing = await _db
        .collection('job_titles')
        .where('name', isEqualTo: nameTrimmed)
        .limit(1)
        .get();

    if (existing.docs.isEmpty) {
      await _db.collection('job_titles').add({
        'name': nameTrimmed,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
