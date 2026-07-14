import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/field_assignment_model.dart';
import '../models/user_model.dart';
import 'audit_log_service.dart';

class FieldAssignmentService {
  FieldAssignmentService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<void> create({
    required UserModel employee,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String reason,
    required String siteName,
    required bool requiresReturnToOffice,
    required bool requiresCheckout,
    required String createdBy,
  }) async {
    final ref = _db.collection('fieldAssignments').doc();
    final assignment = FieldAssignmentModel(
      assignmentId: ref.id,
      userId: employee.uid,
      employeeId: employee.employeeId,
      employeeName: employee.displayName,
      department: employee.department,
      locationId: employee.locationId,
      date: DateFormat('yyyy-MM-dd').format(date),
      startTime: startTime,
      endTime: endTime,
      reason: reason.trim(),
      siteName: siteName.trim(),
      requiresReturnToOffice: requiresReturnToOffice,
      requiresCheckout: requiresCheckout,
      status: 'active',
      createdBy: createdBy,
    );
    await ref.set(assignment.toFirestore());
    await AuditLogService.instance.record(
      actorId: createdBy,
      action: 'field_assignment_created',
      targetCollection: 'fieldAssignments',
      targetId: ref.id,
      metadata: {'userId': employee.uid, 'date': assignment.date},
    );
  }

  Future<FieldAssignmentModel?> activeAt({
    required String userId,
    required String dateKey,
    required DateTime now,
  }) async {
    final snapshot = await _db
        .collection('fieldAssignments')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: dateKey)
        .where('status', isEqualTo: 'active')
        .get();
    for (final doc in snapshot.docs) {
      final assignment = FieldAssignmentModel.fromFirestore(doc);
      final start = _timeOnDate(now, assignment.startTime);
      final end = _timeOnDate(now, assignment.endTime);
      if (!now.isBefore(start) && !now.isAfter(end)) return assignment;
    }
    return null;
  }

  Future<bool> skipsCheckoutForDate({
    required String userId,
    required String dateKey,
  }) async {
    final snapshot = await _db
        .collection('fieldAssignments')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: dateKey)
        .where('status', isEqualTo: 'active')
        .get();
    return snapshot.docs.any((doc) {
      final assignment = FieldAssignmentModel.fromFirestore(doc);
      return !assignment.requiresCheckout;
    });
  }

  Stream<List<FieldAssignmentModel>> watchForDate(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    return _db
        .collection('fieldAssignments')
        .where('date', isEqualTo: key)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(FieldAssignmentModel.fromFirestore).toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime)),
        );
  }

  Future<void> cancel(String assignmentId, String actorId) async {
    await _db.collection('fieldAssignments').doc(assignmentId).update({
      'status': 'cancelled',
      'cancelledBy': actorId,
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  DateTime _timeOnDate(DateTime date, String value) {
    final parts = value.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }
}
