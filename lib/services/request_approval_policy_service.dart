import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/request_approval_policy.dart';

class RequestApprovalPolicyService {
  RequestApprovalPolicyService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _policyRef =>
      _db.collection('publicConfig').doc('requestApproval');

  Stream<RequestApprovalPolicy> watchPolicy() {
    return _policyRef.snapshots().map(
      (snapshot) => RequestApprovalPolicy.fromMap(snapshot.data()),
    );
  }

  Future<RequestApprovalPolicy> getPolicy() async {
    try {
      final snapshot = await _policyRef.get();
      return RequestApprovalPolicy.fromMap(snapshot.data());
    } catch (_) {
      return const RequestApprovalPolicy();
    }
  }

  Future<void> setRequireHrAfterManagerApproval({
    required bool value,
    required String updatedBy,
  }) {
    return _policyRef.set({
      'requireHrAfterManagerApproval': value,
      'updatedBy': updatedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
