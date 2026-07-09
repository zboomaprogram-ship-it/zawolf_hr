import 'package:cloud_firestore/cloud_firestore.dart';

class TaskPriority {
  static const low = 'low';
  static const medium = 'medium';
  static const high = 'high';
  static const urgent = 'urgent';

  static String arabicLabel(String value) {
    switch (value) {
      case urgent:
        return 'عاجلة';
      case high:
        return 'عالية';
      case low:
        return 'منخفضة';
      default:
        return 'متوسطة';
    }
  }
}

class TaskStatus {
  static const newTask = 'new';
  static const inProgress = 'in_progress';
  static const done = 'done';
  static const late = 'late';
  static const cancelled = 'cancelled';

  static String arabicLabel(String value) {
    switch (value) {
      case inProgress:
        return 'قيد التنفيذ';
      case done:
        return 'مكتملة';
      case late:
        return 'متأخرة';
      case cancelled:
        return 'ملغاة';
      default:
        return 'جديدة';
    }
  }
}

class EmployeeTaskModel {
  final String taskId;
  final String title;
  final String description;
  final String assigneeId;
  final String assigneeName;
  final String assigneeEmployeeId;
  final String department;
  final String managerId;
  final List<String> managerIds;
  final String createdBy;
  final String createdByName;
  final String priority;
  final String status;
  final DateTime dueDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final int? qualityScore;
  final String? managerComment;
  final String? attachmentUrl;
  final bool isRead;

  EmployeeTaskModel({
    required this.taskId,
    required this.title,
    required this.description,
    required this.assigneeId,
    required this.assigneeName,
    required this.assigneeEmployeeId,
    required this.department,
    required this.managerId,
    this.managerIds = const [],
    required this.createdBy,
    required this.createdByName,
    required this.priority,
    required this.status,
    required this.dueDate,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.qualityScore,
    this.managerComment,
    this.attachmentUrl,
    this.isRead = false,
  });

  factory EmployeeTaskModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmployeeTaskModel(
      taskId: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      assigneeId: data['assigneeId'] as String? ?? '',
      assigneeName: data['assigneeName'] as String? ?? '',
      assigneeEmployeeId: data['assigneeEmployeeId'] as String? ?? '',
      department: data['department'] as String? ?? '',
      managerId: data['managerId'] as String? ?? '',
      managerIds:
          (data['managerIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [
            if ((data['managerId'] as String? ?? '').isNotEmpty)
              data['managerId'] as String,
          ],
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      priority: data['priority'] as String? ?? TaskPriority.medium,
      status: data['status'] as String? ?? TaskStatus.newTask,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      qualityScore: data['qualityScore'] as int?,
      managerComment: data['managerComment'] as String?,
      attachmentUrl: data['attachmentUrl'] as String?,
      isRead: data['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'assigneeId': assigneeId,
      'assigneeName': assigneeName,
      'assigneeEmployeeId': assigneeEmployeeId,
      'department': department,
      'managerId': managerId,
      'managerIds': managerIds.isNotEmpty ? managerIds : [managerId],
      'createdBy': createdBy,
      'createdByName': createdByName,
      'priority': priority,
      'status': status,
      'dueDate': Timestamp.fromDate(dueDate),
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(updatedAt!),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (qualityScore != null) 'qualityScore': qualityScore,
      if (managerComment != null) 'managerComment': managerComment,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      'isRead': isRead,
    };
  }
}
