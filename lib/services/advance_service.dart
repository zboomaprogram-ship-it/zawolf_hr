import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/advance_model.dart';
import '../models/user_model.dart';
import '../models/employee_role.dart';
import 'audit_log_service.dart';

class AdvanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> submitAdvanceRequest(AdvanceModel req, UserModel employee) async {
    final ref = _db.collection('advances').doc();
    final newReq = AdvanceModel(
      advanceId: ref.id,
      userId: req.userId,
      employeeId: req.employeeId,
      employeeName: req.employeeName,
      department: req.department,
      locationId: req.locationId,
      managerId: req.managerId,
      amount: req.amount,
      reason: req.reason,
      status: 'pending_hr',
      monthKey: req.monthKey,
    );

    await ref.set(newReq.toFirestore());

    await AuditLogService.instance.record(
      actorId: employee.uid,
      action: 'advance_request_submitted',
      targetCollection: 'advances',
      targetId: ref.id,
    );
  }

  Stream<List<AdvanceModel>> watchMyAdvances(String userId) {
    return _db
        .collection('advances')
        .where('userId', isEqualTo: userId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(AdvanceModel.fromFirestore).toList();
    });
  }

  Stream<List<AdvanceModel>> watchTeamAdvances(UserModel reviewer) {
    Query<Map<String, dynamic>> query = _db.collection('advances');

    if (reviewer.role == EmployeeRole.manager) {
      query = query.where('managerId', isEqualTo: reviewer.uid);
    }
    
    return query
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(AdvanceModel.fromFirestore).toList();
    });
  }

  Future<void> updateAdvanceStatus({
    required String advanceId,
    required String status,
    required String reviewerId,
    String? comment,
  }) async {
    await _db.collection('advances').doc(advanceId).update({
      'status': status,
      'reviewedBy': reviewerId,
      'reviewedAt': FieldValue.serverTimestamp(),
      if (comment != null) 'reviewerComment': comment,
      'isRead': false,
    });

    await AuditLogService.instance.record(
      actorId: reviewerId,
      action: 'advance_request_reviewed',
      targetCollection: 'advances',
      targetId: advanceId,
      metadata: {'newStatus': status},
    );
  }

  Future<void> markAsRead(String advanceId) async {
    await _db.collection('advances').doc(advanceId).update({'isRead': true});
  }
}
