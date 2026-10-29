/// Source-neutral, pure Dart representation of an organizational request
/// within the unified Requests Hub (Task C014).
///
/// Strictly conforms to AGENTS.md domain rules: no Flutter, Firebase, Dio, or UI imports.
enum RequestWorkspaceCategory {
  leave,
  permission,
  attendanceCorrection,
  salaryDeduction,
  lateArrivalDeduction,
  advance,
  administrative,
  custom,
  meeting,
  complaint,
  resignation,
  remoteWork,
  employeeDeletion,
  unknown;

  String get localizedArabicTitle => switch (this) {
    RequestWorkspaceCategory.leave => 'إجازة',
    RequestWorkspaceCategory.permission => 'إذن انصراف/تأخير',
    RequestWorkspaceCategory.attendanceCorrection => 'تصحيح بصمة',
    RequestWorkspaceCategory.salaryDeduction => 'خصم يدوي',
    RequestWorkspaceCategory.lateArrivalDeduction => 'خصم تأخير',
    RequestWorkspaceCategory.advance => 'سلفة مالية',
    RequestWorkspaceCategory.administrative => 'طلب إداري',
    RequestWorkspaceCategory.custom => 'طلب مخصص',
    RequestWorkspaceCategory.meeting => 'حجز قاعة اجتماعات',
    RequestWorkspaceCategory.complaint => 'شكوى / مقترح',
    RequestWorkspaceCategory.resignation => 'طلب استقالة',
    RequestWorkspaceCategory.remoteWork => 'طلب عمل عن بعد',
    RequestWorkspaceCategory.employeeDeletion => 'حذف موظف',
    RequestWorkspaceCategory.unknown => 'طلب عام',
  };
}

enum RequestWorkspaceStatus {
  pending,
  approved,
  rejected,
  cancelled,
  confirmed,
  unknown;

  String get localizedArabicLabel => switch (this) {
    RequestWorkspaceStatus.pending => 'قيد الانتظار',
    RequestWorkspaceStatus.approved => 'معتمد',
    RequestWorkspaceStatus.rejected => 'مرفوض',
    RequestWorkspaceStatus.cancelled => 'ملغي',
    RequestWorkspaceStatus.confirmed => 'مؤكد',
    RequestWorkspaceStatus.unknown => 'غير محدد',
  };

  bool get isClosed => switch (this) {
    RequestWorkspaceStatus.approved ||
    RequestWorkspaceStatus.rejected ||
    RequestWorkspaceStatus.cancelled ||
    RequestWorkspaceStatus.confirmed => true,
    _ => false,
  };
}

enum RequestWorkflowStage {
  manager,
  hr,
  ceo,
  completed,
  unknown;

  String get localizedArabicLabel => switch (this) {
    RequestWorkflowStage.manager => 'اعتماد المدير المباشر',
    RequestWorkflowStage.hr => 'اعتماد الموارد البشرية',
    RequestWorkflowStage.ceo => 'اعتماد الإدارة العليا',
    RequestWorkflowStage.completed => 'مكتمل',
    RequestWorkflowStage.unknown => 'مرحلة غير محددة',
  };
}

final class RequestRecord {
  const RequestRecord({
    required this.id,
    required this.collection,
    required this.category,
    required this.status,
    required this.stage,
    required this.requesterId,
    required this.createdAt,
    this.requesterName,
    this.requesterCode,
    this.department,
    this.summary,
    this.details = const {},
    this.isActionableByMe = false,
    this.historyEvents = const [],
  });

  final String id;
  final String collection;
  final RequestWorkspaceCategory category;
  final RequestWorkspaceStatus status;
  final RequestWorkflowStage stage;
  final String requesterId;
  final DateTime createdAt;
  final String? requesterName;
  final String? requesterCode;
  final String? department;
  final String? summary;
  final Map<String, dynamic> details;
  final bool isActionableByMe;
  final List<RequestTimelineEvent> historyEvents;

  RequestRecord copyWith({
    String? id,
    String? collection,
    RequestWorkspaceCategory? category,
    RequestWorkspaceStatus? status,
    RequestWorkflowStage? stage,
    String? requesterId,
    DateTime? createdAt,
    String? requesterName,
    String? requesterCode,
    String? department,
    String? summary,
    Map<String, dynamic>? details,
    bool? isActionableByMe,
    List<RequestTimelineEvent>? historyEvents,
  }) {
    return RequestRecord(
      id: id ?? this.id,
      collection: collection ?? this.collection,
      category: category ?? this.category,
      status: status ?? this.status,
      stage: stage ?? this.stage,
      requesterId: requesterId ?? this.requesterId,
      createdAt: createdAt ?? this.createdAt,
      requesterName: requesterName ?? this.requesterName,
      requesterCode: requesterCode ?? this.requesterCode,
      department: department ?? this.department,
      summary: summary ?? this.summary,
      details: details ?? this.details,
      isActionableByMe: isActionableByMe ?? this.isActionableByMe,
      historyEvents: historyEvents ?? this.historyEvents,
    );
  }
}

final class RequestTimelineEvent {
  const RequestTimelineEvent({
    required this.title,
    required this.timestamp,
    this.actorName,
    this.note,
    this.isSuccessful = true,
  });

  final String title;
  final DateTime timestamp;
  final String? actorName;
  final String? note;
  final bool isSuccessful;
}
