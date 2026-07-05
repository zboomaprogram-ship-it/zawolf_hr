import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_policy.dart';

class AttendancePolicyService {
  final FirebaseFirestore _db;

  AttendancePolicyService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  Future<AttendancePolicyConfig> getPolicyConfig({
    String companyId = 'zawolf',
  }) async {
    final docRef = _db.collection('companies').doc(companyId);

    try {
      final doc = await docRef.get();
      return _configFromDoc(doc);
    } catch (_) {
      try {
        final cached = await docRef.get(const GetOptions(source: Source.cache));
        return _configFromDoc(cached);
      } catch (_) {
        return const AttendancePolicyConfig();
      }
    }
  }

  AttendancePolicyConfig _configFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists) return const AttendancePolicyConfig();
    final data = doc.data() ?? <String, dynamic>{};
    final policy = data['attendancePolicy'];
    if (policy is Map<String, dynamic>) {
      return AttendancePolicyConfig.fromMap(policy);
    }
    return AttendancePolicyConfig.fromMap(data);
  }
}
