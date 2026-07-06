import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/employee_role.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import 'audit_log_service.dart';

class TaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<EmployeeTaskModel>> watchMyTasks(String userId) {
    return _db
        .collection('tasks')
        .where('assigneeId', isEqualTo: userId)
        .orderBy('dueDate')
        .snapshots()
        .map(_tasksFromSnapshot);
  }

  Stream<List<EmployeeTaskModel>> watchManagedTasks(UserModel reviewer) {
    Query<Map<String, dynamic>> query = _db.collection('tasks');
    if (reviewer.role == EmployeeRole.manager) {
      query = query.where('managerId', isEqualTo: reviewer.uid);
    }
    return query.orderBy('dueDate').snapshots().map(_tasksFromSnapshot);
  }

  Future<List<UserModel>> loadAssignableEmployees(UserModel reviewer) async {
    Query<Map<String, dynamic>> query = _db
        .collection('users')
        .where('isActive', isEqualTo: true);
    if (reviewer.role == EmployeeRole.manager) {
      query = query.where('managerId', isEqualTo: reviewer.uid);
    }
    final snap = await query.get();
    final users = snap.docs.map(UserModel.fromFirestore).where((user) {
      if (user.role == EmployeeRole.superAdmin) return false;
      if (reviewer.role == EmployeeRole.manager) {
        return user.managerId == reviewer.uid;
      }
      return true;
    }).toList();
    users.sort((a, b) => a.displayName.compareTo(b.displayName));
    return users;
  }

  Future<void> createTask({
    required UserModel creator,
    required UserModel assignee,
    required String title,
    required String description,
    required DateTime dueDate,
    required String priority,
  }) async {
    final ref = _db.collection('tasks').doc();
    final task = EmployeeTaskModel(
      taskId: ref.id,
      title: title.trim(),
      description: description.trim(),
      assigneeId: assignee.uid,
      assigneeName: assignee.displayName,
      assigneeEmployeeId: assignee.employeeId,
      department: assignee.department,
      managerId: assignee.managerId ?? creator.uid,
      createdBy: creator.uid,
      createdByName: creator.displayName,
      priority: priority,
      status: TaskStatus.newTask,
      dueDate: dueDate,
    );

    await ref.set(task.toFirestore());
    await AuditLogService.instance.record(
      actorId: creator.uid,
      action: 'task_created',
      targetCollection: 'tasks',
      targetId: ref.id,
      metadata: {
        'assigneeId': assignee.uid,
        'priority': priority,
        'dueDate': dueDate.toIso8601String(),
      },
    );

    try {
      await _createNotification(
        recipientId: assignee.uid,
        type: 'task_assigned',
        title: 'مهمة جديدة',
        body: '${creator.displayName} أسند إليك مهمة: ${title.trim()}',
        data: {'taskId': ref.id},
      );
    } catch (_) {}
  }

  Future<void> updateMyTaskStatus({
    required String taskId,
    required String userId,
    required String status,
    String? attachmentUrl,
  }) async {
    if (![TaskStatus.inProgress, TaskStatus.done].contains(status)) {
      throw Exception('حالة المهمة غير صحيحة');
    }
    final patch = <String, dynamic>{
      'status': status,
      'isRead': true,
      'updatedAt': FieldValue.serverTimestamp(),
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (status == TaskStatus.done)
        'completedAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('tasks').doc(taskId).update(patch);
    await AuditLogService.instance.record(
      actorId: userId,
      action: 'task_status_updated',
      targetCollection: 'tasks',
      targetId: taskId,
      metadata: {'status': status},
    );
  }

  Future<void> reviewTask({
    required String taskId,
    required UserModel reviewer,
    required int qualityScore,
    String? comment,
  }) async {
    final doc = await _db.collection('tasks').doc(taskId).get();
    if (!doc.exists) throw Exception('المهمة غير موجودة');
    final task = EmployeeTaskModel.fromFirestore(doc);

    await doc.reference.update({
      'qualityScore': qualityScore,
      'managerComment': comment?.trim() ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.instance.record(
      actorId: reviewer.uid,
      action: 'task_reviewed',
      targetCollection: 'tasks',
      targetId: taskId,
      metadata: {'qualityScore': qualityScore, 'assigneeId': task.assigneeId},
    );

    try {
      await _createNotification(
        recipientId: task.assigneeId,
        type: 'task_reviewed',
        title: 'تم تقييم المهمة',
        body: 'تم تقييم مهمة "${task.title}" بدرجة $qualityScore/100.',
        data: {'taskId': taskId},
      );
    } catch (_) {}
  }

  Future<void> cancelTask({
    required String taskId,
    required UserModel reviewer,
  }) async {
    await _db.collection('tasks').doc(taskId).update({
      'status': TaskStatus.cancelled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AuditLogService.instance.record(
      actorId: reviewer.uid,
      action: 'task_cancelled',
      targetCollection: 'tasks',
      targetId: taskId,
    );
  }

  List<EmployeeTaskModel> _tasksFromSnapshot(QuerySnapshot snapshot) {
    final tasks = snapshot.docs
        .map((doc) => EmployeeTaskModel.fromFirestore(doc))
        .toList();
    tasks.sort((a, b) {
      if (a.status == TaskStatus.done && b.status != TaskStatus.done) return 1;
      if (a.status != TaskStatus.done && b.status == TaskStatus.done) return -1;
      return a.dueDate.compareTo(b.dueDate);
    });
    return tasks;
  }

  Future<void> _createNotification({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final notifRef = _db
        .collection('notifications')
        .doc(recipientId)
        .collection('items')
        .doc();

    await notifRef.set({
      'notificationId': notifRef.id,
      'type': type,
      'title': title,
      'body': body,
      'data': data ?? {},
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('users').doc(recipientId).update({
      'unreadNotifications': FieldValue.increment(1),
    });
  }
}
